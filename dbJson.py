#!/bin/env python
import boto
from boto.s3.connection import S3Connection
import json
import collections
import os

def dumpkeys(data, filename):
  keys = data.keys()
  with open("/tmp/rundeck_json/%s.json" % filename, 'w') as outfile:
    json.dump(keys, outfile)
  for key in keys:
    if type(data[key]) is dict or type(data[key]) is collections.defaultdict:
      dumpkeys(data[key], "%s.%s" % (filename, key))
    else:
      print "%s ====> %s " % (key, data[key])
      with open("/tmp/rundeck_json/%s.%s.json" % (filename, key), 'w') as outfile:
        json.dump(list(data[key]), outfile)

s3 = boto.connect_s3()
bucket = s3.get_bucket('@option.bucket@')

bucket_contents = bucket.list()
#we support only 4-element deep storage 'backup_schedule, environment, site, filename'
files_data = filter(lambda l: len(l) == 4,
  map(lambda key: key.name.split('/'), bucket_contents))

#https://stackoverflow.com/questions/16724788/how-can-i-get-python-to-automatically-create-missing-key-value-pairs-in-a-dictio/16724937
nested_dict = lambda: collections.defaultdict(nested_dict)
data = nested_dict()

#transform flat list 'files_data' into nested dictionary
# { backup_schedule => environment => site => [backup_files] }
for (backup_schedule, environment, site, filename) in files_data:
  if site in data[backup_schedule][environment]:
      data[backup_schedule][environment][site].add(filename)
  else:
      data[backup_schedule][environment][site] = set([filename])

if not os.path.exists('/tmp/rundeck_json'):
    os.makedirs('/tmp/rundeck_json')
#recursively create files basing on dictionary created on previous steps
dumpkeys(data, 'db-envs')
