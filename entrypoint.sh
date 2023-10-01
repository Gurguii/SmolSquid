#!/bin/sh

# Gurgui custom entrypoint script to
# automatise squid in alpine docker container

# Re/create swap directories
printf "== Creating swap directories\n" && squid -z &> /dev/null  

sleep 3

# Start squid
printf "== Starting squid\n"
squid &>/dev/null

sleep 3 

printf "== Doing extra stuff\n"
tail -f /etc/passwd
# Display access log file
#tail -f "/var/log/squid/access.log"
