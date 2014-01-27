require 'sequel'
require 'logger'
require 'jdbc/mysql'

module Amplify
module Failover
module MySQL

class MasterWatcher
  attr_reader :status, :active_master_id, :failover_state

  def initialize ( mysql_cfg, zk_cfg, misc_cfg = {})
    @status                 = :starting
    @logger                 = misc_cfg[:logger] || Logger.new($stderr)
    @watcher_server_id      = normalize_server_id(zk_cfg[:server_id])
    @active_master_id_znode = zk_cfg[:active_master_id_znode] || '/active_master_id'
    @state_znode            = zk_cfg[:state_znode]            || '/state'
    @tracking_table         = mysql_cfg['tracking_table']     || 'failover'
    @tracking_max_wait_secs = mysql_cfg['tracking_max_wait_secs'] || 600
    @tracking_poll_interval_secs = mysql_cfg['tracking_poll_interval_secs'] || 5

    # https://github.com/zk-ruby/zk/wiki/Events
    # use a Queue to coordinate between threads
    @queue = Queue.new

    zk_connect zk_cfg
    mysql_connect mysql_cfg
  end

  def mysql_connect ( mysql_cfg )
    Jdbc::MySQL.load_driver
    @db = Sequel.connect(adapter:        'jdbc',
                         uri:            mysql_cfg['uri'],
                         user:           mysql_cfg['user'],
                         password:       mysql_cfg['password'],
                         sql_log_level:  :debug,
                         logger:         @logger )

    create_tracking_table
  end

  def create_tracking_table
    @db.create_table? @tracking_table do
      primary_key :id
      column      :created_at, 'TIMESTAMP', :null => false
      Bignum      :version, :null => false
      DateTime    :mtime,   :null => false
    end
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
      java.lang.Thread.currentThread.setName('mysql-master-watcher')
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
#
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

  def process_queue_event ( type, value, meta )
    case type
    when :active_master_changed
      process_master_change(value, meta)
    end
  end

# Public: Does this server need to step up to active master?
  def step_up? (new_active_server_id)
    # if this server was not the active master and now has become the active master, step up
    @active_master_id != @watcher_server_id && new_active_server_id == @watcher_server_id
  end

# Public: Does this server need to step down from active master?
  def step_down? (new_active_server_id)
    # if this server was the active master and is no longer the active master, step down
    @active_master_id == @watcher_server_id && new_active_server_id != @watcher_server_id
  end

  def process_master_change ( new_active_server_id, meta )
    # do nothing if the value didn't actually change (for znode version changes)
    return if normalize_server_id(new_active_server_id) == active_master_id
    if failover_state != Amplify::Failover::COMPLETE
      @logger.warn "Transition currently in progress.  Not processing second transition.  #{@active_master_id_znode} may be incorrect."
      return
    end

    if step_up?(new_active_server_id)
      @active_master_id = new_active_server_id
      step_up(meta)

    elsif step_down?(new_active_server_id)
      @active_master_id = new_active_server_id
      step_down(meta)
    end
  end

  def step_up ( meta )
    @logger.info "This server will become the active master."
    set_failover_state Amplify::Failover::TRANSITION
    mysql_read_only false
    mysql_poll_for_tracker meta
    set_failover_state Amplify::Failover::COMPLETE
    @logger.info "Now in active mode."
  end

  def step_down ( meta )
    @logger.info "This server will become the passive master."
    mysql_read_only
    mysql_kill_connections
    mysql_insert_tracker meta
    @logger.info "Now in passive mode."
  end

  def failover_state
    @zk.get(@state_znode).first
  end

  def set_failover_state (state)
    @zk.create(@state_znode, state, or: :set, mode: :persistent)
  end

  def mysql_poll_for_tracker ( meta )
    total_time = 0
    start_time = Time.now

    # loop until the timeout is hit or the token is found
    begin
      found = mysql_tracking_token_found?(meta)
      unless found
        sleep @tracking_poll_interval_secs
        total_time = Time.now - start_time
      end
    end while total_time < @tracking_max_wait_secs && !found

    if total_time > @tracking_max_wait_secs
      @logger.info "Tracking token wait has expired."
    else
      @logger.info "Found tracking token."
    end
  end

  def mysql_tracking_token_found? (meta)
    @db[@tracking_table.to_sym].
      where(:version => meta.version).
      where('mtime >= ?', meta.mtime).count > 0
  end

  def mysql_insert_tracker (meta)
    @db[@tracking_table.to_sym].insert( :created_at => Time.now,
                                        :version    => meta.version,
                                        :mtime      => Time.at(meta.mtime/1000) )
  end

  # kill off any connections except for self and slave processes
#TODO: make this more graceful.
  def mysql_kill_connections
    @logger.info "Killing off database connections"
    mysql_with_slave_stopped do
      connections = @db[:information_schema__processlist].select(:id).
                      where('id != CONNECTION_ID()').
                      exclude(:User => 'system user').all

      connections.each { |row| @db["KILL #{row[:id]}"].update }
    end
  end

# run some code with the MySQL slave threads stopped
# This is primarily to avoid ungracefully killing the slave
# threads in mysql_kill_connections
  def mysql_with_slave_stopped
    slave_status = @db['SHOW SLAVE STATUS'].first
    @logger.info "Stopping slave threads if necessary."
    @db['STOP SLAVE IO_THREAD'].update   if slave_status[:Slave_IO_Running]  == 'Yes'
    @db['STOP SLAVE SQL_THREAD'].update  if slave_status[:Slave_SQL_Running] == 'Yes'
    yield
    @logger.info "Returning slave threads back to their previous state."
    @db['START SLAVE SQL_THREAD'].update if slave_status[:Slave_SQL_Running] == 'Yes'
    @db['START SLAVE IO_THREAD'].update  if slave_status[:Slave_IO_Running]  == 'Yes'
  end


  def mysql_read_only ( read_only = true )
    @db['SET GLOBAL read_only = ?', read_only ? 1 : 0].update
  end

# Public: Register ephemeral znode for this host
#
# Examples
#
#   register_self_with_zk
#
  def register_self_with_zk
    @zk.create('/masters', ignore: :node_exists)
    @zk.create("/masters/node-#{@watcher_server_id}", mode: :ephemeral)
  end

  # presently active or passive?
  def active_master?
    @logger.debug "@active_master_id = #{@active_master_id.inspect}"
    @watcher_server_id == @active_master_id
  end

  def watch_active_master_id_znode
    # set the watch
    begin
      zk_node = @zk.get(@active_master_id_znode, watch: true)
      result = { :value => zk_node.first, :meta => zk_node.last }
    rescue ZK::Exceptions::NoNode => e
      @logger.error "No ZNode exists at #{@active_master_id_znode}.  Create this znode with the server ID of the presently active master."
      @zk.stat(@active_master_id_znode, watch: true)
      result = nil
    end

    result
  end

# Public: set watches and get initial values for watched znodes
  def watch
    @zk_watch = @zk.register(@active_master_id_znode) do |event|
      znode = watch_active_master_id_znode
      if event.node_changed? || event.node_created?
        @logger.info "#{@active_master_id_znode} changed.  New value: #{znode[:value]}"
        @queue.push( :type  => :active_master_changed,
                     :value => znode[:value],
                     :meta  => znode[:meta] )
      end
    end

    znode = watch_active_master_id_znode
    @active_master_id = normalize_server_id znode[:value]
  end

  def normalize_server_id ( value )
    value.is_a?(String) ? value : value.to_s
  end

end
end
end
end
