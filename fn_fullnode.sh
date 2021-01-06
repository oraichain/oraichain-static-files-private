#!/bin/bash

#
# Copyright Oraichain All Rights Reserved
#
# SPDX-License-Identifier: Apache-2.0
#
# export so other script can access

# colors
BROWN='\033[0;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'
BOLD=$(tput bold)
NORMAL=$(tput sgr0)

# environment
BASE_DIR=$PWD
SCRIPT_NAME=`basename "$0"`

# verify the result of the end-to-end test
verifyResult() {  
  if [ $1 -ne 0 ] ; then    
    printBoldColor $RED  "========= $2 ==========="
    echo
      exit 1
  fi
}

printCommand(){
  echo -e ""
  printBoldColor $BROWN "Command:"
  printBoldColor $BLUE "\t$1"  
}

printBoldColor(){
  echo -e "$1${BOLD}$2${NC}${NORMAL}"
}

# Print the usage message
printHelp () {

  echo $BOLD "Usage: "  
  echo "  $SCRIPT_NAME -h|--help (Show help)"  
  echo $NORMAL

  if [[ ! -z $2 ]]; then
    res=$(printHelp 0 | grep -A2 "\- '$2' \-")
    echo "$res"    
  else      
    printBoldColor $BROWN "      - 'start' - Run the full node"
    printBoldColor $BLUE  "          fn start"           
    echo
    printBoldColor $BROWN "      - 'broadcast' - broadcast transaction"
    printBoldColor $BLUE  "          fn broadcast --key value"           
    echo
    printBoldColor $BROWN "      - 'init' - Init the orai node"
    printBoldColor $BLUE  "          fn init"           
    echo
    printBoldColor $BROWN "      - 'sign' - sign transaction"
    printBoldColor $BLUE  "          fn sign --key value"           
    echo
    printBoldColor $BROWN "      - 'initScript' - init AI request script"
    printBoldColor $BLUE  "          fn initScript --key value"           
    echo
    printBoldColor $BROWN "      - 'clear' - Clear all existing data"
    printBoldColor $BLUE  "          fn clear"           
    echo
  fi

  echo
  echo "  $SCRIPT_NAME method --argument=value"
  
  # default exit as 0
  exit ${1:-0}
}


# Get a value:
getArgument() {     
  local key="args_${1/-/_}"  
  echo ${!key:-$2}  
}


# check first param is method
if [[ $1 =~ ^[a-z] ]]; then 
  METHOD=$1
  shift
fi

# use [[ ]] we dont have to quote string
args=()
case "$METHOD" in
  bash)        
    while [[ ! -z $2 ]];do         
      if [[ ${1:0:2} == '--' ]]; then
        KEY=${1/--/}            
        if [[ $KEY =~ ^([a-zA-Z_-]+)=(.+) ]]; then                
          declare "args_${BASH_REMATCH[1]/-/_}=${BASH_REMATCH[2]}"
        else          
          declare "args_${KEY/-/_}=$2" 
          shift
        fi    
      else 
        args+=($1)
      fi
      shift
    done
    QUERY="$@"            
  ;;
  config)        
    while [[ $# -gt 0 ]] ; do            
      if [[ ${1:0:2} == '--' ]]; then
        KEY=${1/--/}            
        if [[ $KEY =~ ^([a-zA-Z_-]+)=(.+) ]]; then                
          declare "args_${BASH_REMATCH[1]/-/_}=${BASH_REMATCH[2]}"
        else          
          declare "args_${KEY/-/_}=$2" 
          shift
        fi    
      else 
        args+=($1)
      fi
      shift
    done     
  ;;
  *) 
    # normal processing
    while [[ $# -gt 0 ]] ; do                
      if [[ ${1:0:2} == '--' ]]; then
        KEY=${1/--/}                
        if [[ $KEY =~ ^([a-zA-Z_-]+)=(.+) ]]; then         
          declare "args_${BASH_REMATCH[1]/-/_}=${BASH_REMATCH[2]}"
        else
          declare "args_${KEY/-/_}=$2"        
          shift
        fi    
      else 
        case "$1" in
          -h|\?)            
            printHelp 0 $2
          ;;
          *)  
            args+=($1)            
          ;;  
        esac    
      fi 
      shift
    done 
  ;; 
esac


clear(){
    rm -rf .oraid/
    rm -rf .oraicli/
    rm -rf .oraifiles/    
}

oraidFn(){
    # oraid start
    orai start --chain-id $CHAIN_ID --laddr tcp://0.0.0.0:1317 --node tcp://0.0.0.0:26657 # --trust-node
}


initFn(){
  ### Check if a directory does not exist ###
  if [[ ! -d "$PWD/.oraid/" || ! -d "$PWD/.oraicli/" ]] 
  then  
    oraid init $MONIKER --chain-id Oraichain
    res=$?        
    verifyResult $res "can not run oraid init"  

    # Configure your CLI to eliminate need to declare them as flags
    oraicli config chain-id Oraichain
    oraicli config output json
    oraicli config indent true
    oraicli config trust-node true
    oraicli config keyring-backend test

    oraicli keys add $USER
    res=$?        
    verifyResult $res "can not add $USER"

    # download genesis json file
    
    curl $GENESIS_URL > .oraid/config/genesis.json

    res=$?        
    verifyResult $res "can not downlodad genesis file $GENESIS_URL"

    # rm -f .oraid/config/genesis.json && wget https://raw.githubusercontent.com/oraichain/oraichain-static-files/ducphamle2-test/genesis.json -q -P .oraid/config/

    # add persistent peers to listen to blocks
    local persistentPeers=$(getArgument "persistent_peers" "$PERSISTENT_PEERS")
        [ ! -z $persistentPeers ] && sed -i 's/persistent_peers *= *".*"/persistent_peers = "'"$persistentPeers"'"/g' .oraid/config/config.toml 

    res=$?        
    verifyResult $res "can not edit the persistent peer value $persistentPeers"

    oraid validate-genesis

    # run at background without websocket
    oraid start --minimum-gas-prices $GAS_PRICES
  fi
}

createValidatorFn() {
  local user=$(getArgument "user" $USER)
  # run at background without websocket
  # # 30 seconds timeout to check if the node is alive or not, the '&' symbol allows to run below commands while still having the process running
  # oraid start &
    # 30 seconds timeout
  timeout 30 bash -c 'while [[ "$(curl -s -o /dev/null -w ''%{http_code}'' localhost:26657/health)" != "200" ]]; do sleep 1; done' || false

  local amount=$(getArgument "amount" $AMOUNT)
  local pubkey=$(oraid tendermint show-validator)
  local moniker=$(getArgument "moniker" $MONIKER)
  if [[ $moniker == "" ]]; then
    moniker="$USER"_"Oraichain"_$(($RANDOM%100000000000))
  fi
  local floatRe='^[+-]?[0-9]+\.?[0-9]*$'
  local commissionRate=$(getArgument "commission_rate" $COMMISSION_RATE)
  if [[ $commissionRate > 1 || !$commissionRate =~ $floatRe || $commissionRate == "" ]]; then
    commissionRate=0.10
  fi
  local commissionMaxRate=$(getArgument "commission_max_rate" $COMMISSION_MAX_RATE)
  if [[ $commissionMaxRate > 1 || !$commissionMaxRate =~ $floatRe || commissionMaxRate == "" ]]; then
    commissionMaxRate=0.20
  fi
  local commissionMaxChangeRate=$(getArgument "commission_max_change_rate" $COMMISSION_MAX_CHANGE_RATE)
  if [[ $commissionMaxChangeRate > 1 || !$commissionMaxChangeRate =~ $floatRe || $commissionMaxChangeRate == "" ]]; then
    commissionMaxChangeRate=0.01
  fi
  local minDelegation=$(getArgument "min_self_delegation" $MIN_SELF_DELEGATION)

  # verify env from user, regex for checking number
  local re='^[0-9]+$'
  if [[ $minDelegation < 1 || !$minDelegation =~ $re || $minDelegation == "" ]]; then
    minDelegation=1
  fi

  local gas=$(getArgument "gas" $GAS)
  if [[ $gas != "auto" && !$gas =~ $re ]]; then
    gas=200000
  fi

  # workaround, since auto gas in this case is not good, sometimes get out of gas
  if [[ $gas == "auto" || $gas < 200000 ]]; then
    gas=200000
  fi

  local gasPrices=$(getArgument "gas_prices" $GAS_PRICES)
  if [[ $gasPrices == "" ]]; then
    gasPrices="0.000000000025orai"
  fi
  local securityContract=$(getArgument "security_contract" $SECURITY_CONTRACT)
  local identity=$(getArgument "identity" $IDENTITY)
  local website=$(getArgument "website" $WEBSITE)
  local details=$(getArgument "details" $DETAILS)

  echo "start creating validator..."
  sleep 10

  enterPassPhrase oraicli tx staking create-validator --amount $amount --pubkey $pubkey --moniker $moniker --chain-id Oraichain --commission-rate $commissionRate --commission-max-rate $commissionMaxRate --commission-max-change-rate $commissionMaxChangeRate --min-self-delegation $minDelegation --gas $gas --gas-prices $gasPrices --security-contact $securityContract --identity $identity --website $website --details $details --from $user

  local reporter="${user}_reporter"
  # # for i in $(eval echo {1..$2})
  # # do
  #   # add reporter key

  # ###################### init websocket for the validator

  echo "start initiating websocket..."
  HOME=$PWD/.oraid
  # rm -rf ~/.websocket
  WEBSOCKET="websocket --home $HOME"
  #$WEBSOCKET keys delete-all
  $WEBSOCKET keys add $reporter

  # config chain id
  $WEBSOCKET config chain-id Oraichain

  # add validator to websocket config
  echo "get user validator address..."
  local val_address=$(oraicli keys show $user -a --bech val)
  $WEBSOCKET config validator $val_address

  # setup broadcast-timeout to websocket config
  $WEBSOCKET config broadcast-timeout "30s"

  # setup rpc-poll-interval to websocket config
  $WEBSOCKET config rpc-poll-interval "1s"

  # setup max-try to websocket config
  $WEBSOCKET config max-try 5

  # config log type
  $WEBSOCKET config log-level debug

  $WEBSOCKET config gas-prices $gasPrices

  $WEBSOCKET config gas $gas

  echo "start sending tokens to the reporter"

  sleep 10

  local reporterAmount=$(getArgument "reporter_amount" $REPORTER_AMOUNT)

  echo "collecting user account address from local node..."
  local user_address=$(oraicli keys show $user -a)

  # send orai tokens to reporters

  echo "collecting the reporter's information..."

  enterPassPhrase oraicli tx send $user_address $($WEBSOCKET keys show $reporter) $reporterAmount --from $user_address --gas-prices $gasPrices

  echo "start broadcasting the reporter..."
  sleep 10

  #wait for sending orai tokens transaction success

  # add reporter to oraichain
  enterPassPhrase oraicli tx websocket add-reporters $($WEBSOCKET keys list -a) --from $user --gas-prices $gasPrices
  sleep 8

  # pkill oraid
}

websocketInitFn() {
  # run at background without websocket
  # # 30 seconds timeout to check if the node is alive or not
  timeout 30 bash -c 'while [[ "$(curl -s -o /dev/null -w ''%{http_code}'' localhost:26657/health)" != "200" ]]; do sleep 1; done' || false
  local reporter="${USER}_reporter"
  # for i in $(eval echo {1..$2})
  # do
    # add reporter key

  ###################### init websocket for the validator

  HOME=$PWD/.oraid
  # rm -rf ~/.websocket
  WEBSOCKET="websocket --home $HOME"
  #$WEBSOCKET keys delete-all
  $WEBSOCKET keys add $reporter  

  # config chain id
  $WEBSOCKET config chain-id Oraichain

  # add validator to websocket config
  $WEBSOCKET config validator $(oraicli keys show $USER -a --bech val --keyring-backend test)

  # setup broadcast-timeout to websocket config
  $WEBSOCKET config broadcast-timeout "30s"

  # setup rpc-poll-interval to websocket config
  $WEBSOCKET config rpc-poll-interval "1s"

  # setup max-try to websocket config
  $WEBSOCKET config max-try 5

  # config log type
  $WEBSOCKET config log-level debug

  sleep 10

  # send orai tokens to reporters
  echo "y" | oraicli tx send $(oraicli keys show $USER -a) $($WEBSOCKET keys show $reporter) 10000000orai --from $(oraicli keys show $USER -a) --fees 5000orai

  sleep 6

  #wait for sending orai tokens transaction success

  # add reporter to oraichain
  echo "y" | oraicli tx websocket add-reporters $($WEBSOCKET keys list -a) --from $USER --fees 5000orai --keyring-backend test
  sleep 8
  pkill oraid
}


initScriptFn(){
  echo "y" | oraicli tx provider set-datasource coingecko_eth ./testfiles/coingecko_eth.py "A data source that fetches the ETH price from Coingecko API" --from $USER --fees 5000orai

  sleep 5

  echo "y" | oraicli tx provider set-datasource crypto_compare_eth ./testfiles/crypto_compare_eth.py "A data source that collects ETH price from crypto compare" --from $USER --fees 5000orai

  sleep 5

  echo "y" | oraicli tx provider set-testcase testcase_price ./testfiles/testcase_price.py "A sample test case that uses the expected output of users provided to verify the bitcoin price from the datasource" --from $USER --fees 5000orai

  sleep 5

  echo "y" | oraicli tx provider set-oscript oscript_eth ./testfiles/oscript_eth.py "An oracle script that fetches and aggregates ETH price from different sources" --ds coingecko_eth,crypto_compare_eth --tc testcase_price --from $USER --fees 5000orai
}

unsignedFn(){
  local id=$(curl -s "http://localhost:1317/auth/accounts/$(oraicli keys show $USER -a)" | jq ".result.value.address" -r)
  local unsigned=$(curl --location --request POST 'http://localhost:1317/airequest/aireq' \
--header 'Content-Type: application/json' \
--data-raw '{
    "base_req":{
        "from":"'$id'",
        "chain_id":"'$CHAIN_ID'"
    },
    "oracle_script_name":"oscript_eth",
    "input":"",
    "expected_output":{"price":"5000"},
    "fees":"60000orai",
    "validator_count": "1"
}' > tmp/unsignedTx.json)

    res=$?  
    verifyResult $res "Unsigned failed"
}

unsignedSetDsFn(){
  local id=$(curl -s "http://localhost:1317/auth/accounts/$(oraicli keys show $USER -a)" | jq ".result.value.address" -r)
  local unsigned=$(curl --location --request POST 'http://localhost:1317/provider/datasource' \
--header 'Content-Type: application/json' \
--data-raw '{
    "base_req":{
        "from":"'$id'",
        "chain_id":"Oraichain"
    },
    "name":"coingecko_eth",
    "code_path":"/workspace/testfiles/coingecko_eth.py",
    "description":"NTAwMA==",
    "fees":"60000orai",
    "test":["abc","efgh"]
}' > tmp/unsignedTx.json)
}

clear(){
    rm -rf .oraid/
    rm -rf .oraicli/
    rm -rf .oraifiles/    
}

signFn(){     
    # $1 is account number
    local sequence=$(curl -s "http://localhost:1317/auth/accounts/$(oraicli keys show $USER -a)" | jq ".result.value.sequence" -r)
    local acc_num=$(curl -s "http://localhost:1317/auth/accounts/$(oraicli keys show $USER -a)" | jq ".result.value.account_number" -r)
    oraicli tx sign tmp/unsignedTx.json --from $USER --offline --chain-id $CHAIN_ID --sequence $sequence --account-number $acc_num > tmp/signedTx.json
    oraicli tx broadcast tmp/signedTx.json

    res=$?  
    verifyResult $res "Signed failed"
}


USER=$(getArgument "user" $USER)
CHAIN_ID=$(getArgument "chain-id" Oraichain)

# processing
case "${METHOD}" in     
  hello)
    helloFn
  ;;
  init)
    initFn
  ;;
  initDev)
    initDevFn
  ;;
  start)
    oraidFn
  ;;  
  unsign)
    unsignedFn
  ;;
  unsignedSetDs)
    unsignedSetDsFn
  ;;
  initScript)
    initScriptFn
  ;;
  createValidator)
    createValidatorFn
  ;;
  sign)
    signFn
  ;;
  broadcast)
    broadcastFn
  ;;  
  clear)
    clear
  ;; 
  *) 
    printHelp 1 ${args[0]}
  ;;
esac
