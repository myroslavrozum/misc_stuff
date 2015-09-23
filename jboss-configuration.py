#!/usr/bin/python
# -*- coding: utf-8 -*-
#
# (c) 2015, Myroslav Rozum <Myroslav_Rozum1@epam.com>
#
# This file is part of SLON-SCM, Epam
#
import json
import sys
import os

DOCUMENTATION = """
---
module: init_jboss_configuration_cli
short_description:
    Initialize JBoss configuration via CLI
description:
    - Retreives current configuration version from JBoss server
    - basing on previous step reads list of CLI script templates and filters them by version
version_added: "0.0"
options:
    cli_path:
        description:
            - path to jboss CLI
        default: /opt/apps/jboss-cli/bin/jboss-cli.sh
        required: false
    user:
    password:
    controller:
    scripts_src:
        description:
            - path to CLI templates
        required: false
        default: null
    action:
        description:
            - what to do
        required: true
        default: null
    script:
        description:
            - what to run if 'action' is 'run_script'
        required: false
        default: null
    command:
        description:
            - what to run if 'action' is 'run_command'
        required: false
        default: null
    files:
        description:
            - Set of CLI scripts templates to process in form of tuple: (name.cli.j2, name.cli)
        required: false
        default: null
    server_group:
        description:
            - name of server_group to store "einvoicing_config_version"
        required: false
        default: null
requirements:
    - jboss-cli installed on the same server
author:
    - "Myroslav Rozum"
"""

debug = False
slonscm_configuration_property = "einvoicing_config_version"

class JbossCliError(Exception):
    def __init__(self, value):
        self.value = value
        self.str_value = json.dumps(value)

    def __str__(self):
        return repr(self.value)

class JBossCli(object):
    def __init__(self, module, cli_path, user, password, controller, server_group):
        self.changed = False
        self.module = module
        self.cli_path = cli_path
        self.user = user
        self.password = password
        self.controller = controller
        # select whether we dump additional debug info through syslog
        self.syslogging = False
        self.cli = "%s --connect --user=%s --password=%s controller=%s " % (self.cli_path,
                                                                          self.user,
                                                                          self.password,
                                                                          self.controller)
        if server_group is not None:
            self.where = "/server-group="+ server_group 
        else:
            self.where = ""

    def run_cli( self, command ):
        output = os.popen(self.cli  + command).read()
        #nornalize jboss-cli version of json to parse it with python
        output = output.replace("=>", ":").replace("undefined","\"undefined\"").replace("\n", "")
        if debug : print output
        try:
            return json.loads(output)
        except ValueError:
            return output

    def run_command(self, command):
        return self.run_cli("-c " + command)

    def jboss_get_property( self, property ):        
        out = self.run_command(self.where + "'/system-property=%s:read-resource'" % ( property ))
        if out["outcome"] == 'failed':
            if out["failure-description"].startswith("JBAS014807"):
                val = None
            else:
                self.module.fail_json(msg="jboss-cli failed", var=var)
        else:
            val = out["result"]["value"]
        return val

    def jboss_set_property(self, property, value ):
        self.changed = True
        out = self.run_command(self.where + "'/system-property=%s:read-resource'" % ( property ))
        if out["outcome"] == 'success':
            self.run_command(self.where + "'/system-property=%s:remove'" % ( property ))
        out = self.run_command(self.where + "'/system-property=%s:add(value=%s)'" % (property, value))

    def execute_script(self, script, config_version):
        (sdate, stime, sversion, sname, sext) = script.split('.')
        (date, time, version) = config_version.split('.')
        out = self.run_cli("--file=" + script)
        self.changed = True
        return out

    def log_message(self, message):
        if self.syslogging:
            syslog.syslog(syslog.LOG_NOTICE, 'ansible: "%s"' % message)

    def get_config_version(self):
        var = self.jboss_get_property(slonscm_configuration_property)
        out = {}
        #if config_version is not set intialize it with 0
        if var is None:
            out = self.jboss_set_property(slonscm_configuration_property, "%d.%d%d.0" % (1980, 0, 0))
        else:
            out["outcome"] = "success"
            out["result"] = var
        var = self.jboss_get_property(slonscm_configuration_property)
        return (str(var), out)

def reverse_version(a, b):
    (adate, atime, aversion, aname, aext) = a[0].split('.')
    (bdate, btime, bversion, bname, bext) = b[0].split('.')
    cmp_date = int(adate) - int(bdate)
    cmp_time = int(atime) - int(btime)
    cmp_version = int(aversion) - int(bversion)
    return 1 if ((cmp_date > 0) or (cmp_date == 0 and cmp_time > 0) or
                 (cmp_date == 0 and cmp_time == 0 and cmp_version > 0)) else -1

def filter_by_version(version, files):
    if debug: print "v: %s, f: %s" % (version, files)
    (date, time, version) = version.split('.')
    for f in files:
        (fdate, ftime, fversion, fname, fext) = f.split('.')
        if ((fdate > date) or
            (ftime > time and fdate == date) or
            (fversion > version and fdate == date and ftime == time)):
            script_name = '.'.join(f.split('.')[0:-1])
            yield f, script_name

def main():
    module = AnsibleModule(
        argument_spec = dict(
            cli_path = dict(required=False, default='/opt/apps/jboss-cli/bin/jboss-cli.sh'),
            user = dict(required=True),
            password = dict(required=True),
            controller = dict(required=True),
            scripts_src = dict(required=False),
            script = dict(required=False),
            command = dict(required=False),
            action = dict(required=True,
                           choices=['init', 'run_command', 'run_script', 'commit']),
            files = dict(required=False),
            server_group = dict(required=False)
        ),
        supports_check_mode = False
    )
    cli_path = module.params['cli_path']
    user = module.params['user']
    password = module.params['password']
    controller = module.params['controller']
    scripts_src = module.params['scripts_src']
    command = module.params['command']
    action = module.params['action']
    script = module.params['script']
    files = module.params['files']
    server_group = module.params['server_group']

    changed = False
    jboss_cli = JBossCli(module, cli_path, user, password, controller, server_group)

    if jboss_cli.syslogging:
        syslog.openlog('ansible-%s' % os.path.basename(__file__))
        syslog.syslog(syslog.LOG_NOTICE, 'jboss-cli instantiated - name: "%s"' % name)

    (config_version, out) = jboss_cli.get_config_version()
    if action == "init":
        files = list(filter_by_version(config_version,
                                     [ f for f in os.listdir(scripts_src) if f.endswith('.cli.j2') ]))
        files = sorted(files, cmp=reverse_version)
        if debug: print list(files)
        #result.files is tuple which comtains of pare of names template and resulting script
        module.exit_json(changed=jboss_cli.changed,
                         config_version=config_version,
                         files=files, output=out)
    elif action == "run_script":
        out = jboss_cli.execute_script( scripts_src + script, config_version )
        module.exit_json(changed = jboss_cli.changed,
                         output=out)
    elif action == "run_command":
        out = jboss_cli.run_command( command )
        if out["outcome"] == 'failed':
            module.fail_json(var)
        module.exit_json(changed=jboss_cli.changed,
                         output=out)
    elif action == "commit" :
        output = []
        if len(files) == 0:
            module.exit_json(changed = False,
                         output = "No CLI scripts processed",
                         config_version = config_version)

        last_cli_script = files[-1][0].split('.')
        old_config_version = jboss_cli.get_config_version()[0]
        config_version = "%s.%s.%s" % (last_cli_script[0], last_cli_script[1],
                                       last_cli_script[2])
        if old_config_version != config_version:
            var = jboss_cli.run_command(jboss_cli.where + "/system-property=%s:remove" % (slonscm_configuration_property))
            if var["outcome"] == 'failed':
                module.fail_json(msg=json.dumps(var))
            out = jboss_cli.jboss_set_property(slonscm_configuration_property, config_version)
        module.exit_json(changed = jboss_cli.changed,
                         output = out,
                         config_version = config_version)
    else:
        module.fail_json(msg="Command unknown")

from ansible.module_utils.basic import *
main()
