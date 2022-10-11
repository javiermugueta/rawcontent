#!/bin/bash
# jmu 10/Oct/2022
# this command searchs in the logs of the current day
# performing a fulltext search case insesnsitive
#
# usage
#
usage() {
    echo 
    echo "Searchs in the logs of the current day, fulltext, case insensitive"
    echo
    echo "usage: ./log-query.sh <search-string> <compartment-name> <log-group-name> <log-name>"
    echo "<search-string> and <compartment-name> are mandatory"
    echo
    echo "examples:"
    echo "./log-query.sh core.error.internal xploraDEV"
    echo "./log-query.sh core.error.internal xploraDEV PSD2_Dev"
    echo "./log-query.sh core.error.internal xploraDEV PSD2_Dev func_oag_es_dev_invoke"
    echo
    exit 255
}
note(){
    echo "Please note that compartments, log-groups and log-names are case sensitive!!!"
}
#
if [[ -z $1 || -z $2 ]] 
then
    usage
fi
#params
query=$1
compname=$2
groupname=$3
logname=$4
#
tstart=$(date +"%Y-%m-%dT00:00:00.000000Z")
export start_time=$tstart
echo "Logs start time: "$tstart 
tend=$(date +"%Y-%m-%dT23:59:59.999999Z")
echo "Logs end time: "$tend 
export end_time=$tend
#
# locating ocid's by their names
compocid=$(oci iam compartment list --compartment-id-in-subtree true --all | jq --arg compname "$compname" '.data[] | select(."name"==$compname)' | jq -r ."id")
if [[ -z $compocid ]]; then
    echo "Compartment ocid: NOT FOUND !!!!"  
    note
    exit 255 
fi
echo "Compartment ocid: "$compocid
subquery="search \"$compocid"
#
if [[ ! -z $groupname ]]; then
    groupocid=$(oci logging log-group list -c $compocid --all | jq --arg groupname "$groupname" '.data[]| select(."display-name"==$groupname)' | jq -r ."id")
    if [[ -z $groupocid ]]; then
        echo "Log group ocid: NOT FOUND !!!!"
        note
        exit 255
    fi
    echo "Log group ocid: "$groupocid
    subquery="search \"$compocid/$groupocid"
fi
#
if [[ ! -z $logname ]]; then
    logocid=$(oci logging log list --log-group-id $groupocid --display-name $logname | jq -r '.data[].id')
    if [[ -z $logocid ]]; then
        echo "Log name ocid: NOT FOUND !!!!"
        note
        exit 255
    fi
    echo "Log name ocid: "$logocid
    subquery="search \"$compocid/$groupocid/$logocid"
fi
fullquery=$subquery\"" | where logContent='*$query*'"
echo "Search query: "$fullquery
# 
echo "Search results:"
oci logging-search search-logs --search-query "$fullquery" --time-start $start_time --time-end $end_time | jq '.data.results[].data.logContent.data.message'
echo "End, bye"
# EOF

