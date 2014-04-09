#!/usr/bin/env ruby
require "fallen"
require "fallen/cli"
require 'yaml'
require 'httparty'
require 'multi_json'

module DeploymentFanfare
  extend Fallen
  extend Fallen::CLI

  def self.run
    load_config
    while running?
      response = HTTParty.head(data_points_url, headers: default_headers)

      report_http_error(response)

      last_id = response.headers["x-last-data-point-id"]
      if @previous_id.nil?
        puts "no data yet, waiting till next loop"
      else
        
        if last_id != @previous_id
          puts "NEW DEPLOY! #{last_id}"
          if play_sound?
            cmd = "#{player_command} #{sound_file}"
            puts "playing sound with '#{cmd}'"
            `#{cmd}`
          end
        else
          puts "Nothing new: #{@previous_id}"
        end

      end

      @previous_id = last_id
      
      puts "\tsleeping for #{loop_delay} seconds"
      sleep(loop_delay)
    end
  end

  def self.usage
    puts "Monitors thirdfloor installation for newrelic deployments"
    puts fallen_usage
  end

  def self.load_config
    @config = YAML.load(File.open('./config.yml').read)
  end

  def self.loop_delay
    @config['deployment_fanfare']['delay']
  end

  def self.play_sound?
    @config['deployment_fanfare']['play_sound']
  end

  def self.sound_file
    @config['deployment_fanfare']['sound_file']
  end

  def self.player_command
    @config['deployment_fanfare']['sound_player_command']
  end

  def self.data_points_url
    "#{@config['base_url']}#{@config['paths']['data_points']}?name=newrelic&has_key=deployment&cache_time=#{loop_delay}"
  end

  def self.default_headers
    {
      'Content-Type' => 'application/json',
      'Accepts' => 'application/json'
    }
  end

  def self.report_http_error(response)
    if response.code.to_s =~ /^(1|2)\d{2}$/
      # puts "HTTP success: #{response.code}"
      return false
    else
      raise "FATAL: HTTP Error: #{response.code}\n#{response.body}"
    end
  end

end

case Clap.run(ARGV, DeploymentFanfare.cli).first
when "start"
  DeploymentFanfare.start!
when "stop"
  DeploymentFanfare.stop!
else
  DeploymentFanfare.usage
end