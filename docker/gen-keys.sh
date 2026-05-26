#!/usr/bin/env bash
# Generates the SSH key pair used by Ansible to connect to the ubuntu-target container.
# Keys are stored at ~/.ansible-tp2/ (outside the workspace) so they survive
# `actions/checkout` clean operations between CI jobs.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KEY_DIR="$HOME/.ansible-tp2"
PUBKEY_DST="$SCRIPT_DIR/ubuntu-target/authorized_keys"

mkdir -p "$KEY_DIR"
chmod 700 "$KEY_DIR"

if [ ! -f "$KEY_DIR/ansible_ed25519" ]; then
  ssh-keygen -t ed25519 -f "$KEY_DIR/ansible_ed25519" -N "" -C "ansible@devops-tp2"
  echo "SSH key pair generated at $KEY_DIR/ansible_ed25519"
else
  echo "SSH key already exists at $KEY_DIR/ansible_ed25519"
fi

chmod 600 "$KEY_DIR/ansible_ed25519"
chmod 644 "$KEY_DIR/ansible_ed25519.pub"

cp "$KEY_DIR/ansible_ed25519.pub" "$PUBKEY_DST"
echo "Public key copied to $PUBKEY_DST"
echo ""
echo "Next steps:"
echo "  cd docker && docker compose up -d --build"
