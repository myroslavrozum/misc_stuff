#!/bin/bash

region=$(/usr/bin/facter -p ec2_placement_availability_zone | sed 's/\(.*\)[a-z]/\1/')
instance_id=$(ec2-metadata -i | cut -d ' ' -f2)

# EC2 Tag 'custom:ConsulCluster' is used
# In case if it's a server node than it must be set to 'server'
# otherwise, if it's a client node then it must be set to 'farm' value of
# consul cluster, e.g:
# For 'platformconsulenv' servers this tag is set to 'server', while
# For 'platfvaultenv' servers this tag is set to 'platformconsulenv'
consul_role=$(ec2-describe-tags --filter 'resource-type=instance' \
  --filter "resource-id=${instance_id}" --filter 'key=custom:ConsulCluster' | cut -f5)

consul_cluster_to_join=$(/usr/bin/facter -p farm)
if [ "$consul_role" != "server" ]; then
  consul_cluster_to_join=$consul_role
fi

my_ip=$(/usr/bin/facter -p ipaddress)
consul_nodes=($(aws ec2 describe-instances \
  --filters "Name=tag:Group,Values=${consul_cluster_to_join}" --no-paginate --region $region\
      --query "Reservations[*].Instances[*].{IP:PrivateIpAddress}" --output text|\
      grep . | grep -v None | grep -v $my_ip))

if [ "$consul_role" == "server" ]; then
  #If it's a consul server node then we don't need it in the 'retry_join' list
  #this is why we are doing 'grep -v $my_ip' above, but number of nodes to wait
  #for bootstrap must include it, so that's why +1 here
  echo "consul_nodes_number=$(( ${#consul_nodes[@]} +1 ))"
else
  #if its a client node then it does not appear in the $consul_nodes above and
  #its IP is nof filtered with 'grep -v $my_ip' so we don't need to +1 here
  echo "consul_nodes_number=${#consul_nodes[@]}"
fi
echo "consul_nodes_list=\"$(echo ${consul_nodes[@]} | sed -e 's/ /\",\"/g')\""
echo "first_consul_node=${consul_nodes}"
