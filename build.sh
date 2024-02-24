#!/bin/bash
git pull
cp service.conf /etc/systemd/system/joeyinnes.service
export COMMIT_HASH=$(git rev-parse HEAD)
export HIDDEN_SERVICE_HOSTNAME=$(cat /var/lib/tor/hidden_service/hostname)
hugo --baseURL="http://$HIDDEN_SERVICE_HOSTNAME"
systemctl restart joeyinnes
systemctl status joeyinnes