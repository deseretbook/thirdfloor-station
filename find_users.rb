#!/usr/bin/env ruby
require 'rubygems'

require 'multi_json'
require 'httparty'

config_file_path = "./config.yml"

@config = YAML.load(File.new(config_file_path).read)

def users_url
  @config['base_url'] + @config['paths']['users']
end

def user_locations
  @config['base_url'] + @config['paths']['user_locations']
end

def production?
  @config["environment"] == "production"
end

def hcitool_sees_address?(bt_addr)
  if File.exists?(@config["hcitool_path"])
    query_hcitool(bt_addr) != ""
  else
    puts "WARNING: #{@config["hcitool_path"]} not found. Returning false."
    false
  end
end

def report_http_error(response)
  if response.code.to_s =~ /^(1|2)\d{2}$/
    puts "HTTP success: #{response.code}"
    return false
  else
    raise "FATAL: HTTP Error: #{response.code}\n#{response.body}"
  end
end

def bluetooth_address_present?(bt_addr)
  puts "Querying for: #{bt_addr}"
  if production?
    hcitool_sees_address?(bt_addr)
  else
    if @config["test_hcitool_response"]
      puts "INFO: returning 'test_hcitool_response' value as boolean."
      !!@config["test_hcitool_response"]
    else
      hcitool_sees_address?(bt_addr)
    end
  end
end

def default_headers
  {
    'Content-Type' => 'application/json',
    'Accepts' => 'application/json'
  }
end

response = HTTParty.get(users_url, headers: default_headers)

report_http_error(response)

users_found = []
MultiJson.load(response.body)["users"].each do |user|
  puts "Looking for #{user["first_name"]} #{user["last_name"]} (#{user["bluetooth_address"]})"
  if bluetooth_address_present?(user["bluetooth_address"])
    puts "\tfound."
    users_found << user
  else
    puts "\tnot found."
  end
end

puts "Found #{users_found.size} users. Reporting."
response = HTTParty.post(user_locations,
  body: {
    station: {
      hostname: @config["hostname"],
      password: @config["password"]
    },
    user_ids: users_found.map{|u|u["id"]}
  }.to_json,
  headers: default_headers
)

report_http_error(response)

puts MultiJson.load(response.body).inspect

puts "Run complete."