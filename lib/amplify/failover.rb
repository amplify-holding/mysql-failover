require "amplify/failover/version"
require "amplify/failover/mysql"

module Amplify
  module Failover
    # states
    TRANSITION = 'transitioning'
    COMPLETE   = 'complete'
    ERROR      = 'complete'
    # Your code goes here...
  end
end
