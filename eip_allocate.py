#!/usr/bin/env python
import subprocess
import pprint
import boto.ec2
import json
import os
import urllib2

region = urllib2.urlopen('http://169.254.169.254/latest/meta-data/placement/availability-zone').read()[:-1]
conn = boto.ec2.connect_to_region(region)
eips = conn.get_all_addresses()
allocation_pool = json.loads(os.environ['ATTACH_IPS'])

#Ment to avoi dinstallation of any unnecessary modules, so wirking with facts directly.
def facter2dict( lines ):
  res = {}
  for fact in [ line.split('=>') for line in lines if '=>' in line ]:
    #puppet facts contain '=>' so we need to first split string using this sign,
    #then use its first element as fact name and then join everything back using jsonish ':' instead
    res[fact[0].strip()] = ':'.join(fact[1:]).strip()
  return res

def get_facts():
  p = subprocess.Popen( ['facter'], stdout=subprocess.PIPE )
  p.wait()
  lines = p.stdout.readlines()
  return facter2dict( lines )

#AWS EC2 EIP Part
#returns dictionary of present EIPs where IP address is key and association + allocation ids are values for hash.
def get_all_eips():
  return { eip.public_ip: { 'association_id' : eip.association_id, 'allocation_id' : eip.allocation_id }
    for eip in eips if eip.domain == 'vpc' }

#check if public ip address assigned to instance is EIP
def has_eip_associated( instance_public_ip ):
  return instance_public_ip in [ eip.public_ip for eip in eips ]

def associate_eip( instance_id ):
  #scan through given list of IP, take first unallocated and assign
  for eip in [ eip for eip in eips if eip.public_ip in allocation_pool
                                      and eip.association_id is None ]:
    print "Associating EIP: %s" % eip.public_ip
    conn.associate_address(instance_id = instance_id,
                           public_ip = eip.public_ip,
                           allocation_id = eip.allocation_id )
    break

def disassociate_eip( public_ip ):
  print "Disassociating EIP"
  eip = [ eip for eip in eips if eip.public_ip == public_ip ][0]
  conn.disassociate_address( public_ip=public_ip,
                             association_id = eip.association_id )

if __name__ == "__main__":
  facts = get_facts()
  #conn = boto.ec2.connect_to_region(facts['region'])
  self_ip = facts['ec2_public_ipv4']
  self_instance_id = facts['ec2_instance_id']
  
  print "IPS to allocate: %s" % json.dumps(allocation_pool)
  
  if has_eip_associated( self_ip ):
    if not self_ip in allocation_pool:
      disassociate_eip( public_ip = self_ip )
      associate_eip( instance_id = self_instance_id )
  else:
    associate_eip( instance_id = self_instance_id )
