require "bundler/gem_tasks"
require 'rake/clean'
require 'warbler'
require 'rack'
require 'rubocop/rake_task'

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
task :build => [:rubocop, :war]

task :default => [:server]

desc 'Bump the patch version in version.rb'
task :bump, [:version] do |t, args|
  raise 'Which version?' unless args[:version]
  fn = "lib/amplify/failover/version.rb"
  version_regex = /(\s*)VERSION\s*=\s*["'](\d+)\.(\d+)\.(\d+)["']/
  contents = File.open(fn) { |f| f.readlines }

  output = contents.map do |line|
    if line =~ version_regex
      line.gsub(version_regex, sprintf('\1VERSION = "\2.\3.%s"', args[:version]))
    else
      line
    end
  end
  File.open(fn, 'w') { |f| f.write(output.join) }
  puts "Bumped patch version to #{args[:version]}"
end


desc 'Run Rubocop'
task :rubocop do |t,args|
  Rubocop::RakeTask.new
end
