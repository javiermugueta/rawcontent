#!/bin/bash
# jmu 30/Nov/2019
# this script needs jq (yum install jq, brew install jq, ....)
#
compartment=$1
bucket=$2
#
usage(){
    echo "Usage:"
    echo "      ./auditoser.sh compartmentid bucketname"
    echo "Example:"
    echo "./auditoser.sh ocid1.compartment.oc1..aaaaaaaa3sz43qrfhsjmbibsrc6e7c2ftlt53gfnzifvlow2yoz7hk3ni2jq AUDIT"
}
#
if [[ "$#" -ne 2 ]]; then
    echo
    echo "Wrong number of arguments passed!"
    echo
    usage
    exit
fi
# the tool archives the day before
initial=$(date -v-1d "+%Y-%m-%d")"T00:00:00.000Z"
final=$(date -v-1d "+%Y-%m-%d")"T23:59:59.999Z"
#
echo "OCI Audit to Object Storage Archiver"
echo "Initial audit date: ${initial}"
echo "Final audit date: ${final}"
file=audit-${initial}-${final}
# empty file
echo "" > file
# the first command to execute, results come paginated
command="oci audit event list --compartment-id ${compartment} --start-time ${initial} --end-time ${final}"
while :
do
    #
    result=`$command`
    # this variable stores the records
    records=`echo $result | jq '.data'`
    echo ${records} >> ${file}
    # this variable stores the next page of results
    nextpage=`echo $result | jq '.["opc-next-page"]'`
    nextpage=$(eval echo $nextpage)
    #echo ${nextpage}
    if [[ "$nextpage" == "" ]]; then
        # no more pages
        break
    fi
    # recurring calls with page parameter
    command="oci audit event list --compartment-id ${compartment} --start-time ${initial} --end-time ${final} --page ${nextpage}"
    #echo ${command}
    # don't wanna fry the cpu
    sleep 1
done
# uploading to object storage overwriting if file already exists
oci os object put -bn ${bucket} --file ${file} --force --output table
rm ${file}
echo "goodbye!"
