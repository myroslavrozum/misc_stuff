#!/bin/bash

[[ $FS_ID ]] || exit 1

[ -d /mnt/gfs/ ] || sudo mkdir -p /mnt/gfs/

MOUNT_OPTS='nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2'

for FS in ${FS_ID[@]}; do
  if [[ ! $(grep $FS /etc/mtab) ]]; then
	  sudo mount -t nfs4 -o $MOUNT_OPTS \
		  ${FS}.efs.us-east-1.amazonaws.com:/ \
		  /mnt/gfs/
  fi
  for tag in $(ls /mnt/gfs); do
    fs_tags="${fs_tags} ${FS}:${tag}"
  done
  sudo umount -f /mnt/gfs
done

#========================================
subscriptions=$(/usr/bin/aws ec2 describe-tags \
	--filters "Name=resource-type,Values=instance" \
		"Name=key,Values=Subscription" \
	--region=us-east-1 \
	| jq '.Tags[].Value'| tr -d '"' | sort -u | tr '\n' ' ')

#========================================
echo $fs_tags | tee fs_tags.txt
echo $subscriptions | tee subscription.txt
