#!/usr/bin/env ruby

require 'json'
require 'uri'
require 'net/http'
require 'net/https'
require 'securerandom'

def fetch(uri_str, limit = 10)
  raise 'HTTP redirect too deep' if limit == 0

  url = URI(uri_str)
  req = Net::HTTP::Get.new(url.path, { 'User-Agent' => 'Mozilla/5.0 (etc...)' })
  response = Net::HTTP.start(url.host, url.port, :use_ssl => url.scheme == 'https') { |http| http.request(req) }
  case response
  when Net::HTTPSuccess     then response
  when Net::HTTPRedirection then fetch(response['location'], limit - 1)
  else
    response.error!
  end
end

def set_pr_status(validator, state, description, url)
  headers = {
    "Authorization" => "token #{ENV['GITHUB_AUTH_TOKEN']}",
  }
  data = {
    "state" => state,
    "target_url" => "http://server/job/github_test/lastBuild/",
    "description" => description,
    "context" => "jenkins/puppet_validator (#{validator})"
  }.to_json

  http = Net::HTTP.new(url.host, url.port)
  http.use_ssl = url.scheme == 'https'
  response = http.post(url.path, data, headers)
  raise response.error! unless response.is_a? Net::HTTPSuccess
end

from_github = JSON.load(ARGF.read)

if ! from_github['action'].include? "opened"
  exit
end

patch = fetch(from_github['pull_request']['patch_url'])
          .body
patch_filename = "/tmp/#{SecureRandom.uuid.to_str}.patch"
repository_name = from_github['repository']['name']

puts "===================="
printf "%s:\n%s", patch_filename, patch
puts "===================="

File.open(patch_filename, "w") { | f |  f.write(patch) }

puts `
/usr/bin/git apply --reject  --whitespace=fix #{patch_filename}
/usr/bin/git add -A
`

url = URI(from_github['pull_request']['statuses_url'])

clean_run = true
Dir.glob("/opt/validate_*.sh") do | validator |
  response = set_pr_status(validator, "pending", "Pending validation", url)
  puts validator_output = `/bin/bash -c #{validator}`
  check_state = "success"
  check_description = "Validation passed"
  if $?.exitstatus != 0
      check_state = "failure"
      check_description = validator_output
  end
  set_pr_status(validator, check_state, check_description, url)
  clean_run = (check_state == "success" and clean_run)
  puts "#{validator}: #{$?.exitstatus}"
end
raise "Validation failed" unless clean_run
