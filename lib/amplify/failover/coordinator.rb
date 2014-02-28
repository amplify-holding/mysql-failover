# this code shares a lot in common with the watchdogs, particularly because it watches
# the state znode.  Consider refactoring
module Amplify
module Failover

class Coordinator
  MASTER_ROOT = '/masters'

  attr_reader :zk
  attr_accessor :logger

  def initialize ( zk_cfg, misc_cfg = {} )
    @zk_cfg = zk_cfg
    @active_master_id_znode = @zk_cfg['active_master_id_znode'] || '/active_master_id'
    @state_znode            = @zk_cfg['state_znode']            || '/state'
    @queue = Queue.new

    @logger = misc_cfg[:logger] || Logger.new($stderr)
    ZK.logger = @logger
    @zk = ZK.new(@zk_cfg['hosts'].join(','), chroot: @zk_cfg['chroot'])

    @zk.on_expired_session do
      @logger.info "ZK Session expired.  Reconnecting and resetting watches."
      @zk.reopen
      watch
    end
  end

  def clean
    ZK::Locker.cleanup(@zk)
  end

# Get an Array of all the master ids connected to ZooKeeper ephemerally
  def connected_master_ids
    begin
      znodes = @zk.children(MASTER_ROOT)
      ids = znodes.map { |znode| @zk.get(File.join(MASTER_ROOT, znode)).first }
    rescue => e
      return nil
    end
    # the master root could exist but still have no children, so return nil
    znodes.empty? ? nil : ids
  end

  def active_master_id
    begin
      @zk.get(@active_master_id_znode).first
    rescue => e
      nil
    end
  end

# Generate a String for display that outputs all the connected masters and
# has a * next to the currently active node.
  def active_master_pretty
    node_list = self.connected_master_ids.map do |id|
      if id == self.active_master_id
        "* #{id}"
      else
        "  #{id}"
      end
    end

    "Available fail over targets (* denotes currently active master):\n\n" + node_list.join("\n")
  end

  def trigger_failover! ( server_id )
    if self.active_master_id == server_id
      @logger.fatal "#{server_id} is already active master.  Can't continue"
      return false
    end

    lock = @zk.exclusive_locker('failover_in_progress')

    unless lock.lock(wait: false)
      raise "A fail over is already in progress"
    end

    begin
      @logger.info "Failing over to #{server_id}..."
      @zk.create(@active_master_id_znode, server_id, or: :set)
      wait_for_failover_complete
    ensure
      lock.unlock
    end

    true
  end

  def wait_for_failover_complete
    watch
    loop do
      queue_event = @queue.pop
      if queue_event[:type] == :state_changed
        @logger.info "State changed to #{queue_event[:value]}"

        case queue_event[:value]
        when Amplify::Failover::STATE_TRANSITION
          on_state_transition
        when Amplify::Failover::STATE_COMPLETE
          on_state_complete
          break
        when Amplify::Failover::STATE_ERROR
          on_state_error
          raise
        end
      end

    end
  end

  def on_state_transition
    @logger.info "Failover in progress..."
  end

  def on_state_complete
    @logger.info "Failover complete."
  end

  def on_state_error
    @logger.fatal "Failover failed!  May be in inconsistent state"
  end

  def watch_state_znode
    @zk.stat(@state_znode, watch: true)
  end

  def watch
    @zk_watch = @zk.register(@state_znode) do |event|
      if event.node_changed? || event.node_created?
        state = @zk.get(@state_znode, watch:true).first
        @logger.info "#{@state_znode} changed.  New value: #{state}"
        @queue.push( :type  => :state_changed,
                     :value => state )
      end
    end

    watch_state_znode
  end


  def server_id_exists? ( server_id )
    (self.connected_master_ids || []).include? server_id
  end

end

end
end
