require 'logger'


module Amplify
module Failover
class AppWatchdog

  attr_reader :status, :failover_state

  def initialize ( app_cfg, zk_cfg, misc_cfg = {})
    @status                 = :starting
    @logger                 = misc_cfg[:logger] || Logger.new($stderr)
    @state_znode            = zk_cfg['state_znode']       || '/state'
    @client_data_znode      = zk_cfg['client_data_znode'] || '/client_data'
    @cmd_on_transition      = app_cfg['cmd_on_transition']
    @cmd_on_complete        = app_cfg['cmd_on_complete']
    @cmd_on_error           = app_cfg['cmd_on_error']

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
  end

# Public: Put this class into the background and execute the run method
#
# Examples
#
#   background!
#
  def background!
    Thread.new do
      java.lang.Thread.currentThread.setName('app-master-watcher')
      begin
        @zk.reopen
        run
        @logger.info "Main thread running in background"
      rescue => e
        @logger.fatal 'Unrecoverable worker exception: ', e
        @status = :stopped
      end
    end
  end

  def running?
    @status == :running
  end


# Public: Start the main watcher loop
# Examples
#
#   run
#
  def run
    @logger.info "Running"
    @status = :running

    register_self_with_zk
    watch
    loop do
      queue_event = @queue.pop
      process_queue_event(queue_event[:type], queue_event[:value], queue_event[:meta])
    end
    @status = :stopped
  end

  def process_state_change (state)
    @logger.info "State changed to #{state}"

    case state
    when Amplify::Failover::STATE_TRANSITION
      on_state_transition
    when Amplify::Failover::STATE_COMPLETE
      on_state_complete
    when Amplify::Failover::STATE_ERROR
      on_state_error
    end
  end

  def exec_cmd (cmd)
    @logger.info "Executing \`#{cmd}\`"
    %x[#{cmd}]
  end

  def on_state_transition
    exec_cmd @cmd_on_transition
  end

  def on_state_complete
    exec_cmd @cmd_on_complete
  end

  def on_state_error
    exec_cmd @cmd_on_error
  end

  def process_queue_event ( type, value, meta )
    case type
    when :state_changed
      process_state_change(value)
    end
  end


# Public: Register ephemeral znode for this host
#
# Examples
#
#   register_self_with_zk
#
  def register_self_with_zk
    @zk.create('/clients', ignore: :node_exists)
    @zk.create("/clients/client-", mode: :ephemeral_sequential)
  end

  def watch_state_znode
    # set the watch
    begin
      zk_node = @zk.get(@state_znode, watch: true)
      result = { :value => zk_node.first, :meta => zk_node.last }
    rescue ZK::Exceptions::NoNode => e
      @logger.error "No ZNode exists yet at #{@state_znode}.  This will be created by the MySQLWatchdog."
      @zk.stat(@state_znode, watch: true)
      result = nil
    end

    result
  end

# Public: set watches and get initial values for watched znodes
  def watch
    @zk_watch = @zk.register(@state_znode) do |event|
      znode = watch_state_znode
      if event.node_changed? || event.node_created?
        @logger.info "#{@state_znode} changed.  New value: #{znode[:value]}"
        @queue.push( :type  => :state_changed,
                     :value => znode[:value],
                     :meta  => znode[:meta] )
      end
    end

    znode = watch_state_znode
  end

end
end
end
