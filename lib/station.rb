require 'yaml'
require 'digest'

class Station
  def initialize(config_file_path='./config.yml')
    @config_file_path = config_file_path
    load_config
  end

  def config_file_path
    @config_file_path
  end

  def config_file_data
    File.open(config_file_path).read
  end

  def load_config
    @config = YAML.load(config_file_data)
  end

  def config_file_mtime
    File.mtime(config_file_path)
  end

  def config_check_delay
    (@config['config_check_delay'] || 30).to_i
  end

  def exit_if_config_changed?
    !!@config['exit_if_config_changed']
  end

  def check_for_config_change
    if @previous_config_mtime
      current_config_mtime = config_file_mtime
      if @previous_config_mtime != current_config_mtime
        puts "Config file changed! Reloading config."
        load_config
        if exit_if_config_changed?
          puts "Exiting."
          exit
        end
        @previous_config_mtime = current_config_mtime
      end
    else
      @previous_config_mtime = config_file_mtime
    end
  end

  def sleep
    puts "sleeping for #{config_check_delay} seconds."
    super(config_check_delay)
  end

end