#!/bin/sh
# download the docker-compose & orai.env file

curl -OL https://raw.githubusercontent.com/oraichain/oraichain-static-files-private/testnet-dev/docker-compose.yml

curl -OL https://raw.githubusercontent.com/oraichain/oraichain-static-files-private/testnet-dev/orai.dev.env

# modify the orai.env name & content
