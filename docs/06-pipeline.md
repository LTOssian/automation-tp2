# 06 – CI/CD Pipeline Walkthrough

## Trigger

Any push to the `main` branch triggers the pipeline automatically.

## Pipeline overview

```
push to main
    │
    ├──────────────────────────────────────────┐
    │  Job 1: terraform (self-hosted runner)   │
    │  1. checkout                             │
    │  2. setup terraform                      │
    │  3. terraform init                       │
    │  4. terraform validate                   │
    │  5. terraform apply  →  inventory.ini    │
    └──────────────────────────────────────────┘
    │
    ├──────────────────────────────────────────┐
    │  Job 2: docker (self-hosted runner)      │
    │  1. checkout                             │
    │  2. gen-keys.sh  →  ~/.ansible-tp2/      │
    │  3. docker compose up -d --build         │
    │  4. wait for SSH (15 retries × 3s)       │
    └──────────────────────────────────────────┘
    │ needs: [terraform, docker]
    ▼
┌──────────────────────────────────────────────┐
│  Job 3: ansible (self-hosted runner)         │
│  1. checkout                                 │
│  2. gen-keys.sh  (key already exists → skip) │
│  3. write inventory.ini (shell heredoc)      │
│     ansible_ssh_private_key_file=            │
│       ~/.ansible-tp2/ansible_ed25519         │
│  4. pip check / ansible --version            │
│  5. ssh-keygen -R '[127.0.0.1]:2222'         │
│  6. ansible-playbook site.yml                │
│     ├── play 1: gather facts (localhost)     │
│     ├── play 2: deploy nginx + HTML          │
│     ├── play 3: timezone Europe/Paris→Abidjan│
│     ├── play 4: configure load balancer      │
│     └── play 5: windows stub (unreachable)   │
└──────────────────────────────────────────────┘
```

## Key pipeline decisions

| Decision | Reason |
|---|---|
| `runs-on: self-hosted` | Guarantees execution on your local runner, never shared |
| SSH key at `~/.ansible-tp2/` | Survives `git clean` between jobs (gitignored files deleted by checkout) |
| Inventory written via heredoc | No artifact handoff; `$HOME` expands the key path reliably |
| `ssh-keygen -R '[127.0.0.1]:2222'` | Clears stale known_hosts entry when container is rebuilt |
| `needs: [terraform, docker]` | Enforces sequential execution (container ready before Ansible) |
| `ignore_unreachable: true` on Windows play | Allows pipeline to pass even though Windows VM is not provisioned |

## Troubleshooting

### `Permission denied (publickey)` on Ansible SSH

The SSH private key at `~/.ansible-tp2/ansible_ed25519` must:
1. Be owned by the runner user (`User11`), not `root`
2. Match the public key baked into the Docker image (`docker/ubuntu-target/authorized_keys`)

If the key ownership is wrong: `sudo chown -R User11:staff ~/.ansible-tp2`

If the key has rotated (new key, old container): re-run `docker/gen-keys.sh` then
`docker compose up -d --build` in the `docker/` directory.

### Runner lost communication with server

This is a transient network glitch during GitHub Actions post-cleanup. Re-run the failed
job from the Actions UI (`Re-run failed jobs`). The playbook itself succeeds.

## Proof of local runner execution

In the GitHub Actions UI, each job log header shows the runner name. It must display your
self-hosted runner name (e.g., `self-hosted`) — not a GitHub-hosted runner.
