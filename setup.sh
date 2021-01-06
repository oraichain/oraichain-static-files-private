#!/bin/sh
# download the docker-compose & orai.env file

curl -OL https://raw.githubusercontent.com/oraichain/oraichain-static-files-private/testnet-dev/docker-compose.fullnode.yml

curl -OL https://raw.githubusercontent.com/oraichain/oraichain-static-files-private/testnet-dev/orai.dev.env

curl -OL https://raw.githubusercontent.com/oraichain/oraichain-static-files-private/testnet-dev/fn_fullnode.sh

# modify the orai.env name & content
