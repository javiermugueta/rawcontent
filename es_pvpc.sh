#!/bin/bash
# jmu 25/09/2022
# gets pvpc from ree data
# only works for winter time
os=$(uname -a)
if echo "$os" | grep -q "Linux"; then
    # linuxlike
    ahora=$(date --date="+%Y-%m-%dT%H")":00:00.000+01:00"
    start=$(date --date="+%Y-%m-%dT")"00:00"
    stop=$(date --date="+%Y-%m-%dT")"23:59"
elif echo "$os" | grep -q "Darwin"; then
    # mac
    ahora=$(date "+%Y-%m-%dT%H")":00:00.000+01:00"
    start=$(date "+%Y-%m-%dT")"00:00"
    stop=$(date "+%Y-%m-%dT")"23:59"
else
    #
    echo "I haven't been instructed by the programmer how to deal with date in this platform"
    echo ":-("
    echo ":-)"
    exit -1
fi
echo "Current time:" $ahora
#
cmd="curl --location --request GET https://apidatos.ree.es/es/datos/mercados/precios-mercados-tiempo-real?start_date=$start&end_date=$stop&time_trunc=hour&geo_limit=peninsular"
echo $cmd
result=$($cmd)
echo $result | jq
result1=$(echo $result | jq --arg ahora "$ahora"  '.included[0].attributes.values[] | select(."datetime"==$ahora).value')
echo $result1