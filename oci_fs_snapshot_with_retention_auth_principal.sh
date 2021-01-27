#!/bin/bash
# jmu mar/22/2020
# jmu jan/28/2021 - version that works for --auth instance_principal approach
# 1) creates snapshot of file system with ocid of argument $1
# 2) deletes snapshots  older than the number of days passed as $2 argument
#
fs=$1 
numdays=$2
#
#
# creating one snapshot now
fecha=$(date)
oci fs snapshot create --file-system-id $fs --name "snapshot_$fecha" --auth instance_principal
#
# let's see if there are stuff to delete
#
limitdate=$(date -d "-$numdays days" +"%Y-%m-%d %H:%M:%S")
echo "Will delete snapshots older than "$limitdate
# list of snapshots
sninfo=`oci fs snapshot list --file-system-id $fs --auth instance_principal`
sninfo="${sninfo//time-created/time_created}"
#echo $sninfo
count=`echo $sninfo | jq '.data | length'`
count=`expr $count - 1`
# looping records
for i in $(eval echo {0..$count})
do
    name=`echo $sninfo | jq .data[$i].name`
    name=$(eval echo $name)
    id=`echo $sninfo | jq .data[$i].id`
    id=$(eval echo $id)
    created=`echo $sninfo | jq .data[$i].time_created`
    created=$(eval echo $created)
    #echo "Snapshot name: "$name
    #echo "Snapshot id: "$id
    #echo "Snapshot creation date: "$created
    if [[ $created < $limitdate ]]; then
        echo "Deleting snapshot $name"
        oci fs snapshot delete --snapshot-id $id --force --auth instance_principal
    fi
done
echo "Finished, have a good day!"