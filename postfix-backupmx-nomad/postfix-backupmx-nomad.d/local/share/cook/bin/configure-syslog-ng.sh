#!/bin/sh

# shellcheck disable=SC1091
if [ -e /root/.env.cook ]
    . /root/.env.cook
fi

set -e
# shellcheck disable=SC3040
set -o pipefail

export PATH=/usr/local/bin:$PATH

SCRIPT=$(readlink -f "$0")
TEMPLATEPATH=$(dirname "$SCRIPT")/../templates

# shellcheck disable=SC3003,SC2039
# safe(r) separator for sed
sep=$'\001'

# get syslog-ng version
config_version=$(/usr/local/sbin/syslog-ng --version | \
  grep "^Config version:" | awk -F: '{ print $2 }' | xargs)

# copy in syslog-ng.conf
< "$TEMPLATEPATH/syslog-ng.conf.in" \
  sed "s${sep}%%config_version%%${sep}$config_version${sep}g" | \
  sed "s${sep}%%remotelogip%%${sep}$REMOTELOG${sep}g" \
  > /usr/local/etc/syslog-ng.conf

# stop and disable syslogd
service syslogd onestop || true
service syslogd onedisable || true

# enable and start syslog-ng
service syslog-ng enable
sysrc syslog_ng_flags="-R /tmp/syslog-ng.persist"
service syslog-ng start
