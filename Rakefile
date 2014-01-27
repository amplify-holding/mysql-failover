require "bundler/gem_tasks"
require 'rake/clean'
require 'warbler'
require 'rack'

CLEAN.include('dist')
CLEAN.include('*.jar')
CLEAN.include('*.war')
CLEAN.include('*.log')

Warbler::Task.new

desc "Run the server, default port 9292"
task :server, :port do |task, args|
  Dir['java/lib/*.jar'].each { |jar| require jar }
  Dir['java/local/*.jar'].each { |jar| require jar }
  args.with_defaults(:port => 9292)
  Rack::Server.new(config: 'config.ru', Port: args[:port]).start
end

desc 'build WAR'
#task :build => [:clean, :spec, 'spec:integration', :war]
task :build => [:war]

task :default => [:server]
