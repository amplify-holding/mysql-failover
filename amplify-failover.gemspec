# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'amplify/failover/version'

Gem::Specification.new do |spec|
  spec.name          = "failover"
  spec.version       = Amplify::Failover::VERSION
  spec.authors       = ["Aaron Brown"]
  spec.email         = ["abrown@amplify.com"]
  spec.description   = %q{Failover scripts and utilities for Amplify databases}
  spec.summary       = %q{Failover scripts and utilities for Amplify databases}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  %w{sequel gli sinatra sinatra-contrib simple-graphite}.each { |gem| spec.add_dependency gem }
  spec.add_dependency 'amplify-slf4j', '~> 0.0.4'
  spec.add_dependency 'zk', '~> 1.9.5'

  # this thing needs to run under both jruby and MRI, if possible
  if RUBY_PLATFORM =~ /java/
    %w{jdbc-mysql}.each { |gem| spec.add_dependency gem } 
  else
    %w{mysql}.each { |gem| spec.add_dependency gem } 
  end

  # dev deps
  spec.add_development_dependency "bundler", "< 1.10"
  %w{rubocop rake warbler}.each { |gem| spec.add_development_dependency gem }
end
