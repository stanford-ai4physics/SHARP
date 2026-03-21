#!/bin/bash
# Container entrypoint: sets up SSH, then runs the CMD.
# Runs as the researcher user; uses sudo only for starting sshd.

set -e

# --- SSH setup ---
if [ -n "$SSH_PUBKEY" ]; then
    echo "Setting up SSH access for researcher..."
    mkdir -p ~/.ssh
    echo "$SSH_PUBKEY" > ~/.ssh/authorized_keys
    chmod 700 ~/.ssh
    chmod 600 ~/.ssh/authorized_keys
    echo "Starting SSH daemon..."
    sudo /usr/sbin/sshd
    echo "SSH daemon started on port 22."
else
    echo "No SSH_PUBKEY set — SSH disabled."
fi

# Execute the CMD
exec "$@"
