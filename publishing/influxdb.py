#!/usr/bin/env python3

# Publish Tarantool performance metrics to InfluxDB database.

import argparse
import math
import os
import platform
import sys
import time

import git
from influxdb_client import InfluxDBClient, Point, WritePrecision
from influxdb_client.client.write_api import SYNCHRONOUS


def parse_args():
    parser = argparse.ArgumentParser(description='Publish Tarantool performance metrics to InfluxDB database')
    parser.add_argument(
        '-m', '--measurement', choices=['cbench', 'sysbench'], required=True, help="Name of the measurement tool"
    )
    parser.add_argument(
        '-f', '--file', required=True, help="Path to the file with metrics data where each line is '<key>: <value>'"
    )
    parser.add_argument(
        '-s',
        '--save',
        nargs='?',
        metavar='FILE',
        const='db_record.txt',
        help="Save the new DB record to the specified file in the 'line protocol' form",
    )
    parser.add_argument(
        '-r', '--repo', default='.', help='Path to the Tarantool git repository. Should be switched to relevant branch'
    )
    parser.add_argument(
        '-u', '--url', default=env_opt('INFLUXDB_URL'), help="InfluxDB connection URL like 'http://localhost:8086'"
    )
    parser.add_argument('-o', '--org', default=env_opt('INFLUXDB_ORG'), help='InfluxDB organization name')
    parser.add_argument('-b', '--bucket', default=env_opt('INFLUXDB_BUCKET'), help='InfluxDB bucket name')
    parser.add_argument(
        '-t', '--token', default=env_opt('INFLUXDB_TOKEN'), help='InfluxDB token for making API requests'
    )

    return parser.parse_args()


def validate_args(args):
    for arg_name in ['url', 'org', 'bucket', 'token']:
        if not getattr(args, arg_name):
            raise ValueError(
                f"Argument '--{arg_name}' must be provided or "
                f"'INFLUXDB_{arg_name.upper()}' env variable must be defined"
            )


def env_opt(name):
    return os.environ.get(name)


def load_metrics(file_path):
    metrics = {}
    with open(file_path) as f:
        for line in f.read().strip().splitlines():
            if not line.startswith('#'):
                name, value = line.partition(':')[::2]
                metrics[name.strip()] = float(value.strip())

    return metrics


def gmean(dataset, precision=3):
    if not dataset:
        raise ValueError('Given dataset must not be empty')

    return round(math.exp(math.fsum(math.log(item) for item in dataset) / len(dataset)), precision)


def main(args):
    validate_args(args)

    metrics = load_metrics(args.file)
    try:
        repo = git.Repo(args.repo)
    except git.exc.InvalidGitRepositoryError:
        # Re-raise the error with a comprehensive description.
        raise git.exc.InvalidGitRepositoryError(f"Not a git repository: {os.path.abspath(args.repo)}")
    else:
        if os.path.basename(repo.remotes.origin.url.split('.git')[0]) != 'tarantool':
            raise git.exc.InvalidGitRepositoryError(f"Not a Tarantool git repository: {os.path.abspath(args.repo)}")

    with InfluxDBClient(url=args.url, token=args.token, org=args.org) as client:
        point = Point(args.measurement)

        # Add fields.
        for field_key, field_value in metrics.items():
            point = point.field(field_key, field_value)
        point = point.field('gmean', gmean(metrics.values()))

        # Add tags.
        tags = {
            'branch_name': 'master', #repo.active_branch.name,
            'commit_sha': repo.head.commit.hexsha,
            'build_version': repo.git.describe('--long'),
            'author_name': repo.head.commit.author.name,
            'author_email': repo.head.commit.author.email,
            'authored_date': repo.head.commit.authored_date,
            'committer_name': repo.head.commit.committer.name,
            'committer_email': repo.head.commit.committer.email,
            'committed_date': repo.head.commit.committed_date,
            'commit_summary': repo.head.commit.summary,
            'machine_type': platform.machine(),
            'distribution_type': 'ce',
            'gc64_enabled': 'false',
        }
        for tag_key, tag_value in tags.items():
            point = point.tag(tag_key, tag_value)

        # Publish data.
        point = point.time(int(time.time()), WritePrecision.S)
        client.write_api(write_options=SYNCHRONOUS).write(args.bucket, args.org, point)

        if args.save:
            with open(args.save, 'w') as f:
                f.write(point.to_line_protocol() + '\n')
        else:
            print(point)


if __name__ == '__main__':
    sys.exit(main(parse_args()))
