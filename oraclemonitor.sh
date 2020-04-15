#!/bin/bash

#####    Packages required: jq, bc

#####    CONFIG    ##################################################################################################
config=""              # config.toml file for node, eg. /home/user/.terrad/config/config.toml
terracli=""            # the terracli binary, eg. /home/user/go/bin/terracli
validatorpubkey=""     # terravaloper* pubkey, is used to find the feeder address
nmissedoraclevotes=100  # checks back the missed oracle votes n blocks from blockheight, a value higher than 100 is not supported by terrad
logname=""             # a custom log file name can be chosen, if left empty default is oraclemonitor-<username>.log
logpath="$(pwd)"       # the directory where the log file is stored, for customization insert path like: /my/path
logsize=200            # the max number of lines after that the log will be trimmed to reduce its size
sleep1=30              # polls every sleep1 sec
#####  END CONFIG  ##################################################################################################

if [ $nmissedoraclevotes -gt 100 ]; then
    echo "nmissedoraclevotes > 100 is not supported by terrad"
    exit 1
fi

if [ -z $config ]; then
    echo "please configure config.toml in script"
    exit 1
fi
url=$(sed '/^\[rpc\]/,/^\[/!d;//d' $config | grep "^laddr\b" | awk -v FS='("tcp://|")' '{print $2}')
chainid=$(jq -r '.result.node_info.network' <<<$(curl -s "$url"/status))
if [ -z $url ]; then
    echo "please configure config.toml in script correctly"
    exit 1
fi
url="http://${url}"

if [ -z $terracli ]; then
    echo "please configure terracli in script"
    exit 1
fi
terraclitest=$($terracli version)
if [ -z $terraclitest ]; then
    echo "please configure terracli correctly"
    exit 1
fi

if [ -z $logname ]; then logname="oraclemonitor-${USER}.log"; fi
logfile="${logpath}/${logname}"
touch $logfile

echo "log file: ${logfile}"
echo "terracli: ${terracli}"
echo "lcd url: ${url}"
echo "chain id: ${chainid}"

if [ -z $validatorpubkey ]; then
    echo "Please configure the validator address"
    exit 1
fi

feeder=$($terracli query oracle feeder $validatorpubkey --chain-id $chainid)
if [ -z $feeder ]; then
    echo "Please configure the validator pubkey correctly"
    exit 1
fi
feeder=$(sed -e 's/^"//' -e 's/"$//' <<<$feeder)
echo "feeder address: $feeder"

echo ""

date=$(date --rfc-3339=seconds)

nloglines=$(wc -l <$logfile)
if [ $nloglines -gt $logsize ]; then sed -i "1,$(expr $nloglines - $logsize)d" $logfile; fi # the log file is trimmed for logsize
echo "$date status=scriptstarted chainid=$chainid feederaddress=$feeder" >>$logfile

while true; do
    status=$(curl -s "$url"/status)
    result=$(grep -c "result" <<<$status)

    if [ "$result" != 0 ]; then
        npeers=$(curl -s "$url"/net_info | jq -r '.result.n_peers')
        if [ -z $npeers ]; then npeers="na"; fi
        blockheight=$(jq -r '.result.sync_info.latest_block_height' <<<$status)
        blocktime=$(jq -r '.result.sync_info.latest_block_time' <<<$status)
        catchingup=$(jq -r '.result.sync_info.catching_up' <<<$status)
        if [ $catchingup == "false" ]; then catchingup="synced"; elif [ $catchingup == "true" ]; then catchingup="catchingup"; fi

        nmissedstart=$($terracli query oracle miss $validatorpubkey --chain-id $chainid --height=$(expr $blockheight - $nmissedoraclevotes))
        nmissedstart=$(sed -e 's/^"//' -e 's/"$//' <<<$nmissedstart)
        nmissedend=$($terracli query oracle miss $validatorpubkey --chain-id $chainid)
        nmissedend=$(sed -e 's/^"//' -e 's/"$//' <<<$nmissedend)
        if [ $nmissedoraclevotes -eq 0 ]; then pctvotes="1.0"; else pctvotes=$(echo "scale=2 ; 1 - (($nmissedend - $nmissedstart) / $nmissedoraclevotes * 5)" | bc); fi

        amountukrw=$($terracli query account $feeder --chain-id $chainid | grep -A 1 "denom: ukrw" | tail -1 | awk -F'"' '{print $2}')

        now=$(date --rfc-3339=seconds)

        logentry="$now status=$catchingup blockheight=$blockheight nmissedvotes=$nmissedend pctvotes=$pctvotes amtukrw=$amountukrw"
        echo "$logentry" >>$logfile
    else
        now=$(date --rfc-3339=seconds)
        logentry="$now status=error"
        echo "$logentry" >>$logfile
    fi

    nloglines=$(wc -l <$logfile)
    if [ $nloglines -gt $logsize ]; then sed -i '1d' $logfile; fi

    echo "$logentry"
    echo "sleep $sleep1"
    sleep $sleep1
done
