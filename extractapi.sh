#!/bin/bash
#
# jmu 2/2/1968+54
#
# Purpose:
# Extracts a json file of an existing APIGW deployment 
#
# NOTICE:This tool is experimental
#        Keys are exported like camel-case instead of like camelCase
#
# parameters
deployname=$1 
compname=$2 
gatewayname=$3
outputfile=$4
#
# inerface for humans
echo .
echo "Input vars:"
echo "Deployment Name: "$deployname
echo "Compartment Name (case sensitive): "$compname
echo "Gateway Name: "$gatewayname
echo "Output file: "$outputfile
echo .
#
usage(){
    echo "Usage:"
    echo "      ./extractapi.sh deployment-name compartment-name gateway-name output-file"
    echo "Example:"
    echo "      ./extractapi.sh pet xploraDEV api-oag-es-dev.oci.wizink.net extract.json"
}
#
if [[ "$#" -ne 4 ]]; then
    echo .
    echo "Wrong number of arguments passed!"
    echo .
    usage
    echo 
    exit
fi
#
# hands on
#
compocid=$(oci iam compartment list --compartment-id-in-subtree true --all | jq --arg compname "$compname" '.data[] | select(."name"==$compname)' | jq -r ."id")
#
gwocid=$(oci api-gateway gateway list -c $compocid --lifecycle-state ACTIVE --all --query "data.items[?\"display-name\" == '$gatewayname'].\"id\""  | jq -r .[0])
#
deployid=$(oci api-gateway deployment list -c $compocid --lifecycle-state ACTIVE --gateway-id $gwocid --all --query "data.items[?\"display-name\" == '$deployname'].\"id\"" | jq -r .[0])
#
# extracts document and converts keys to camelCase
##oci api-gateway deployment get --deployment-id $deployid | perl -pe 's/-(.)/\u$1/g' > $outputfile
oci api-gateway deployment get --deployment-id $deployid  > $outputfile
#
##unameOut="$(uname -s)"
#
# key_ops is the only key that APIGW expects to be in xxx_yyy format
# wahtever xxxx-yyyy in the doccument that is not a key must be "resolved" here
# detecting the OS because sed behaves different
##if [[ $unameOut == "Darwin" ]]; then
##    sed -i '' 's/keyOps/key_ops/g' $outputfile
##    sed -i '' 's/featuresMatrix/features-matrix/g' $outputfile
##else
##    sed -i -e 's/keyOps/key_ops/g' $outputfile
##    sed -i -e 's/featuresMatrix/features-matrix/g' $outputfile
##fi
#
mv $outputfile $outputfile.temp
#
# extracts "specification" key value inside "data" key of json extraction
cat $outputfile.temp | jq .data.specification > $outputfile
rm $outputfile.temp
#
echo
echo "Extraction finished!!!"
echo

