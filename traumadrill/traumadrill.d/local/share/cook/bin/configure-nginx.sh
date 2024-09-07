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

# make traumadrill web directory and set permissions
mkdir -p /usr/local/www/traumadrill

# copy in index.php with buttons to run scripts
cp -f "$TEMPLATEPATH/index.php.in" /usr/local/www/traumadrill/index.php

# set ownership on web directory, www needs write perms for stress-ng
chown www:www /usr/local/www/traumadrill
chmod 775 /usr/local/www/traumadrill

# copy in bash scripts to run stress-ng
cp -f "$TEMPLATEPATH/my-stress-ng.sh.in" /usr/local/bin/my-stress-ng.sh
chmod +x /usr/local/bin/my-stress-ng.sh

# shellcheck disable=SC3003,SC2039
# safe(r) separator for sed
sep=$'\001'

# copy in custom nginx and set IP to ip address of pot image
< "$TEMPLATEPATH/nginx.conf.in" \
  sed "s${sep}%%ip%%${sep}$IP${sep}g" \
  > /usr/local/etc/nginx/nginx.conf

# copy over custom php.ini with long execution time
cp -f "$TEMPLATEPATH/php.ini.in" /usr/local/etc/php.ini

# enable nginx
service nginx enable

# configure php-fpm service manually by fixing
# missing /usr/local/etc/rc.d/php-fpm file
if [ ! -f /usr/local/etc/rc.d/php-fpm ]; then
	cp -f "$TEMPLATEPATH/php-fpm.rc.in" /usr/local/etc/rc.d/php-fpm
	chown root:wheel /usr/local/etc/rc.d/php-fpm
	chmod +x /usr/local/etc/rc.d/php-fpm
fi

# enable php-fpm
service php-fpm enable

