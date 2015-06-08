#!/usr/bin/env bash

if [ -s "$HOME/.rvm/scripts/rvm" ]; then
  source "$HOME/.rvm/scripts/rvm"
  rvm rvmrc trust . > /dev/null
  source .rvmrc > /dev/null
fi

gem install bundler --version '< 1.10'
bundle check || bundle install

bundle exec rake $@
