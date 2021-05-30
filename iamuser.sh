#!/bin/bash
# jmu may 2021
#
# creates IAM user associated to  <group> and API signing keys
#
# usage
#
usage() {
    echo 
    echo "usage: ./iamuser.sh <username> <groupname>"
    echo
    exit 255
}
#
if [[ -z $1 || -z $2 ]] 
then
    usage
fi
#
username=$1
groupname=$2
#
# main section
#
echo
userid=$(oci iam user create --name $username --description $username | jq -r '.data.id')
echo $userid
echo
#
openssl genrsa -out myuser.pem  2048 
openssl rsa -pubout -in myuser.pem -out myuser_public.pem
#
cmd="oci iam group list | jq -r '.data[] | select(.name | test(\""$groupname"\")) | .id'"
echo $cmd >tempfile
groupid=$(source tempfile)
echo $groupid
oci iam group add-user --group-id $groupid --user-id $userid
#
echo
echo User created, goodbye!
echo 