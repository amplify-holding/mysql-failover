require 'simple-graphite'

%w{version watchdog mysql app coordinator graphite_connector graceful_trap}.each do |lib|
  require "amplify/failover/#{lib}"
end

module Amplify
  module Failover
    # states
    STATE_TRANSITION = 'transitioning'
    STATE_COMPLETE   = 'complete'
    STATE_ERROR      = 'error'
  end
end
