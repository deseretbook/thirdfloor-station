#!/usr/bin/env ruby
require 'rubygems'

require 'multi_json'
require 'httparty'
require 'socket'

config_file_path = "./config.yml"

@config = YAML.load(File.new(config_file_path).read)

def data_points_url
  @config['base_url'] + @config['paths']['data_points']
end

def production?
  @config["environment"] == "production"
end

def report_http_error(response)
  if response.code.to_s =~ /^(1|2)\d{2}$/
    puts "HTTP success: #{response.code}"
    return false
  else
    raise "FATAL: HTTP Error: #{response.code}\n#{response.body}"
  end
end

# returns the first local (non-routable) IP address.
def local_ip
  @local_ip ||= Socket.ip_address_list.detect{|intf| intf.ipv4_private?}.ip_address
end

def default_headers
  {
    'Content-Type' => 'application/json',
    'Accepts' => 'application/json'
  }
end

response = HTTParty.get(
  "https://bookshelf-admin.deseretbook.com/admin/api/logs/rpm",
  :basic_auth => { :username => 'mnielsen', :password => 'KKll0099' }
)

report_http_error(response)

rpm_json = JSON.parse(response.body)

response = HTTParty.post(data_points_url,
  body: {
    station: {
      hostname: @config["hostname"],
      password: @config["password"],
      ip: local_ip
    },
    name: 'bookshelf_api_rpm',
    data: {
      rpm: rpm_json['total'],
      version_0: rpm_json["versions"]["0"],
      version_1: rpm_json["versions"]["1"]
    }
  }.to_json,
  headers: default_headers
)

report_http_error(response)

puts MultiJson.load(response.body).inspect

puts "Run complete."