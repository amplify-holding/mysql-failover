module Amplify
module Failover

class Watchdog
  def initialize ( zk_cfg, misc_cfg )
    @logger   = misc_cfg[:logger] || Logger.new($stderr)
    @graphite = misc_cfg[:graphite]
    @thread_status   = :starting

    # https://github.com/zk-ruby/zk/wiki/Events
    # use a Queue to coordinate between threads
    @queue = Queue.new

    zk_connect zk_cfg
  end

# Public: Connect to ZooKeeper.  Set @zk instance variable to
#         ZooKeeper connection
#
# zk_cfg - Hash of ZooKeeper configuration :
#   'hosts'  => Array of hostname:port for ZooKeeper ensemble
#   'chroot' => The ZK node to chroot to
#
# Examples
#
#   zk_connect({ 'hosts' => ['zk1.example.com:2181','zk2.example.com:2182'],
#                'chroot' => '/my/znode' })
#   # => ZK::Client
#
# Returns: ZK::Client object.
#
  def zk_connect ( zk_cfg )
    ZK.logger = @logger
    @zk = ZK.new(zk_cfg['hosts'].join(','), chroot: zk_cfg['chroot'])
    @zk.on_expired_session do
      @logger.info "ZK Session expired.  Reconnecting and resetting watches."
      @zk.reopen
      register_self_with_zk
      watch
    end
  end

# Public: Put this class into the background and execute the run method
#
# Examples
#
#   background!
#
  def background! ( thread_name = nil)
    Thread.new do
      java.lang.Thread.currentThread.setName(thread_name) if thread_name
      begin
        @zk.reopen
        run
        @logger.info "Main thread running in background"
      rescue => e
        @logger.fatal 'Unrecoverable worker exception: ', e
        @thread_status = :stopped
      end
    end
  end

  def running?
    @thread_status == :running
  end

# Public: Start the main watcher loop
#
# The register_self_with_zk,  watch, and process_queue_event classes must be implemented
# by a subclass
#
# Examples
#
#   run
#
  def run
    @logger.info "Running"
    @thread_status = :running

    register_self_with_zk
    register_callbacks
    watch
    loop do
      queue_event = @queue.pop
      Amplify::Failover::GracefulTrap.critical_section(%w{INT TERM}, @logger) do
        process_queue_event(queue_event[:type], queue_event[:value], queue_event[:meta])
      end
    end
    @thread_status = :stopped
  end

  def status
    running? && zk_connected?
  end

  def zk_connected?
    begin
      @zk.connected?
    rescue
      false
    end
  end


  def status_hash
    {
      status: (self.status ? 'ok' : 'ko'),
      worker: @thread_status,
      zk_connected: zk_connected?,
      host: Socket.gethostbyname(Socket.gethostname).first
    }
  end

  def register_callbacks
    #implement in a subclass
  end

  def watch
    #implement in a subclass
  end

  def register_self_with_zk
    # implement in a subclass
  end

  def process_queue_event
    #implement in a subclass
  end

  def register_self_with_zk
    # implement in a subclass
  end

end

end
end
