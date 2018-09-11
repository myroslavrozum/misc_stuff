#!/usr/bin/env ruby

require 'aws-sdk'
require 'json'
require 'securerandom'
require "net/http"
require "uri"
require "openssl"
require 'optparse'
require 'pp'


def read_existing_rrset(route53, start_record_name=nil)
  names = []
  response = route53.list_resource_record_sets({
    hosted_zone_id: HOSTED_ZONE,
    start_record_name: start_record_name
  })

  for record in response.resource_record_sets
    names.push(record.name.tr('"', '').chomp("."))
  end
  names += read_existing_rrset(route53, response.next_record_name) if response.is_truncated
  names
end

def read_existing_healthchecks(route53, marker=nil)
  healthchecks = {}
  response = route53.list_health_checks({marker: marker})
  for healthcheck in response.health_checks
    healthchecks[healthcheck.health_check_config.fully_qualified_domain_name.to_s] = healthcheck.id
  end
  healthchecks += read_existing_healthchecks(route53, response.marker) if response.is_truncated
  healthchecks
end

def read_existing_elbs(elb, marker=nil)
  elbs = []
  response = elb.describe_load_balancers({marker: marker})
  for balancer in response.load_balancer_descriptions
    elbs.push(balancer.dns_name)
  end
  elbs += read_existing_elbs(elb, response.next_marker) if not response.next_marker.nil?
  elbs
end

def init_options
  options = {}
  OptionParser.new do |opts|
    opts.banner = "Usage: adddomains.rb [options]"
    opts.on("-n", "--groupname NAME", "Name of group") { |v| options[:group_name] = v }
    opts.on("-b", "--balancer NAME", "Name of balancer") { |v| options[:balancer_name] = v }
    opts.on("-w", "--webgroup-is-group", "Webgroup is the same s group") { |v| options[:groupiswebgroup] = v }
    opts.on("-v", "--[no-]verbose", "Run verbosely") { |v| options[:verbose] = v }
    opts.on("-D", "--[no-]Dev", "Dev environment, attach to commonbaldev") { |v| options[:isDev] = v }
    opts.on("-E", "--[no-]Elb", "attach to ELB, name should be defined with -b") { |v| options[:useElb] = v }
    opts.on('-h', '--help', 'Displays Help') { |v| puts opts }
  end.parse!
  if options[:group_name].nil? or (options[:useElb] and options[:balancer_name].nil?)
    raise OptionParser::MissingArgument
  end
  options
end

options = init_options()
verbose = options[:verbose]
environment = options[:group_name]
isDev = options[:isDev]
useElb = options[:useElb]
############################################################################### 
#  0. init variables.
#  By default balancer name considered to be <group>bal, e.g tsjfprodbal
#  can be overriden by -n key
#####
if options[:balancer_name].nil? and not isDev
  balname = "#{environment}bal"
elsif isDev
  balname = "sharedbalancer"
else
  balname = options[:balancer_name]
end

HOSTED_ZONE = "Z" 
DOMAIN = "#{environment}.apps.com"
ec2 = Aws::EC2::Resource.new
route53 = Aws::Route53::Client.new

###############################################################################
#  0.1 Recursively read existing records, topmost value is the name of hosted zone
#####

existing_records = read_existing_rrset(route53).uniq
HOSTED_ZONE_NAME = existing_records[0]
puts "Hosted zone name #{HOSTED_ZONE_NAME}" if verbose

####
# 1.0 Get list of existing load balancers
####
if useElb
  BALANCERS = read_existing_elbs(Aws::ElasticLoadBalancing::Client.new)
    .select{ | name | name.include?(balname) }
else
  BALANCERS=ec2.instances({
    filters: [{
      name: "tag:Name",
      values: ["#{balname}*"],
    }]
  })
end

primary_balancer = BALANCERS.first
pp "Primary balancer instance: #{primary_balancer}" if verbose
raise "Can not find load balancers for #{DOMAIN}. Create them first. Expected names are \"#{balname}*\", or override with -n key" if BALANCERS.first.nil?

response = route53.list_resource_record_sets({
  hosted_zone_id: HOSTED_ZONE,
})

###############################################################################
#  1.1 And creating healthcheck which will be pointing to check load balancer
#  Which we consider as primary (to fail back to second, see below)
#####
health_check_id = nil
existing_healthchecks = read_existing_healthchecks(route53)
if existing_healthchecks.keys.include?(DOMAIN)
  health_check_id = existing_healthchecks[DOMAIN] 
  puts "Found existing healthcheck for #{DOMAIN} : #{health_check_id}" if verbose
elsif isDev
  puts "Launched with isDev flag, will be attached to Commonbaldev, no need for healthceheck, bypassing"
elsif useElb
  puts "Launched with useELb flag, will be attached to #{BALANCERS.first}, no need for healthceheck, bypassing"
else
  puts "Can not find healthcheck for #{DOMAIN}.... Creating new one" if verbose
  resp = route53.create_health_check({
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
  puts "Health check ID: #{resp.data.health_check.id}, Adding Name tag: #{DOMAIN}-primary_bal-health"
  route53.change_tags_for_resource({
    resource_id: resp.data.health_check.id,
    resource_type: "healthcheck",
    add_tags: [{
      key: "Name",
      value: "#{DOMAIN}-primary_bal-health",
    }]
  })
  health_check_id = resp.data.health_check.id
end
if health_check_id.nil? and not (isDev or useElb)
  raise "Was not able find existing healthcheck, neither create new"
end

###############################################################################
#  2. Read server_names and server_aliases form dashboard
#     and filter the list to comply with HOSTED_ZONE
#####
webgroup = environment + 'web'
if options[:groupiswebgroup] or isDev or useElb
  webgroup = environment
end
puts "Webgroup: #{webgroup}" if options[:verbose]

DASHBOARD_API = "https://dashboard/v3/search/groups/"
uri = URI.parse(DASHBOARD_API + webgroup + '@')
puts "#{uri.to_json} >>>>>>>>>>>>>>>" if verbose
http = Net::HTTP.new(uri.host, uri.port, "proxy.org.com" , "80")
http.use_ssl = true
http.verify_mode = OpenSSL::SSL::VERIFY_NONE
request = Net::HTTP::Get.new(uri.request_uri)
response = http.request(request)
metadata = JSON.load(response.body)
puts "<<<<<<<<<<<<<<< METADATA" if verbose
pp metadata if verbose
puts ">>>>>>>>>>>>>>>" if verbose

dns_names = []
for webgroup in metadata.keys
  if metadata[webgroup].has_key?('sites')
    for site in metadata[webgroup]['sites'].keys
      dns_names.push(metadata[webgroup]['sites'][site]['servername'])
      for server_alias in metadata[webgroup]['sites'][site]['serveralias']
        dns_names.push(server_alias)
      end
    end
  end
end
puts "Configured domains for #{webgroup} are: #{dns_names.to_json}\n\n" if verbose
dns_names = dns_names.select{ | name | name.include?(HOSTED_ZONE_NAME) }
puts "Filtered to register in #{HOSTED_ZONE_NAME}: #{dns_names.to_json}" if verbose

recordset_changes = []
commonbaldevs = ['commonbaldev-prime', 'commonbaldev-sec']
dns_names.each do |name|
  i = 0
  BALANCERS.each do |balancer|
    resource_records = []
    resource_record_set = {
      name: name,
      ttl: 300,
      resource_records: resource_records,
    }
    action = existing_records.include?(name) ? "UPSERT" : "CREATE"
    change = {
      action: action,
      resource_record_set: resource_record_set
    }
    ### if we ar using ELB then BALANCERS are the list of public DNS names, and
    #actually there is only one entry
    if useElb
      puts name
      resource_record_set[:type] = "CNAME"
      resource_records.push(value: balancer )
      recordset_changes.push(change)
      i+=1
      next
    end
    # If its a dev environmens - creating two records pointing to two
    # commonbaldevs having the same weight
    if isDev
      puts name
      resource_record_set[:type] = "CNAME"
      resource_record_set[:set_identifier] = commonbaldevs[i]
      resource_record_set[:weight] = 1
      resource_records.push(value: "#{commonbaldevs[i%2]}.apps.org.com" )
      recordset_changes.push(change)
      i+=1
      next
    end
    #if its a prod env - create failover record.
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
      resource_record_set[:health_check_id] = health_check_id
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

pp batch.to_json if verbose
response = route53.change_resource_record_sets({
  :hosted_zone_id => HOSTED_ZONE,
  :change_batch => batch
})

id = response.change_info.id
print "Waiting for #{id}\n"

while response.change_info.status == "PENDING"
  response = route53.get_change({ id: id })
  sleep(5)
end
print "#{response.change_info.status} #{response.change_info.id}\n"
