require 'json'
require 'httpclient'
require 'puppetdb'
require 'inifile'

class Dropsonde
  require 'dropsonde/cache'
  require 'dropsonde/metrics'
  require 'dropsonde/monkeypatches'
  require 'dropsonde/version'

  @@pdbclient = nil
  @@settings  = {}
  def self.settings=(arg)
    raise "Requires a Hash to set all settings at once, not a #{arg.class}" unless arg.is_a? Hash
    @@settings = arg
  end

  def self.settings
    @@settings
  end

  def self.generate_schema
    puts JSON.pretty_generate(Dropsonde::Metrics.new.schema)
  end

  def self.list_metrics
    puts
    puts Dropsonde::Metrics.new.list
  end

  def self.generate_report(format)
    case format
    when 'json'
      puts JSON.pretty_generate(Dropsonde::Metrics.new.report)
    when 'human'
      puts
      puts Dropsonde::Metrics.new.preview
    else
      raise "unknown format"
    end
  end

  def self.submit_report(endpoint, port)
    client = HTTPClient.new()
    result = client.post("#{endpoint}:#{port}",
                  :header => {'Content-Type' => 'application/json'},
                  :body   => Dropsonde::Metrics.new.report.to_json
                )

    if result.status == 200
      data = JSON.parse(result.body)
      if data['newer']
        puts 'A newer version of the telemetry client is available:'
        puts "  -- #{data['link']}"
      else
        puts data['message']
      end
    else
      puts 'Failed to submit report'
      puts JSON.pretty_generate(result.body) if Dropsonde.settings[:verbose]
      exit 1
    end
  end

  def self.puppetDB
    return @@pdbclient if @@pdbclient

    config = File.join(Puppet.settings[:confdir], 'puppetdb.conf')

    return unless File.file? config

    server = IniFile.load(config)['main']['server_urls'].split(',').first

    @@pdbclient = PuppetDB::Client.new({
      :server => server,
      :pem    => {
          'key'     => Puppet.settings[:hostprivkey],
          'cert'    => Puppet.settings[:hostcert],
          'ca_file' => Puppet.settings[:localcacert],
      }
    })
  end

end
