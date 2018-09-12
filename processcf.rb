#!/usr/bin/env ruby

require 'aws-sdk'
require 'json'
require 'securerandom'
require 'erb'
require 'yaml'
require 'pp'

input = JSON.load(ARGF.read)

###########################################################################################
# 1. Prepare Puppet and Yaml
###########################################################################################
keyslist = []
consul_templates = []
sites = {}
port = input['Port']
group = input['Group']
environment_aliases = input['EnvAliases']
gituser_aliases = environment_aliases.values
classname = group+input['EnvironmentType']

for environment in input['Sites'].keys
  for site in input['Sites'][environment].keys
    consul_template_params = []
    site_env = site+environment
    #Here and below strings are joined like this to have single quoted values
    consul_template_params.push('/etc/consul-templates/' + site_env + '-settings.inc.tmpl')
    consul_template_params.push('/var/www/site-php/' + site_env + '/' + site_env + '-settings.inc')
    consul_template_params.push('')
    consul_templates.push( consul_template_params )
    
    combined = site+environment
    keyslist.push(combined)
    rdsinstancename = 'vpc-' + group + '-dev'# + environment
    if ! input['RDSInstanceName'].empty?
      rdsinstancename = input['RdsInstanceName']
    end
  
    sites[combined] = {
      'environment' => environment_aliases[environment],
      'subscription' => group,
      'shortname' => combined,
      'servername' => input['Sites'][environment][site]['servername'],
      'serveralias' => input['Sites'][environment][site]['serveralias'],
      'documentroot' => group + environment + '/docroot',
      'mysqlhost' => rdsinstancename + '.xxx.us-east-1.rds.amazonaws.com',
      'database' => input['Sites'][environment][site]['database'],
      'username' => input['Sites'][environment][site]['username'],
      'password' => input['Sites'][environment][site]['password'],
      'giturl' => '',
      'sitefolder' => combined,
      'port' => port
    }
    port += 1
  end
end

puts '######################################'
puts '# 1. Prepare Puppet and Yaml'
puts '######################################'
manifest_erb = File.read('./init.pp.erb')
renderer = ERB.new(manifest_erb,0,'<>')


puts rendered = renderer.result()
File.open('./init.pp', 'wb') do |file|
  file.write(rendered)
end

framework_description = {}
environmentType = input['EnvironmentType']
framework_description[classname] = {
    'public' => true,
    'vpc_name' => 'publisher',
    'env' => environmentType,
    'eip' =>  false,
    'balancer' => 'none',
    'zones' => 'ac',
    'image_type' => input['WebInstanceType'],
    'min_servers' => 0,
    'max_servers' => 1,
    'root_size' => input['WebStorageSize'],
    'security_group' => 'template',
    'group' => input['Group'] + environmentType,
  }

puts framework_description.to_yaml
File.open(input['Group'] + environmentType + '.yml', 'wb') do |file|
  file.write(framework_description.to_yaml)
end

puts '######################################'
puts '# 2. Prepare CloudFormation template'
puts '######################################'
s3 = Aws::S3::Client.new

chunk = ''
resp = s3.get_object(bucket: 'bucket', key: 'app_new.template') do |portion|
  chunk += portion
end
# 
parameters2inputs = {
  DbCapacity: 'RDSStorageSize',
  DbInstanceName: 'RDSInstanceName',
  DbInstanceType: 'DatabaseInstanceType',
  DbName: 'DatabasesToCreate',
  DbPassword: 'RDSSuperPassword',
  DbReadReplica: 'ReplicaNeeded',
  DbUser: 'RDSUser',
  EnvironmentTag: 'EnvironmentType',
  HostInstanceType: 'WebInstanceType',
  HostPrefix: 'Group',
  PublicDnsName: 'Domains',
  WebAmiImage: 'AmiId'
}
#
cf_template = JSON.load(chunk)

#parameters2inputs.each do | key, value |
#  group = input['Group']
#  if input[value] != ''
#    if value == 'Domains'
#      cf_template['Parameters'][key.to_s]['Default'] = input['Sites'][environmentType][group+environmentType]['servername']
#    else
#      cf_template['Parameters'][key.to_s]['Default'] = input[value].to_s
#    end
#  else
#    if value == 'Group'
#      cf_template['Parameters'][key.to_s]['Default'] = group+environmentType
#    elsif value == 'RDSInstanceName'
#      cf_template['Parameters'][key.to_s]['Default'] = 'vpc-' + group + '-' environmentType
#    elsif value == 'Domains'
#      cf_template['Parameters'][key.to_s]['Default'] = group + environmentType + '.apps.com'
#    elsif value == 'DatabasesToCreate'
#      cf_template['Parameters'][key.to_s]['Default'] = (group + environmentType[0]).upcase
#    end
#  end
#end
#
puts cf_template
s3.put_object(bucket: 'bucket',
              key: input['Group'] + '-' + environmentType + '.template',
              body: cf_template.to_json)

puts resp.body
puts s3.waiter_names
