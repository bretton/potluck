---
author: "Stephan Lichtenauer, Bretton Vine"
title: Postgres-Single
summary: This is a single-server PostgreSQL jail with access from the local network.
tags: ["postgresql", "sql", "database", "mastodon"]
---

# Overview

This is a PostgreSQL jail intended to be run as a single PostgreSQL instance and can be started with ```pot```.

The jail exposes parameters that can be set via the environment.

It also contains `node_exporter` and a local `consul` agent instance to be
available that it can connect to (see configuration below). You can e.g.
use the [consul](https://potluck.honeyguide.net/blog/consul/) `pot` flavour
on this site to run `consul`.

# Setup

This PostgreSQL jail is designed to be accessed by trusted clients inside trusted environments.

This jail must be run with a non-routable IP address, accessible only to the internal network.

## Installation

* Create a ZFS data set on the parent system beforehand
  ```
  zfs create -o mountpoint=/mnt/postgres zroot/postgres
  ```
* Create your local jail from the image or the flavour files.
* Clone the local jail
* Mount in the ZFS data set you created
  ```
  pot mount-in -p <jailname> -m /mnt -d /mnt/postgres
  ```
* Copy in your custom `customscript.sh` with additional commands, for example creating database users
  ```
  pot copy-in -p <jailname> -s /path/to/your/customscript.sh -d /root/customscript.sh
  ```
* Adjust to your environment:
  ```
  sudo pot set-env -p <jailname> \
   -E DATACENTER=<datacenter name> \
   -E CONSULSERVERS="<comma-deliminated list of consul servers>" \
   -E GOSSIPKEY=<32 byte Base64 key from consul keygen> \
   -E NODENAME=<name of node> \
   -E IP=<IP address> \
   -E IP4NETWORK=<10.0.0.1/24> \
   -E EXPORTERPASS=<password for the postgres_exporter user> \
   [ -E DUMPSCHEDULE="<cronschedule>" ] \
   [ -E DUMPPATH=<path for database backups> ] \
   [ -E REMOTELOG=<IP of syslog-ng server> ]
  ```

The DATACENTER parameter is the name of the datacenter.

The CONSULSERVERS parameter is a comma-deliminated list of IP addresses for the consul server or cluster. Do not include spaces!

e.g. ```CONSULSERVERS="10.0.0.2"``` or ```CONSULSERVERS="10.0.0.2,10.0.0.3,10.0.0.4,10.0.0.5,10.0.0.6"```

The GOSSIPKEY parameter is the gossip encryption key for consul agent.

The NODENAME parameter is the name of the node.

The IP parameter is the IP address of this image.

The IP4NETWORK parameter is the local network/mask to allow access to the PostgreSQL server. Pot jails in this range can access PostgreSQL.

The EXPORTERPASS parameter is a password for the postgres_exporter user for stats collection.

DUMPSCHEDULE is an optional parameter for a cronjob to dump the databases to file. Provide it in the scheduling format of crontab, e.g. "*/5 * * * *". (include quotes)

DUMPPATH is an optional parameter for the path to store database backups. For example `/mnt/pgbak`.

REMOTELOG is an optional parameter for a remote syslog service, such as via the `loki` or `beast-of-argh` images on potluck site.

## Usage

### customscript.sh

The is a sample `customscript.sh` file `customscript.sh.sample`. You can modify this to add users or perform additional steps, then copy it in before starting the image.

This file is automatically run if found in the jail's `/root/customscript.sh`.

## upgrading postgresql

This jail stores postgresql-15 data in `/mnt/postgres/data`. Upgrades with a newer version of postgresql won't work with old versions.

Create a new postgresql jail with the newer version, and make a database dump from the old server, then import to new server with newer version of postgresql. 

This is the least problematic approach, as `pg_upgrade` requires both old and new versions of postgresql to be installed to work.

TBA: automatic upgrade from backups when the upgrade parameter is passed in with path to file.