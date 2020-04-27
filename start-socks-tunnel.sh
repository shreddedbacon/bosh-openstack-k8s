#!/bin/bash

SOCKS_PORT=$(bosh int openstack-setup/config.yml --path /socks/port)
PORT=${SOCKS_PORT:-9998}
JUMPBOX=$(./deploy jumpbox-ip)

echo "Starting SOCKS5 on port $PORT..."
bosh int jumpbox-root/creds.yml --path /jumpbox_ssh/private_key > keypair/jumpbox && chmod 600 keypair/jumpbox

## load key into agent
if ps -p $SSH_AGENT_PID > /dev/null
then
  ssh-add keypair/jumpbox
fi

ssh -i keypair/jumpbox -o "UserKnownHostsFile=/dev/null" -o "StrictHostKeyChecking=no" -A jumpbox@${JUMPBOX} -N -D ${PORT}
while true
do
  ssh -i keypair/jumpbox -o "UserKnownHostsFile=/dev/null" -o "StrictHostKeyChecking=no" -A jumpbox@${JUMPBOX} -N -D ${PORT}
  sleep 15
done
