require 'rubygems'
require 'bundler'
Bundler.require

# make sure SLF4J is loaded on the main thread
# so it can properly initialise itself
require 'amplify-slf4j'
Amplify::SLF4J['amplify-failover']

require_relative 'lib/application'
run Sinatra::Application
