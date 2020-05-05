#!/usr/bin/env python
import fnmatch
import os
from urllib import urlencode
import requests


def parse_bench(filename):
    with open(filename) as raw_data:
        return raw_data.readlines()


def get_version(filename):
    with open(filename) as raw_data:
        version = raw_data.readlines()[-1]
        return version.split()[0]


def push_to_microb(server, token, name, value, version, tab):
    uri = 'http://%s/push?%s' % (server, urlencode(dict(
        key=token, name=name, param=value,
        v=version, unit='trps', tab=tab
    )))

    r = requests.get(uri)
    if r.status_code == 200:
        print('Export complete')
    else:
        print('Export error http: %d' % r.status_code)
        print('Export error text: %d' % r.text)


def main():
    if "MICROB_WEB_TOKEN" in os.environ and "MICROB_WEB_HOST" in os.environ:
        bench = {}
        res = []
        current_data = {}
        version = ''
        for file in os.listdir('.'):
            if fnmatch.fnmatch(file, '*_result.txt'):
                values = parse_bench(file)
                benchmark = file.split('_')[0]
                version = get_version('{}_t_version.txt'.format(benchmark))
                for value in values:
                    test_name = value.split(':')[0]
                    test_res = float(value.split(':')[1])
                    res.append(test_res)
                    push_to_microb(
                        os.environ['MICROB_WEB_HOST'],
                        os.environ['MICROB_WEB_TOKEN'],
                        test_name,
                        test_res,
                        version,
                        benchmark,
                    )
        print ("VERSION - ", version)
    else:
        print("MICROB params not specified")

    return 0


if __name__ == '__main__':
    main()
