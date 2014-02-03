require 'json'
require 'sinatra'
require 'sinatra/json'
require 'sinatra/config_file'
require 'amplify/failover'
require 'zk'
require 'pp'

@logger = Amplify::SLF4J['amplify-failover']

config_filename = (ENV['FAILOVER_CONFIG'] || java.lang.System.getProperty('failover.config', 'config/failover.yaml'))

@logger.info "Loading config from #{config_filename}"
config_file config_filename

disable :run
disable :logging

set :root, File.expand_path(File.join(File.dirname(__FILE__), ".."))

VERSION_FILE = File.join(settings.root, 'config', 'version.txt')
VERSION_INFO = File.file?(VERSION_FILE) ? File.read(VERSION_FILE).strip.split(',') : 'dev'

user_options = {}
user_options[:env] = (ENV['ENV'] || '').downcase
user_options[:sf_sandbox] = user_options[:env] == 'dev'


WATCHDOG = case settings.mode
when "mysql"
  Amplify::Failover::MySQLWatchdog.new(settings.mysql, settings.zookeeper, logger: @logger)
when "application"
  Amplify::Failover::AppWatchdog.new(settings.application, settings.zookeeper, logger: @logger)
end

WATCHDOG.background!

get '/status' do
  status = {
    status: (WATCHDOG.running? ? 'ok' : 'ko'),
    version: VERSION_INFO,
#    worker: WORKER.status
  }
  cache_control :private, :no_cache, :no_store
  json status
end

get '/ping' do
  cache_control :private, :no_cache, :no_store
  "PONG"
end

get '/start' do
  WATCHDOG.background! if WATCHDOG.status != :running
end
