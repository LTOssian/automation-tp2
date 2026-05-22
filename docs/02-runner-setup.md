# 02 – GitHub Actions Self-Hosted Runner Setup

## Why a self-hosted runner?

A self-hosted runner ensures the pipeline executes on **your own machine** (or VM), giving you:
- Control over the environment (tools, network, sudo access)
- Proof that the pipeline did not run on GitHub's shared infrastructure

## Registration Steps

### 1. Navigate to runner settings

`https://github.com/LTOssian/automation-tp2` → **Settings → Actions → Runners → New self-hosted runner**

### 2. Download & configure

```bash
mkdir ~/actions-runner && cd ~/actions-runner
# Download (use the exact URL shown on GitHub – it includes your OS/arch)
curl -o actions-runner.tar.gz -L <URL_FROM_GITHUB>
tar xzf actions-runner.tar.gz

# Register (token is shown on GitHub – valid 1h)
./config.sh \
  --url https://github.com/LTOssian/automation-tp2 \
  --token <TOKEN_FROM_GITHUB>
```

### 3. Start the runner

```bash
# Temporary / testing
./run.sh

# Persistent – systemd service (recommended)
sudo ./svc.sh install
sudo ./svc.sh start
sudo ./svc.sh status
```

### 4. Verify

**Settings → Actions → Runners** → runner appears as **Idle** (green dot).

## How the pipeline uses it

In `.github/workflows/deploy.yml` every job declares:

```yaml
runs-on: self-hosted
```

This ensures GitHub will never fall back to a shared hosted runner.

## Prerequisites on the runner machine

| Tool | Install command |
|---|---|
| Ansible | `sudo apt install ansible` |
| Terraform | See [terraform.io/install](https://developer.hashicorp.com/terraform/install) |
| sudo | Required for `become: true` in playbooks |
