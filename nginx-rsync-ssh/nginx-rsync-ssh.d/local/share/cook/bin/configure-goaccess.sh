#!/bin/sh

# shellcheck disable=SC1091
if [ -e /root/.env.cook ]; then
    . /root/.env.cook
fi

set -e
# shellcheck disable=SC3040
set -o pipefail

export PATH=/usr/local/bin:$PATH

SCRIPT=$(readlink -f "$0")
TEMPLATEPATH=$(dirname "$SCRIPT")/../templates

# cleanup goaccess
mv /usr/local/etc/goaccess.conf /usr/local/etc/goaccess.conf.ignore

# copy over goaccess.conf
cp -f "$TEMPLATEPATH/goaccess.conf.in" /usr/local/etc/goaccess/goaccess.conf

# configure goaccess sysrc entires
sysrc goaccess_config="/usr/local/etc/goaccess/goaccess.conf"
sysrc goaccess_log="/var/log/nginx/access.log"

# enable and start
service goaccess enable
service goaccess start || true
