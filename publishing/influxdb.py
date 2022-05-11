#!/usr/bin/env python3

# Publish Tarantool performance metrics to InfluxDB database.

import argparse
import math
import os
import platform
import sys
import time

import git
from influxdb_client import InfluxDBClient, Point
from influxdb_client.client.write_api import SYNCHRONOUS

NA_STR = 'n/a'
PREV_RECORD_TIME_RANGE = '-1mo'  # in months


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
    parser.add_argument(
        '-p', '--prev', action='store_true', help='Add data of the previous DB record to the new record'
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


def div(a, b, precision=3):
    # `a` - 'curr' value, `b` - 'prev' value.
    return round(a / b, precision)


def main(args):
    validate_args(args)

    metrics = load_metrics(args.file)
    try:
        repo = git.Repo(args.repo)
    except git.exc.InvalidGitRepositoryError:
        # Re-raise the error with a comprehensive description.
        raise git.exc.InvalidGitRepositoryError(f"Not a git repository: {os.path.abspath(args.repo)}")

    with InfluxDBClient(url=args.url, token=args.token, org=args.org) as client:
        point = Point(args.measurement)

        # Add fields.

        for field_key, field_value in metrics.items():
            point = point.field(f"{field_key}.curr", field_value)
            point = point.field(f"{field_key}.prev", -1.0)  # -1 means 'not defined'
            point = point.field(f"{field_key}.ratio", -1.0)

        point = point.field('gmean.curr', gmean(metrics.values()))
        point = point.field('gmean.prev', -1.0)
        point = point.field('gmean.ratio', -1.0)

        # Add tags.

        tags_curr = {
            'branch_name.curr': repo.active_branch.name,
            'commit_sha.curr': repo.head.commit.hexsha,
            'build_version.curr': repo.git.describe(),
            'author_name.curr': repo.head.commit.author.name,
            'author_email.curr': repo.head.commit.author.email,
            'authored_date.curr': repo.head.commit.authored_date * 10**9,  # convert to nanoseconds
            'committer_name.curr': repo.head.commit.committer.name,
            'committer_email.curr': repo.head.commit.committer.email,
            'committed_date.curr': repo.head.commit.committed_date * 10**9,  # convert to nanoseconds
            'commit_summary.curr': repo.head.commit.summary,
            'machine_type.curr': platform.machine(),
            'distribution_type.curr': 'ce',
            'gc64_enabled.curr': 'false',
        }
        tags_prev = {
            'branch_name.prev': NA_STR,
            'commit_sha.prev': NA_STR,
            'build_version.prev': NA_STR,
            'author_name.prev': NA_STR,
            'author_email.prev': NA_STR,
            'authored_date.prev': NA_STR,
            'committer_name.prev': NA_STR,
            'committer_email.prev': NA_STR,
            'committed_date.prev': NA_STR,
            'commit_summary.prev': NA_STR,
            'machine_type.prev': NA_STR,
            'distribution_type.prev': NA_STR,
            'gc64_enabled.prev': NA_STR,
        }

        point = point.tag('record_date.prev', NA_STR)
        for tag_key, tag_value in {**tags_curr, **tags_prev}.items():
            point = point.tag(tag_key, tag_value)

        # Add data of the previous DB record to the new record.
        if args.prev:
            query = (
                f"from(bucket: \"{args.bucket}\") "
                f"|> range(start: {PREV_RECORD_TIME_RANGE}) "
                f"|> filter(fn: (r) => r._measurement == \"{args.measurement}\") "
                f"|> filter(fn: (r) => r[\"branch_name.curr\"] == \"{repo.active_branch.name}\") "
                f"|> group(columns: [\"_time\"], mode: \"by\") "
                f"|> sort(columns: [\"_time\"])"
            )

            # Fill up fields.

            tables = client.query_api().query(query, org=args.org)
            if tables:
                # Tables are sorted by time. So taking the latest one.
                for record in tables[-1]:
                    if record['_field'] == 'gmean.curr':
                        point = point.field('gmean.prev', record['_value'])
                    elif not record['_field'].startswith('gmean') and record['_field'].endswith('.curr'):
                        field_key = record['_field'].replace('.curr', '.prev')
                        point = point.field(field_key, record['_value'])
                        point = point.field(
                            field_key.replace('.prev', '.ratio'), div(point._fields[record['_field']], record['_value'])
                        )

                point = point.field('gmean.ratio', div(point._fields['gmean.curr'], point._fields['gmean.prev']))

                # Fill up tags.
                point = point.tag('record_date.prev', int(record['_time'].timestamp() * 10**9))  # convert to ns
                for tag_key in tags_prev:
                    point = point.tag(tag_key, record[tag_key.replace('.prev', '.curr')])
            else:
                print('\nWARNING: No previous DB record found\n')

        # Publish data.
        point = point.time(time.time() * 10**9)  # convert to nanoseconds
        client.write_api(write_options=SYNCHRONOUS).write(args.bucket, args.org, point)

        if args.save:
            with open(args.save, 'w') as f:
                f.write(point.to_line_protocol() + '\n')
        else:
            print(point)


if __name__ == '__main__':
    sys.exit(main(parse_args()))
