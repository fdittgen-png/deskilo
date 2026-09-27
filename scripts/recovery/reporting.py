# SPDX-License-Identifier: AGPL-3.0-or-later
"""Only allowlisted local evidence leaves a drill; raw subprocess logs stay private."""
import json
import platform
import time

from runtime import command


def environment(stack):
    images = {}
    for service in ['db', 'auth', 'storage']:
        image = command(['docker', 'inspect', '--format', '{{.Config.Image}}',
                         'supabase_' + service + '_' + stack.project]).decode().strip()
        images[service] = image
    return {'os': platform.system(), 'architecture': platform.machine(),
            'python': platform.python_version(), 'images': images,
            'schema': int(stack.sql('select public.deskilo_schema_version();'))}


class Timings:
    def __init__(self):
        self.previous = time.monotonic()
        self.values = {}

    def finish(self, name):
        now = time.monotonic()
        self.values[name] = round(now - self.previous, 3)
        self.previous = now


def public_json(report, secrets):
    output = json.dumps(report, indent=2) + '\n'
    if any(value and value in output for value in secrets):
        # Never echo the contaminated report or exception.
        return json.dumps({'format': 'deskilo.recovery', 'version': 1,
                           'status': 'failed', 'check': 'report_secret_detected'}) + '\n'
    return output
