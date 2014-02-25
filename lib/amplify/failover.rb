require 'simple-graphite'

require "amplify/failover/version"
require "amplify/failover/watchdog"
require "amplify/failover/mysql"
require "amplify/failover/app"
require "amplify/failover/coordinator"
require "amplify/failover/graphite_connector"

module Amplify
  module Failover
    # states
    STATE_TRANSITION = 'transitioning'
    STATE_COMPLETE   = 'complete'
    STATE_ERROR      = 'error'
    # Your code goes here...
  end
end
