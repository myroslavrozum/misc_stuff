#!/usr/bin/env ruby

require 'aws-sdk'
require 'json'
require 'securerandom'
require "net/http"
require "uri"
require "openssl"
require 'optparse'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: adddomains.rb [options]"
  opts.on("-g", "--groupname NAME", "Name of group") { |v| options[:group_name] = v }
  opts.on("-v", "--[no-]verbose", "Run verbosely") { |v| options[:verbose] = v }
  opts.on('-h', '--help', 'Displays Help') { |v| puts opts }
end.parse!
raise OptionParser::MissingArgument if options[:group_name].nil?

environment = options[:group_name]
DOMAIN = ""
ec2 = Aws::EC2::Resource.new
route53 = Aws::Route53::Client.new

HOSTED_ZONE_ID = ""
DASHBOARD_API = "https://dashboard/"

BALANCERS=ec2.instances({
  filters: [{
      name: "tag:Name",
      values: ["#{environment}bal*"],
    },
  ],
})
puts "BALANCES: #{BALANCERS.to_json}" if options[:verbose]
raise Exception.new("No balancers for #{environment}") if BALANCERS.nil?
primary_balancer = BALANCERS.first

healthcheck_create_response = route53.create_health_check({
  caller_reference: SecureRandom.uuid,
  health_check_config: {
    ip_address: BALANCERS.first.public_ip_address,
    port: 80,
    type: "HTTP",
    resource_path: "/healthcheck/index.html",
    fully_qualified_domain_name: DOMAIN,
    request_interval: 30,
    failure_threshold: 3,
    measure_latency: false,
    inverted: false,
  },
})
puts "Resoponse: #{healthcheck_create_response.to_json}" if options[:verbose]

route53.change_tags_for_resource({
  resource_id: healthcheck_create_response.data.health_check.id,
  resource_type: "healthcheck",
  add_tags: [
    { 
      key: "Name",
      value: "#{DOMAIN}-primary_bal-health",
    },
  ],
})

dns_names = []
webgroup = environment + 'web'
uri = URI.parse(DASHBOARD_API + webgroup + '@')
http = Net::HTTP.new(uri.host, uri.port, "proxy" , "80")
http.use_ssl = true
http.verify_mode = OpenSSL::SSL::VERIFY_NONE

resp = route53.list_resource_record_sets({
  hosted_zone_id: HOSTED_ZONE_ID,
})
puts resp.resource_record_sets.to_json if options[:verbose]
hosted_zone_name = resp.resource_record_sets[0]['name']

puts "Requesting:: #{uri.request_uri}" if options[:verbose]
request = Net::HTTP::Get.new(uri.request_uri)
resp = http.request(request)
puts "Resoponse: #{resp.to_json}" if options[:verbose]
metadata = JSON.load(resp.body)

for site in metadata[webgroup]['sites'].keys
   dns_names.push(metadata[webgroup]['sites'][site]['servername'])
  for serveralias in metadata[webgroup]['sites'][site]['serveralias']
    dns_names.push(serveralias)
  end
end
puts "Names form dashboardapi: #{dns_names.to_json}" if options[:verbose]
dns_names = dns_names.select { | name | "#{name}.".include? hosted_zone_name }
puts "Filtered names form dashboardapi: #{dns_names.to_json}" if options[:verbose]

recordset_changes = []

dns_names.each do |name|
  BALANCERS.each do |balancer|
    resource_records = []
    resource_record_set = {
      name: name,
      ttl: 300,
      resource_records: resource_records,
    }
    change = {
      action: "CREATE",
      resource_record_set: resource_record_set
    }

    if name == DOMAIN
      resource_record_set[:type] = "A"
      resource_records.push({value: balancer.public_ip_address}) 
    else
      resource_record_set[:type] = "CNAME"
      resource_records.push(value: balancer.public_dns_name )
    end
 
    if balancer.instance_id == primary_balancer.instance_id
      resource_record_set[:set_identifier] = "#{name}-primary"
      resource_record_set[:failover] = "PRIMARY"
      resource_record_set[:health_check_id] = healthcheck_create_response.data.health_check.id
    else
      resource_record_set[:set_identifier] = "#{name}-#{SecureRandom.uuid}-secondary"
      resource_record_set[:failover] = "SECONDARY"
    end
    recordset_changes.push(change)
  end
end
batch = {
    comment: "Create: records in #{environment}",
    changes: recordset_changes
  }
puts "Batch: #{batch.to_json}" if options[:verbose]

resp = route53.change_resource_record_sets({
  :hosted_zone_id => HOSTED_ZONE_ID,
  :change_batch => batch
})
puts "Resoponse: #{resp.to_json}" if options[:verbose]

id = resp.change_info.id
print "Waiting for #{id}\n"

while resp.change_info.status == "PENDING"
  resp = route53.get_change({ id: id })
  sleep(5)
end
print "#{resp.change_info.status} #{resp.change_info.id}\n"
