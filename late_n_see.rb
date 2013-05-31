class LateNSee
  attr_accessor :options

  def initialize(options={})
    @options = options
  end
  
  def call
    measurement = latency(options.fetch(:host) { default_gateway })
    record(measurement)
  end

  def latency(host)
    ping_results = ping!(host)
    Hash.new.tap do |res|
      res[:packet_loss] = ping_results[/([\d\.]+)% packet loss/, 1].to_f
      stats = [:min,:avg,:max,:stddev]
      if %r{^(rtt|round-trip) .* = (?<min>[\d+\.]+)/(?<avg>[\d+\.]+)/(?<max>[\d+\.]+)/(?<stddev>[\d+\.]+) ms} =~ ping_results
        stats.each { |stat| res[stat] = instance_eval(stat.to_s).to_f }
      end
    end
  end

  def ping!(host)
    count   = options.fetch(:count) { 1 }
    pinger  = %x{which ping 2>&1}.strip
    ping    = %x{#{pinger} -c #{count} -i 1 -q #{host}}
    ping    = %x{#{pinger} -c #{count} -q #{host}} unless $?.success?
    ping
  end

  def record(info, recorder=STDOUT)
    recorder.puts("#{options[:host]} => #{info}")
  end

  private

  def default_gateway
    netstat = %x{which netstat 2>&1}.strip
    route   = %x{#{netstat} -rn}
    route[/^(0\.0\.0\.0|default)\s+(\d+\.\d+\.\d+\.\d+)\s+/, 2]
  end

end

class Host
  def initialize(host)
    @host   = host
    @smoked = 0
  end

  def smoke
    LateNSee.new(:host => @host).()
  end
end

class Smoker
  def self.baconize(hosts)
    loop do
      hosts.each { |ip| Host.new(ip).smoke }
    end
  end
end

HOSTS = %w{84.45.120.152 84.45.120.153 10.1.1.254}

Smoker.baconize(HOSTS)
