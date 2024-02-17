#!/bin/bash

git pull

# get commit hash
export COMMIT_HASH=$(git rev-parse HEAD)

# get hostname
export HIDDEN_SERVICE_HOSTNAME=$(cat /var/lib/tor/hidden_service/hostname)

# build site
hugo --baseURL="http://$HIDDEN_SERVICE_HOSTNAME"

# build webserver
go build

# restart webserver
systemctl restart joeyinnes

# show status
systemctl status joeyinnes