# TP2 – DevOps Infrastructure & Automation with Ansible & Terraform

**School:** EFREI | **Class:** M1-DEV1 2026 | **Course:** DevOps – Culture, Practices and Tools

---

## Overview

This project automates the deployment of an **nginx web server** serving a static HTML page,
using a fully automated pipeline:

```
GitLab CI/CD (custom runner)
    ├── Stage 1 – Terraform   →  generates Ansible inventory.ini from a Jinja2-like template
    └── Stage 2 – Ansible     →  installs nginx & deploys the HTML page on target hosts
```

---

## Repository Structure

```
TP2/
├── .gitlab-ci.yml              # CI/CD pipeline definition
├── terraform/
│   ├── main.tf                 # Terraform config – generates inventory via templatefile()
│   └── inventory.tpl           # Jinja2-style template for Ansible inventory
├── ansible/
│   ├── ansible.cfg             # Project-level Ansible configuration
│   ├── site.yml                # Main playbook (facts + nginx deployment)
│   └── roles/
│       └── nginx/
│           ├── tasks/main.yml  # Install & configure nginx
│           ├── handlers/main.yml
│           └── files/index.html # Static HTML page served by nginx
└── screenshots/                # Pipeline proof screenshots (see Delivery section)
```

---

## Architecture

| Component | Technology | Role |
|---|---|---|
| CI/CD Engine | GitLab CI/CD | Orchestrates pipeline stages |
| Custom Runner | GitLab Runner (local) | Exclusive pipeline executor |
| IaC | Terraform + `templatefile()` | Generates `ansible/inventory.ini` |
| Configuration Mgmt | Ansible | Installs nginx, deploys HTML |
| Web Server | nginx | Serves the static HTML page |

---

## Prerequisites

- GitLab Runner registered and tagged `custom-local-runner`
- Terraform ≥ 1.0 installed on the runner
- Ansible ≥ 2.12 installed on the runner
- Target host accessible via SSH (or `local` connection for localhost)

---

## How to Run Locally

### 1. Generate the inventory with Terraform

```bash
cd terraform
terraform init
terraform apply -auto-approve
```

This creates `ansible/inventory.ini` from `inventory.tpl`.

### 2. Run the Ansible playbook

```bash
cd ansible
ansible-playbook -i inventory.ini site.yml
```

### 3. Verify

Open `http://<target-host>` in your browser – you should see the TP2 landing page.

---

## Pipeline Execution

Push to `main` triggers the pipeline automatically:

```
push → GitLab → custom-local-runner
                    ├── terraform job  (init → validate → apply)
                    └── ansible job    (ansible-playbook site.yml)
```

> **Note:** The `tags: [custom-local-runner]` directive in `.gitlab-ci.yml` ensures the pipeline
> runs **only** on the local custom runner, never on shared GitLab-hosted runners.

---

## Customisation

| Variable | Default | Description |
|---|---|---|
| `TF_VAR_ansible_host` | `127.0.0.1` | Target host IP/hostname |
| `TF_VAR_ansible_user` | `ubuntu` | SSH user |
| `TF_VAR_ansible_connection` | `local` | Ansible connection type |

Set these as GitLab CI/CD variables in **Settings → CI/CD → Variables**.
