#!/bin/bash
# jmu 10/Oct/2022, new
# jmu 18/10/2022, adding new flag M|m
# this command searchs in the logs of the current hour
# performing a fulltext search case insesnsitive
# see https://javiermugueta.blog/2022/10/11/googling-oci-logs-helper-utility-for-fulltext-search-in-the-logs-either-from-the-terminal-or-cloud-shell/
#
# usage
#
usage() {
    echo 
    echo "Searches in the logs of the current hour or day, fulltext, case insensitive"
    echo
    echo "usage: ./log-query.sh <forrmat> <time-tscope> <search-string> <compartment-name> <log-group-name> <log-name>"
    echo "${red}<format>, <time-tscope>, <search-string> and <compartment-name> are mandatory"
    echo "${green}<format> can be J|j (json record) or T|t (just the message field)"
    echo "<time-tscope> can be H|h (current hour), D|d (current day), M|m (maximum 14 days back)"
    echo "search-string special value: @@@ -> retrives all records${reset}"
    echo
    echo "examples:"
    echo "./log-query.sh t d core.error.internal xplrDV"
    echo "./log-query.sh t d core.error.internal xplrDV PSD2_Dv"
    echo "./log-query.sh t d core.error.internal xplrDEV PSD2_Dv fnc_g_s_dv_nvk"
    echo "./log-query.sh j h @@@ xplrDV PSD_Dv fnc_g_s_dv_nvk"
    echo "./log-query.sh j m @@@ xplrDV PSD_Dv fnc_g_s_dv_nvk"
    echo
    echo "${red}Please note that some kind of log records doesn't have a message field, use json forrmat instead"
    echo "Please note that number of records retrieved can be limited by the service"
    echo
    exit 255
}
note(){
    echo ${red}"Please note that compartments, log-groups and log-names are case sensitive!!!"
}
#
red=`tput setaf 1`
green=`tput setaf 2`
reset=`tput sgr0`
#
if [[ -z $1 || -z $2 || -z $3 ]] 
then
    usage
fi
#params
format=$1
tscope=$2
query=$3
compname=$4
groupname=$5
logname=$6
#
if [[ $tscope == "H" || $tscope == "h" ]]; then
    tstart=$(date +"%Y-%m-%dT%H:00:00.000000Z")
    export start_time=$tstart
    echo "Logs start time: "${green}$tstart${reset}
    tend=$(date +"%Y-%m-%dT%H:59:59.999999Z")
    echo "Logs end time: "${green}$tend${reset}
    export end_time=$tend
elif [[ $tscope == "D" || $tscope == "d" ]]; then
    tstart=$(date +"%Y-%m-%dT00:00:00.000000Z")
    export start_time=$tstart
    echo "Logs start time: "${green}$tstart${reset}
    tend=$(date +"%Y-%m-%dT23:59:59.999999Z")
    echo "Logs end time: "${green}$tend${reset}
    export end_time=$tend
elif [[ $tscope == "M" || $tscope == "m" ]]; then
    os=$(uname -a)
    if echo "$os" | grep -q "Linux"; then
        # linuxlike
        tstart=$(date --date='-14 day' +"%Y-%m-%dT%H:%M:%S.000000Z")
    elif echo "$os" | grep -q "Darwin"; then
        # mac
        tstart=$(date -v-14d +"%Y-%m-%dT%H:%M:%S.000000Z")
    fi
    export start_time=$tstart
    echo "Logs start time: "${green}$tstart${reset}
    tend=$(date +"%Y-%m-%dT%H:%M:%S.000000Z")
    echo "Logs end time: "${green}$tend${reset}
    export end_time=$tend
else
    usage
fi
#
# locating ocid's by their names
compocid=$(oci iam compartment list --compartment-id-in-subtree true --all | jq --arg compname "$compname" '.data[] | select(."name"==$compname)' | jq -r ."id")
if [[ -z $compocid ]]; then
    echo ${red}"Compartment ocid: NOT FOUND !!!!"  
    note
    exit 255 
fi
echo "Compartment ocid: "${green}$compocid${reset}
subquery="search \"$compocid"
#
if [[ ! -z $groupname ]]; then
    groupocid=$(oci logging log-group list -c $compocid --all | jq --arg groupname "$groupname" '.data[]| select(."display-name"==$groupname)' | jq -r ."id")
    if [[ -z $groupocid ]]; then
        echo ${red}"Log group ocid: NOT FOUND !!!!"
        note
        exit 255
    fi
    echo "Log group ocid: "${green}$groupocid${reset}
    subquery="search \"$compocid/$groupocid"
fi
#
if [[ ! -z $logname ]]; then
    logocid=$(oci logging log list --log-group-id $groupocid --display-name $logname | jq -r '.data[].id')
    if [[ -z $logocid ]]; then
        echo ${red}"Log name ocid: NOT FOUND !!!!"
        note
        exit 255
    fi
    echo "Log name ocid: "${green}$logocid${reset}
    subquery="search \"$compocid/$groupocid/$logocid"
fi
# 
if [[ $query == "@@@" ]]; then
    fullquery=$subquery\"
else
fullquery=$subquery\"" | where logContent='*$query*'"
fi
#
echo "Search query: "${green}$fullquery${reset}
# 
echo "Search results:"
if [[ $format == "T" || $format == "t" ]]; then
    oci logging-search search-logs --search-query "$fullquery" --time-start $start_time --time-end $end_time  | jq '.data.results[].data.logContent.data.message'
elif [[ $format == "J" || $format == "j" ]]; then
    oci logging-search search-logs --search-query "$fullquery" --time-start $start_time --time-end $end_time  | jq '.data.results[].data.logContent.data'
else
    usage
fi
#
echo "End, bye!!"
# EOF

