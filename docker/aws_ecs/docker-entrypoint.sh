#!/bin/bash

# ----- Ensure correct ownership of /diaspora -----
dia_home=/diaspora

HOST_UID=$(stat -c %u /diaspora)
HOST_GID=$(stat -c %g /diaspora)

if ! getent group $HOST_GID >/dev/null; then
  groupmod --gid $HOST_GID diaspora
fi

if ! getent passwd $HOST_UID >/dev/null; then
  usermod --uid $HOST_UID --gid $HOST_GID diaspora
fi

mkdir -p /diaspora/tmp/pids
chown $HOST_UID:$HOST_GID /diaspora/tmp /diaspora/tmp/pids /diaspora/vendor/bundle

cd /diaspora

sh /diaspora/docker/script/db-add-env.sh

bin/bundle install --with=$RAILS_ENV

bundle exec rake db:create db:migrate

rake assets:precompile

chown diaspora.diaspora -R /diaspora

gosu $HOST_UID:$HOST_GID "$@"
