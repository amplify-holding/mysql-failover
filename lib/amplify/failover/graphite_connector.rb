require 'json'
require 'zk'
require 'logger'

module Amplify
module Failover

# this class exists to provide a no-op interface
# in case there is no graphite server specified
# and also to prefix metric names
class GraphiteConnector
  attr_reader :graphite
  def initialize ( graphite_config = {}, misc_cfg = {} )
    begin
      @graphite = Graphite.new( :host => graphite_config[:host],
                                :port => graphite_config[:port] )
    rescue
      @graphite = nil
    end

    @prefix = graphite_config[:prefix]
    @logger = misc_cfg[:logger]
  end

  def prefix_metric ( metric )
    [@prefix,metric].compact.join('.')
  end

  def prefix_metrics ( metrics )
    Hash[metrics.map { |k,v| [prefix_metric(k), v] }]
  end

  def send_metrics ( metrics = {} )
    begin
      @graphite.send_metrics(prefix_metrics(metrics)) if @graphite
    rescue => e
      @logger.error "Unable to send metrics to graphite: #{e}" if @logger
    end
  end


  def send_timer ( metric )
    t1 = Time.new
    yield
    t2 = Time.new
    self.send_metrics( metric => (t2-t1) )
  end
end
end
end
