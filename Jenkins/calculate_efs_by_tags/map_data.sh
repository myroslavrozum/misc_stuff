#!/bin/bash

set +x

REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document|\
  grep region|awk -F\" '{print $4}')
instance_id=$(curl -s http://169.254.169.254/latest/meta-data/instance-id/)
aws ec2 create-tags --resources ${instance_id}\
  --tags Key=org:JenkinsJob,Value=\"${BUILD_URL}\"\
  --region=$REGION

echo "FS_to_TAG            : ${FS_to_TAG}"

FS_ID=$(echo $FS_to_TAG | cut -d':' -f1)
TAG=$(echo $FS_to_TAG | cut -d':' -f2)

[[ $FS_to_TAG ]] || exit 1
[[ $FS_SUBSCRIPTIONS == *$TAG* ]] || (echo "Directory is not Tag"; exit 1)

[ -d /mnt/gfs/${FS_ID}_${TAG} ] || sudo mkdir -p /mnt/gfs/${FS_ID}_${TAG}

MOUNT_OPTS='nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2'
if [[ ! $(grep ${FS_ID}_${TAG} /etc/mtab) ]]; then
	sudo mount -t nfs4 -o $MOUNT_OPTS \
		${FS_ID}.efs.us-east-1.amazonaws.com:/${TAG} \
		/mnt/gfs/${FS_ID}_${TAG}/
fi

size=$(du -sm /mnt/gfs/${FS_ID}_${TAG}/ | awk '{print $1}')
sudo umount -f /mnt/gfs/${FS_ID}_${TAG}

echo "${FS_ID} ${TAG},${size}" | tee efs_size_by_tags_${FS_ID}_${TAG}.csv

