#!/usr/bin/env bash
# Run this once before `docker compose up` to generate the SSH key pair
# used by Ansible to connect to the ubuntu-target container.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KEY_DIR="$SCRIPT_DIR/../ansible/ssh_keys"
PUBKEY_DST="$SCRIPT_DIR/ubuntu-target/authorized_keys"

mkdir -p "$KEY_DIR"

if [ ! -f "$KEY_DIR/ansible_ed25519" ]; then
  ssh-keygen -t ed25519 -f "$KEY_DIR/ansible_ed25519" -N "" -C "ansible@devops-tp2"
  echo "SSH key pair generated at $KEY_DIR/ansible_ed25519"
else
  echo "SSH key already exists at $KEY_DIR/ansible_ed25519"
fi

cp "$KEY_DIR/ansible_ed25519.pub" "$PUBKEY_DST"
echo "Public key copied to $PUBKEY_DST"
echo ""
echo "Next steps:"
echo "  cd docker && docker compose up -d --build"
