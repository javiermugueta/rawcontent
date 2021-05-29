#!/bin/bash
# jmugueta may 2021
#
# recursive list of compute instances in tenancy
# CREATING_IMAGE, MOVING, PROVISIONING, RUNNING, STARTING, STOPPED, STOPPING, TERMINATED, TERMINATING
#
recorre(){
    for i in $(oci iam compartment list --compartment-id $1 | jq -r '.data[].id')
    do
        c=$((c+1))
        indent $c
        oci iam compartment get --compartment-id $i | jq -r '.data."name"'
        oci compute instance list --compartment-id $i --lifecycle-state $2 | jq -r '.data[]."display-name"'
        recorre $i 
        c=$((c-1))
    done
}
indent() {
  L=$1
  shift
  printf "["
  while [ $L -gt 0 ]
  do
    printf "+"
    L=$((L-1))
  done
  printf "]"
}
#
state=$1
tenancy=$(oci iam availability-domain list --all | jq -r '.data[0]."compartment-id"')
recorre $tenancy $state 