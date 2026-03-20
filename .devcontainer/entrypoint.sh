#!/bin/bash
# Container entrypoint: sets up SSH, clones the project repo, then runs the CMD.
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

# --- Clone project repo ---
if [ -n "$GH_TOKEN" ] && [ -n "${GH_REPO:-}" ]; then
    echo "Cloning ${GH_REPO} into /workspace..."
    git clone "https://x-access-token:${GH_TOKEN}@github.com/${GH_REPO}.git" /workspace
    # Configure git to use the token for future operations (push/pull)
    git -C /workspace config credential.helper \
        '!f() { echo "username=x-access-token"; echo "password='"${GH_TOKEN}"'"; }; f'
    echo "Repository cloned."
else
    echo "No GH_TOKEN/GH_REPO set — skipping repo clone."
fi

# Execute the CMD
exec "$@"
