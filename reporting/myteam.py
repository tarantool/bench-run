#!/usr/bin/env python3

# Send a message with Tarantool performance metrics to MyTeam chat.

import argparse
import os
import sys

from bot import bot as myteambot


def parse_args():
    parser = argparse.ArgumentParser(description='Send a message with Tarantool performance metrics to MyTeam chat')
    parser.add_argument('-u', '--url', default=env_opt('MYTEAM_URL'), help='MyTeam API connection URL')
    parser.add_argument('-t', '--token', default=env_opt('MYTEAM_TOKEN'), help='MyTeam token for API requests')
    parser.add_argument('-c', '--chat-id', default=env_opt('MYTEAM_CHAT_ID'), help='MyTeam chat ID')
    parser.add_argument('-m', '--message', help='Message to send')
    parser.add_argument('-f', '--file', help='Path to the file with message to send')
    parser.add_argument('-F', '--format', choices=['Text', 'MarkdownV2'], default='Text', help='Message format to use')

    return parser.parse_args()


def env_opt(name):
    return os.environ.get(name)


def validate_args(args):
    for arg_name in ['url', 'token', 'chat_id']:
        if not getattr(args, arg_name):
            raise ValueError(
                f"Argument '--{arg_name.replace('_', '-')}' must be provided or "
                f"'MYTEAM_{arg_name.upper()}' env variable must be defined"
            )

    for arg_name in ['message', 'file']:
        if getattr(args, arg_name) == '':
            raise ValueError(f"Value for argument '--{arg_name}' must not be empty")

    if not any([args.message, args.file]):
        raise ValueError("Argument '--message' or '--file' must be provided")

    if all([args.message, args.file]):
        raise ValueError("Cannot use '--message' and '--file' arguments at the same time")


def main(args):
    validate_args(args)

    bot = myteambot.Bot(api_url_base=args.url, token=args.token)

    message = args.message
    if args.file:
        with open(args.file) as f:
            # All special characters that do not indicate the beginning or end of a text style must be escaped with
            # a backslash.
            message = f.read().strip().replace('_', '\\_')
            if not message:
                raise ValueError('Message file is empty')

    if args.format == 'Text':
        # There is no 'Text' parse mode, defined for convenience.
        args.format = None
    elif args.format == 'MarkdownV2':
        message = f"```\n{message}```"

    response = bot.send_text(chat_id=args.chat_id, text=message, parse_mode=args.format)
    assert response.json()['ok'], response.json()


if __name__ == '__main__':
    sys.exit(main(parse_args()))
