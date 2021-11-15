#!/usr/bin/env python3

import argparse
import fnmatch
import logging
import os
from typing import AnyStr
from typing import List

import requests

from metrics import Metric

URL = 'http://185.86.146.166:8086/api/v2/write?org=5d8890722b5f1318&bucket=metrics'  # NOQA


def parse_bench(filename: str) -> List[AnyStr]:
    with open(filename) as raw_data:
        return raw_data.readlines()


def get_version(filename: str) -> str:
    """Get tarantool version from the file

    Version is provided by benchmarks in a file <Benchmark>_t_version.txt.
    Example: Sysbench_t_version.txt includes '2.10.0-beta1-113-g16f7bf1'.
    """
    with open(filename) as raw_data:
        version = raw_data.readlines()[-1]
    version = version.split()[0]
    if not version:
        raise Exception("There was no version in a version file.")
    return version


def post_to_database(metric: Metric) -> None:
    """Post request to the database."""
    response = requests.post(
        URL, data=str(metric),
        headers={'Authorization': f'Token {os.environ["INFLUXDB_TOKEN"]}'}
    )

    logging.info(f"Sent metric: {metric} to the database. "
                 f"Response is {response.status_code}")

    if response.status_code >= 400:
        raise Exception(f"Bad response: {response.status_code}")


def main(directory: str):
    logging.info(f"Files will be published from {directory}")
    for file in os.listdir(directory):
        if fnmatch.fnmatch(file, '*_result.txt'):
            logging.info(f"{file} was matched as file with results")
            values = parse_bench(os.path.join(directory, file))
            benchmark = file.split('_')[0]
            version = get_version(
                os.path.join(directory, '{}_t_version.txt'.format(benchmark)))
            logging.info(f"VERSION - {version}")
            for value in values:
                test_name = value.split(':')[0]
                test_res = float(value.split(':')[1])
                metric = Metric(benchmark=benchmark,
                                values={test_name: test_res})
                post_to_database(metric)

    return 0


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument("-f", "--from-directory", required=True,
                    help="directory with files to publish")
    args = ap.parse_args()

    logging.basicConfig(format='%(levelname)s: %(message)s', level=logging.INFO)

    main(directory=args.from_directory)
