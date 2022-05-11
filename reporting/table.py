#!/usr/bin/env python3

# Make a result table with Tarantool performance metrics.

import argparse
from datetime import datetime as dt
import math
import sys

VAL_COLUMN_NAMES = ['Curr(rps)', 'Prev(rps)', 'Ratio']
COMMENTS_TEMPLATE = """
# Curr:
#   branch:  {curr_branch}
#   build:   {curr_build}
#   date:    {curr_date}
#   summary: {curr_summary}
#   machine: {curr_machine}
#   distrib: {curr_distrib}
#   gc64:    {curr_gc64}
# Prev:
#   branch:  {prev_branch}
#   build:   {prev_build}
#   date:    {prev_date}
#   summary: {prev_summary}
#   machine: {prev_machine}
#   distrib: {prev_distrib}
#   gc64:    {prev_gc64}
"""
ESCAPE_TO_PLACEHOLDER = {'\\ ': '<space>', '\\,': '<coma>', '\\=': '<equal>'}
PLACEHOLDER_TO_CHAR = {'<space>': ' ', '<coma>': ',', '<equal>': '='}


def parse_args():
    parser = argparse.ArgumentParser(description='Make a result table with Tarantool performance metrics')
    parser.add_argument(
        '-i',
        '--input',
        required=True,
        metavar='FILE',
        help="Path to the file with InfluxDB record in the 'line protocol' form",
    )
    parser.add_argument(
        '-o',
        '--output',
        nargs='?',
        metavar='FILE',
        const='result_table.txt',
        help='Save the result table to the specified file',
    )

    return parser.parse_args()


def load_db_record(file_path):
    record = {'name': {}, 'fields': {}, 'tags': {}}

    with open(file_path) as f:
        contents = f.read().strip()

    contents = contents.rsplit(' ', maxsplit=1)[0]  # drop timestamp from raw record
    left_record_part, right_record_part = contents.rpartition(' ')[::2]
    record['name'], raw_tags_part = left_record_part.partition(',')[::2]

    for raw_metric_entry in right_record_part.split(','):
        full_metric_name, metric_value = raw_metric_entry.partition('=')[::2]
        metric_name, metric_type = full_metric_name.rpartition('.')[::2]
        record['fields'].setdefault(metric_type, {})[metric_name] = float(metric_value)

    for raw_tag_entry in replace(raw_tags_part, ESCAPE_TO_PLACEHOLDER).split(','):
        full_tag_name, tag_value = raw_tag_entry.partition('=')[::2]
        tag_name, tag_type = full_tag_name.rpartition('.')[::2]
        record['tags'].setdefault(tag_type, {})[tag_name] = replace(tag_value, PLACEHOLDER_TO_CHAR)

    return record


def replace(string, replace_map):
    for old, new in replace_map.items():
        string = string.replace(old, new)

    return string


def gen_table(columns, column_names=None, name_column_size='auto', val_column_size='auto', val_precision=3):
    table_lines = []

    if name_column_size == 'auto':
        size1 = len(column_names[0]) if column_names else 0
        size2 = len(max(columns['metric'], key=len))
        name_column_size = max(size1, size2) + 1
    if val_column_size == 'auto':
        all_columns = columns['curr'] + columns['prev'] + columns['ratio']
        size1 = len(max(column_names[1:], key=len)) if column_names else 0
        size2 = len(f"{max(all_columns, key=lambda x: len(f'{x:.{val_precision}f}')):.{val_precision}f}")
        val_column_size = max(size1, size2) + 1

    rows = list(zip(columns['metric'], columns['curr'], columns['prev'], columns['ratio']))
    val_columns_count = len(rows[0]) - 1
    name_delimiter = '+' + '-' * name_column_size + '+'
    val_delimiter = '-' * val_column_size + '+'
    delimiter = name_delimiter + val_delimiter * val_columns_count

    column_sizes = {'name_size': name_column_size, 'val_size': val_column_size}
    column_names_template = '|{:{name_size}s}|' + '{:>{val_size}}|' * val_columns_count
    row_template = '|{:{name_size}s}|' + f"{{:{{val_size}}.0{val_precision}f}}|" * val_columns_count
    gmean_row = None

    if column_names:
        table_lines.append(delimiter)
        table_lines.append(column_names_template.format(*column_names, **column_sizes))

    table_lines.append(delimiter)
    for row in rows:
        if 'gmean' in row:
            gmean_row = row
            continue
        table_lines.append(row_template.format(*row, **column_sizes))
    table_lines.append(delimiter)

    if gmean_row:
        table_lines.append(row_template.format(*gmean_row, **column_sizes))
        table_lines.append(delimiter)

    return '\n'.join(table_lines)


def main(args):
    record = load_db_record(args.input)
    columns = {'metric': [], 'curr': [], 'prev': [], 'ratio': []}

    for metric_type in record['fields']:
        for metric_name, value in sorted(record['fields'][metric_type].items(), key=lambda x: x[0]):
            if metric_name not in columns.get('metric', []):
                columns['metric'].append(metric_name)
            columns[metric_type].append(value if value > -1 else math.nan)

    comments_template = COMMENTS_TEMPLATE.lstrip()
    curr_date = dt.fromtimestamp(int(record['tags']['curr']['committed_date'])).strftime('%a %d %b %H:%M:%S %Y %z')
    prev_date = record['tags']['prev']['committed_date']
    if prev_date.isdigit():
        prev_date = dt.fromtimestamp(int(prev_date)).strftime('%a %d %b %H:%M:%S %Y %z')
    comments = comments_template.format(
        curr_branch=record['tags']['curr']['branch_name'],
        curr_build=record['tags']['curr']['build_version'],
        curr_date=curr_date,
        curr_summary=record['tags']['curr']['commit_summary'],
        curr_machine=record['tags']['curr']['machine_type'],
        curr_distrib=record['tags']['curr']['distribution_type'],
        curr_gc64=record['tags']['curr']['gc64_enabled'],
        prev_branch=record['tags']['prev']['branch_name'],
        prev_build=record['tags']['prev']['build_version'],
        prev_date=prev_date,
        prev_summary=record['tags']['prev']['commit_summary'],
        prev_machine=record['tags']['prev']['machine_type'],
        prev_distrib=record['tags']['prev']['distribution_type'],
        prev_gc64=record['tags']['prev']['gc64_enabled'],
    )
    column_names = [record['name'].capitalize(), *VAL_COLUMN_NAMES]
    table = comments + gen_table(columns, column_names)

    if args.output:
        with open(args.output, 'w') as f:
            f.write(table + '\n')
    else:
        print(table)


if __name__ == '__main__':
    sys.exit(main(parse_args()))
