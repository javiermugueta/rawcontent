#!/bin/bash
# jmu may 2021
#
# recursive list of compute instances in tenancy
# CREATING_IMAGE, MOVING, PROVISIONING, RUNNING, STARTING, STOPPED, STOPPING, TERMINATED, TERMINATING
#
# recursive call
#
recorre(){
    complist=$(oci iam compartment list --lifecycle-state ACTIVE -c $1 | jq -r '.data[]."id"')
    for i in $complist
    do
        c=$((c+1))
        indent $c
        compname=$(oci iam compartment get --compartment-id $i | jq -r '.data."name"')
        echo $compname
        instlist=$(oci compute instance list --compartment-id $i --lifecycle-state $2 | jq -r '.data[]."display-name"')
        for j in 1 $instlist
        do
            if [ $j != "1" ]; then
                echo "      $j"
            fi
        done
        recorre $i $2
        c=$((c-1))
    done
}
#
# indent
#
indent() {
  L=$1
  shift
  printf "["
  while [ $L -gt 0 ]
  do
    printf "+"
    L=$((L-1))
  done
  printf "] "
}
#
# main section
#
if [[ -z $1  ]] 
then
    echo 
    echo "Please provide an argument with values such as:"
    echo " CREATING_IMAGE, MOVING, PROVISIONING, RUNNING, STARTING, STOPPED, STOPPING, TERMINATED, TERMINATING"
    echo
    exit 255
fi
#
# hands on!
#
echo 
echo "Looking for instances in $1 state in the whole tenancy..."
echo
tenancy=$(oci iam availability-domain list --all | jq -r '.data[0]."compartment-id"')
#
recorre $tenancy $1 
#
echo
echo "Finished, goodbye!"
echo