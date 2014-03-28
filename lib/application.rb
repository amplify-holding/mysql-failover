# coding: utf-8
require 'sinatra'
require 'sinatra/json'
require 'sinatra/config_file'
require 'amplify/failover'
require 'pp'

def config_filename
  ENV['FAILOVER_CONFIG'] || java.lang.System.getProperty('failover.config', 'config/failover.yaml')
end

@logger = Amplify::SLF4J['amplify-failover']
@logger.level = ::Logger::Severity::DEBUG

@logger.info "Loading config from #{config_filename}"
config_file config_filename

disable :run
disable :logging

set :root, File.expand_path(File.join(File.dirname(__FILE__), '..'))

VERSION_FILE = File.join(settings.root, 'config', 'version.txt')
VERSION_INFO = File.file?(VERSION_FILE) ? File.read(VERSION_FILE).strip.split(',') : 'dev'

user_options = {}
user_options[:env] = (ENV['ENV'] || '').downcase
user_options[:sf_sandbox] = user_options[:env] == 'dev'

begin
  graphite_settings = settings.graphite
rescue
  graphite_settings = nil
end
graphite_connector = Amplify::Failover::GraphiteConnector.new(graphite_settings, logger: @logger)

WATCHDOG = case settings.mode
           when 'mysql'
             Amplify::Failover::MySQLWatchdog.new(
               settings.mysql,
               settings.zookeeper,
               logger: @logger,
               graphite: graphite_connector
             )
           when 'application'
             Amplify::Failover::AppWatchdog.new(
               settings.application,
               settings.zookeeper,
               logger: @logger,
               graphite: graphite_connector
             )
           end

WATCHDOG.background!

get '/status' do
  status = WATCHDOG.status_hash.merge(version: VERSION_INFO)
  cache_control :private, :no_cache, :no_store
  json status
end

get '/ping' do
  cache_control :private, :no_cache, :no_store
  WATCHDOG.status ? 'PONG' : 'FAIL'
end

get '/start' do
  WATCHDOG.background! if WATCHDOG.status != :running
end
