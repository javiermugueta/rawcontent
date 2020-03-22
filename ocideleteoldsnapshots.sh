#!/bin/bash
# jmu mar/22/2020
#
# deletes snapshots of file system with id argument $1 older than the number of days passed as $2 argument
#
filesystem_id=$1 #"ocid1.filesystem.oc1.eu_frankfurt_1.aaaaaaaaaaab5orimzzgcllqojxwiotfouwwm4tbnzvwm5lsoqwtcllbmqwtgaaa"
numdays=$2
limitdate=$(date -d "-$numdays days" --date="%Y-%m-%d %H:%M:%S")
echo "Will delete snapshots older than "$limitdate
# list of snapshots
sninfo=`oci fs snapshot list --file-system-id $filesystem_id`
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
    echo "Snapshot name: "$name
    echo "Snapshot id: "$id
    echo "Snapshot creation date: "$created
    if [[ $created < $limitdate ]]; then
        echo "Deleting snapshot $name"
        oci fs snapshot delete --snapshot-id $id --force
    fi
done
echo "Finished, have a good day!"