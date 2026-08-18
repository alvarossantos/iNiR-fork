#!/usr/bin/env bash
# Based on https://unix.stackexchange.com/a/602935

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Skip if already unlocked
if "${SCRIPT_DIR}/is_unlocked.sh"; then
    exit 1
fi

# Prompt for password if not provided
if [[ -z "${UNLOCK_PASSWORD}" ]]; then
    echo -n 'Login password: ' >&2
    read -s UNLOCK_PASSWORD || return
fi

# Unlock — pipe directly to gnome-keyring-daemon, no eval.
# The daemon outputs "export VAR=VALUE" lines on stdout which we source.
killall -q -u "$(whoami)" gnome-keyring-daemon
while IFS= read -r line; do
    export "${line#export }"
done < <(echo -n "${UNLOCK_PASSWORD}" \
            | gnome-keyring-daemon --daemonize --login 2>/dev/null)
unset UNLOCK_PASSWORD
echo '' >&2
