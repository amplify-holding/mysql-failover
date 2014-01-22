#!/bin/bash

[[ -s "$HOME/.rvm/scripts/rvm" ]] && . "$HOME/.rvm/scripts/rvm"
if hash rvm &>/dev/null; then
  rvm rvmrc trust .
fi

# force the .rvmrc file to be re-discovered
cd .

# setup version file
if [ -z "$BUILD_NUMBER" ]; then
  BUILD_NUMBER='dev'
fi
if [ -z "$GIT_BRANCH" ]; then
  GIT_BRANCH='nobranch'
fi
if [ -z "$GIT_COMMIT" ]; then
  GIT_COMMIT='nocommit'
fi
echo "$BUILD_NUMBER,$GIT_BRANCH,$GIT_COMMIT" > config/version.txt

# generate the jar
bundle check || bundle install
bundle package --all
bundle exec rake build

[[ -d dist ]] || mkdir dist
mv amplify-failover.war dist/amplify-failover-${BUILD_NUMBER}.war
