#!/usr/bin/env bash

if [ -s "$HOME/.rvm/scripts/rvm" ]; then
  source "$HOME/.rvm/scripts/rvm"
  rvm rvmrc trust . > /dev/null
  source .rvmrc > /dev/null
fi

bundle check || bundle install

bundle exec rake $@
