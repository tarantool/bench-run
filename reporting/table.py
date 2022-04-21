#!/usr/bin/env python3

# Make a result table with Tarantool performance metrics.

import argparse
import math
import sys

VAL_COLUMN_NAMES = ['Curr(rps)', 'Prev(rps)', 'Ratio']


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
    record = {'name': {}, 'fields': {}}

    with open(file_path) as f:
        contents = f.read().strip()

    record['name'] = contents.split(',')[0]
    for raw_metric_entry in contents.split(' ')[-1].split(','):
        metric_entry_as_list = raw_metric_entry.split('=')
        record['fields'][metric_entry_as_list[0]] = float(metric_entry_as_list[1])

    return record


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
    columns = {}

    for full_metric_name, value in sorted(record['fields'].items()):
        name_as_list = full_metric_name.rsplit('.', maxsplit=1)
        metric_name = name_as_list[0]
        metric_type = name_as_list[-1]
        if metric_name not in columns.get('metric', []):
            columns.setdefault('metric', []).append(metric_name)
        columns.setdefault(metric_type, []).append(value if value > 0 else math.nan)

    column_names = [record['name'].capitalize(), *VAL_COLUMN_NAMES]
    table = gen_table(columns, column_names)

    if args.output:
        with open(args.output, 'w') as f:
            f.write(table)
    else:
        print(table)


if __name__ == '__main__':
    sys.exit(main(parse_args()))
