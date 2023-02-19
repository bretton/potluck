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

# create syslog file and necessary directories
touch /var/log/slapd.log
mkdir -p /usr/local/etc/syslog.d/

# create password
SETSLAPPASS=$(/usr/local/sbin/slappasswd -s "$MYCREDS")

# shellcheck disable=SC3003,SC2039
# safe(r) separator for sed
sep=$'\001'

if [ -n "$REMOTEIP" ]; then
    < "$TEMPLATEPATH/multi-slapd.conf.in" \
    sed "s${sep}%%serverid%%${sep}$SERVERID${sep}g" | \
    sed "s${sep}%%mysuffix%%${sep}$MYSUFFIX${sep}g" | \
    sed "s${sep}%%mytld%%${sep}$MYTLD${sep}g" | \
    sed "s${sep}%%setslappass%%${sep}$SETSLAPPASS${sep}g" | \
    sed "s${sep}%%remoteip%%${sep}$REMOTEIP${sep}g" \
    > /usr/local/etc/openldap/slapd.conf
else
    < "$TEMPLATEPATH/slapd.conf.in" \
    sed "s${sep}%%mysuffix%%${sep}$MYSUFFIX${sep}g" | \
    sed "s${sep}%%setslappass%%${sep}$SETSLAPPASS${sep}g" | \
    sed "s${sep}%%mytld%%${sep}$MYTLD${sep}g" \
    > /usr/local/etc/openldap/slapd.conf
fi

# set ldap owner on config file
chown ldap:ldap /usr/local/etc/openldap/slapd.conf

# remove world-read access
chmod o-rwx /usr/local/etc/openldap/slapd.conf

< "$TEMPLATEPATH/slapd.ldif.in" \
 sed "s${sep}%%setslappass%%${sep}$SETSLAPPASS${sep}g" | \
 sed "s${sep}%%mysuffix%%${sep}$MYSUFFIX${sep}g" | \
 sed "s${sep}%%mytld%%${sep}$MYTLD${sep}g" \
> /usr/local/etc/openldap/slapd.ldif

# set ldap owner
chown ldap:ldap /usr/local/etc/openldap/slapd.ldif

# remove world-read
chmod o-rwx /usr/local/etc/openldap/slapd.ldif

< "$TEMPLATEPATH/ldap.conf.in" \
 sed "s${sep}%%ip%%${sep}$IP${sep}g" | \
 sed "s${sep}%%mysuffix%%${sep}$MYSUFFIX${sep}g" | \
 sed "s${sep}%%mytld%%${sep}$MYTLD${sep}g" \
> /usr/local/etc/openldap/ldap.conf

# set perms
chown ldap:ldap /usr/local/etc/openldap/ldap.conf
chmod 644 /usr/local/etc/openldap/ldap.conf

# remove any old config
rm -r /usr/local/etc/openldap/slapd.d/* || true

# set permissions so that ldap user owns /usr/local/etc/openldap/slapd.d/
# this is critical to making the below work
chown -R ldap:ldap /usr/local/etc/openldap/slapd.d/

# build a basic config from the included slapd.CONF file (capitalised for emphasis)
# -f read from config file, -F write to config dir
# slapcat -b cn=config -f /usr/local/etc/openldap/slapd.conf -F /usr/local/etc/openldap/slapd.d/
/usr/local/sbin/slapcat -n 0 -f /usr/local/etc/openldap/slapd.conf -F /usr/local/etc/openldap/slapd.d/ || true

# import configuration ldif file, uses -c to continue on error, database 0
/usr/local/sbin/slapadd -c -n 0 -F /usr/local/etc/openldap/slapd.d/ -l /usr/local/etc/openldap/slapd.ldif || true

# create import scripts
cp -f "$TEMPLATEPATH/importldapconfig.sh.in" /root/importldapconfig.sh
chmod +x /root/importldapconfig.sh
cp -f "$TEMPLATEPATH/importldapdata.sh.in" /root/importldapdata.sh
chmod +x /root/importldapdata.sh

# enable service
service slapd enable || true
# sysrc doesn't seem to add this correctly so echo in
echo "slapd_flags='-4 -h \"ldapi://%2fvar%2frun%2fopenldap%2fldapi/ ldap://$IP/ ldaps://$IP/\"'" >> /etc/rc.conf
# set cn=config directory config settings
sysrc slapd_cn_config="YES"
sysrc slapd_sockets="/var/run/openldap/ldapi"
# makes root stuff work, currently unset
# sysrc slapd_owner="DEFAULT"
