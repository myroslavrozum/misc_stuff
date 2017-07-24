#!/usr/bin/env ruby

require 'json'
require 'uri'
require 'net/http'
require 'securerandom'
require 'openssl'

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

def set_pr_status(state, description, url)
  Net::HTTP.new(url.host, url.port) { | http |
    http.use_ssl = url.scheme == 'https'
    headers = {
      "Authorization" => "token #{ENV['OAUTH']}",
    }

    data = {
      "state" => state,
      "target_url" => "http://jenkinssrvr:8080/job/github/lastBuild/",
      "description" => description,
      "context" => "jenkinssrvr/validator"
    }.to_json
    http.post(url.path, data, headers)
  }
end

data = JSON.load(ARGF.read)

patch = fetch(data['pull_request']['patch_url'])
          .body
patch_filename = "/tmp/#{SecureRandom.uuid.to_str}.patch"

puts "===================="
printf "%s:\n%s", patch_filename, patch
puts "===================="

File.open(patch_filename, "w") { | f |  f.write(patch) }

puts `/usr/bin/git apply #{patch_filename}`
puts `/usr/bin/git add -A`

url = URI(data['pull_request']['statuses_url'])

response = set_pr_status("pending", "Pending validation", url)

system("/opt/validate_puppet.sh")

check_state = "success"
check_description = "Validation passed"
if $?.exitstatus != 0
  check_state = "failure"
  check_description = "Validation failed"
end
set_pr_status(check_state, check_description, url)

raise "Validation failed" unless check_state == "success"
