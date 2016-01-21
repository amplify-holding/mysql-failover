require 'rubygems'
require 'bundler'
Bundler.require

require 'logger'

require_relative 'lib/application'
run Sinatra::Application
