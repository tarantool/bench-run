#!/usr/bin/env python3

# Publish Tarantool performance metrics to InfluxDB database.

import argparse
import os
import sys

import git
from influxdb_client import InfluxDBClient, Point
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


def read_metrics_file(file_path):
    with open(file_path) as f:
        return f.read().strip().splitlines()


def main(args):
    validate_args(args)

    raw_metrics_as_list = read_metrics_file(args.file)
    try:
        repo = git.Repo(args.repo)
    except git.exc.InvalidGitRepositoryError:
        # Re-raise the error with a comprehensive description.
        raise git.exc.InvalidGitRepositoryError(f"Not a git repository: {os.path.abspath(args.repo)}")

    with InfluxDBClient(url=args.url, token=args.token, org=args.org) as client:
        point = Point(args.measurement)

        # Add fields.
        for raw_metric in raw_metrics_as_list:
            raw_metric_as_list = raw_metric.split(':')
            field_key = raw_metric_as_list[0].strip()
            field_value = float(raw_metric_as_list[1].strip())
            point = point.field(field_key, field_value)

        # Add tags.
        tags_map = {
            'branch_name': repo.active_branch.name,
            'commit_sha': repo.head.commit.hexsha,
            'build_version': repo.git.describe(),
            'author_name': repo.head.commit.author.name,
            'author_email': repo.head.commit.author.email,
            'authored_date': repo.head.commit.authored_date * 10 ** 9,  # convert to nanoseconds
            'committer_name': repo.head.commit.committer.name,
            'committer_email': repo.head.commit.committer.email,
            'committed_date': repo.head.commit.committed_date * 10 ** 9,  # convert to nanoseconds
            'commit_summary': repo.head.commit.summary,
        }
        for tag_key, tag_value in tags_map.items():
            point = point.tag(tag_key, tag_value)

        # Publish data.
        client.write_api(write_options=SYNCHRONOUS).write(args.bucket, args.org, point)

        print(point)


if __name__ == '__main__':
    sys.exit(main(parse_args()))
