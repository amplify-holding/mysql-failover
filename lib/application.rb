require 'json'
require 'sinatra'
require 'sinatra/json'

#require_relative 'worker'

disable :run
disable :logging

set :root, File.expand_path(File.join(File.dirname(__FILE__), ".."))

VERSION_FILE = File.join(settings.root, 'config', 'version.txt')
VERSION_INFO = File.file?(VERSION_FILE) ? File.read(VERSION_FILE).strip.split(',') : 'dev'

user_options = {}
user_options[:env] = (ENV['ENV'] || '').downcase
user_options[:sf_sandbox] = user_options[:env] == 'dev'
#config_path = java.lang.System.getProperty('worker.config')
#user_options[:config_path] = config_path unless config_path.nil?

#WORKER = Worker.new user_options
#WORKER.background

get '/status' do
  status = {
#    status: (WORKER.running? ? 'ok' : 'ko'),
    version: VERSION_INFO,
#    worker: WORKER.status
  }
  cache_control :private, :no_cache, :no_store
  json status
end
