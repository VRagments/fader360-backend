#!/usr/bin/env sh
set -e

# run migrations
/root/darth_release/bin/darth eval "Darth.Release.migrate"

# start application
exec /root/darth_release/bin/darth start
