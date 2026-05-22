# 06 – CI/CD Pipeline Walkthrough

## Trigger

Any push to the `main` branch triggers the pipeline automatically.

## Pipeline overview

```
push to main
    │
    ▼
┌──────────────────────────────────────────┐
│  Job: terraform (self-hosted runner)     │
│  1. checkout                             │
│  2. setup terraform                      │
│  3. terraform init                       │
│  4. terraform validate                   │
│  5. terraform apply  →  inventory.ini    │
│  6. upload artifact (inventory.ini)      │
└──────────────────┬───────────────────────┘
                   │ needs: terraform
    ▼
┌──────────────────────────────────────────┐
│  Job: ansible (self-hosted runner)       │
│  1. checkout                             │
│  2. download artifact (inventory.ini)    │
│  3. ensure ansible is installed          │
│  4. ansible-playbook site.yml            │
│     ├── play: gather facts (localhost)   │
│     ├── play: deploy nginx + HTML        │
│     └── play: configure load balancer   │
└──────────────────────────────────────────┘
```

## Key pipeline decisions

| Decision | Reason |
|---|---|
| `runs-on: self-hosted` | Guarantees execution on your local runner, never shared |
| Artifact upload/download | Passes `inventory.ini` between jobs without committing it |
| `needs: terraform` | Enforces sequential execution (inventory must exist before Ansible runs) |
| Ansible installed in-job | Handles runners where Ansible isn't pre-installed |

## Proof of local runner execution

In the GitHub Actions UI, each job log header shows:

```
Runner: <your-runner-name>  ← must NOT say "GitHub Actions" hosted runner
```

Take a screenshot of this header as pipeline proof for submission.

## GitHub Actions variables to set

Navigate to **Settings → Secrets and variables → Actions → Variables**:

| Name | Example value | Description |
|---|---|---|
| `WEB_HOSTS` | `["192.168.1.10","192.168.1.11"]` | Web server IPs |
| `LB_HOST` | `192.168.1.5` | Load balancer IP |
| `ANSIBLE_USER` | `ubuntu` | SSH user |
| `ANSIBLE_CONNECTION` | `ssh` | `ssh` for remote, `local` for localhost |
