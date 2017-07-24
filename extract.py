#!/usr/bin/python
#
# Extracts $vars and $sites disctionaries form puppet manifest and serializes them as JSON dictionary
# contents extracted as-is, if facts or variables used it willnot make attempt to assign values,
# also it is nt quering PuppetDB or dashboard for facts - just plain text translated into json.
#
import json
import sys
import re
import os.path

def jsonify_string(string):
  return string.replace('=>',':').replace("'",'"').replace(',}','}').replace(',]',']')

def parse_section(section2parse, content):
  section2parse='$'+section2parse
  if not os.path.isfile('init.pp'):
    return []

  i=0
  push_flag = False
  section2parse_foundat = 0
  section2parse_endsat = 0
  bracket_counter = 0

  content = re.sub(r'>(\$.*?),', r'>"\1",', content)
  for char in content:
    if ( i + len(section2parse)) <= len(content):
      section = content[i:i+len(section2parse)]
      suffix = content[ i+len(section2parse) : i+len(section2parse)+2 ]
      if section == section2parse and suffix == '={':
        section2parse_foundat = i

    brackets = []
    if section2parse_foundat > 0:
      if char == '{':
        bracket_counter += 1
      elif char == '}':
        bracket_counter -= 1
        if bracket_counter == 0:
          section2parse_endsat = i+1
          break
    i+= 1
  
  data = jsonify_string(content[ section2parse_foundat:section2parse_endsat ].replace(section2parse+'=', ''))
  #print data
  return [] if not data else json.loads(data)

f = open('init.pp')
content = ''
for line in f:
  line = line.strip()
  if not line.startswith('#'):
    content += line.replace(' ','')

for section in [ 'sites', 'vars' ]:
  print parse_section(section, content)
