#!/bin/bash
# jmu 4/jun/2023
#
# Recycles the ppk for the user passed as argument
# If the user has more than one ppk, only one will remain
# the other will be deleted
ociuser=$1
organization=$2
project=$3
pipeline=$4
azpipelinevarname=$5
#
pubfile="oci_api_key_public.pem"
ppkfile="oci_api_key.pem"
red=`tput setaf 1`
green=`tput setaf 2`
reset=`tput sgr0`
#
usage(){
    echo "Usage:"
    echo "      ./oci-recycle-ppk.sh user_ocid organization project pipeline variablename"
    echo "Example:"
    echo "      ./apigwdeployment.sh ocid1.user.oc1..aaaaaaaag62zndss.... https://dev.azure.com/xxxxxx az2oc mypipe pipelinevar"
}
#
if [[ "$#" -ne 5 ]]; then
    echo ${red}"**********+*******************"
    echo ${red}" Wrong number of arguments !! "
    echo ${red}"**********+*******************"
    usage
    echo 
    exit 255
fi 
#
docker pull ghcr.io/oracle/oci-cli:latest
docker tag ghcr.io/oracle/oci-cli:latest oci
alias oci='docker run  -v ".oci:/oracle/.oci" oci'
#alias oci='docker run --rm -it -v "$HOME/.oci:/oracle/.oci" oci'
#oci os ns get
docker run -v "oci:/oracle/.oci" oci os ns get
# create a new key pair
openssl genrsa -out $ppkfile 2048       
chmod go-rwx $ppkfile       
openssl rsa -pubout -in $ppkfile -out $pubfile  
#
# upload a the new key                 
newfp="$(docker run -v "oci:/oracle/.oci" oci iam user api-key upload --user-id $ociuser --key-file $pubfile | jq -r '.data.fingerprint')"
#
# if the key is uploaded succesfully we delete the oldest one
if  [[ $newfp == "" ]]; then
    echo ${red}"*****************************************************"
    echo ${red}"*        ERROR ASSOCIATING NEW PRIVATE KEY          *"
    echo ${red}"*        MAYBE USER HAS GOT 3 PPK's ALREADY?        *"
    echo ${red}"*****************************************************"
    rm -f oci.err
    exit 255
else
    # looping existing fingerprints, deleting the ones that are not the new
    fps=$(docker run  -v "oci:/oracle/.oci" oci iam user api-key list --user-id $ociuser | jq '.data[]' | jq -r ."fingerprint")
    for fp in $fps 
    do
        if [[ $fp != $newfp ]]; then
            echo "Fingerprint to delete: " $fp
            # deleting old, swap comment to skip confirmation
            # force
            docker run  -v "oci:/oracle/.oci" oci iam user api-key delete --force --user-id $ociuser --fingerprint $finger
            # interactive
            #oci iam user api-key delete --user-id $ociuser --fingerprint $fp
        fi
    done
    echo ${green}"Successfully recycled ppk for user $ociuser with new fingerprint $newfp"
    #cat $ppkfile
    #cat $pubfile
    # now lets change the variable in az
    echo -n "az pipelines variable update --name $azpipelinevarname --value '" > cmd_file
    awk 'NF {sub(/\r/, ""); printf "%s|",$0;}' $ppkfile  >> cmd_file
    echo -n "' --organization $organization  --project $project --pipeline-name $pipeline --output table"  >> cmd_file
    #cat cmd_file
    sh cmd_file
    if [[ $? == 0 ]]; then
        echo ${green}"Successfully updated variable named ${red}$azpipelinevarname${green} of pipeline ${red}$pipeline${green} in the az devops organization named ${red}$organization${reset}."
    else
        echo ${red}"**************************************************************"
        echo ${red}"*        ERROR UPDATING AZ DEVOPS PIPELINE VARIABLE          *"
        echo ${red}"**************************************************************"
    fi
fi
# verification for testing outside AZ devops
echo "Verification"
awk 'NF {sub(/\r/, ""); printf "%s|",$0;}' $ppkfile  > test_file
cat test_file | tr '|' '\n'    
# 
rm $ppkfile
rm $pubfile
rm cmd_file
rm test_file
echo "Goodbye!"