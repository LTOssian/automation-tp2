# 04 – Ansible Playbook & Roles

## Playbook structure

```
ansible/
├── ansible.cfg
├── site.yml                    # entry-point – five plays
└── roles/
    ├── nginx/                  # installs nginx + deploys HTML page
    ├── timezone/               # timezone automation (Linux)
    ├── loadbalancer/           # nginx reverse proxy / upstream
    └── windows_webserver/      # Windows stub (see limitations)
```

## Plays in `site.yml`

### Play 1 – Controller fact gathering (localhost)

Displays OS, hostname and IPv4 of the Ansible controller.

### Play 2 – nginx web servers

Installs nginx and deploys the HTML page on all `[webservers]` hosts.

### Play 3 – Timezone management (Linux)

The core automation task (6 pts):

```yaml
- name: Timezone management on Linux nodes
  hosts: webservers
  become: true
  roles:
    - timezone
```

The `timezone` role:
1. Sets timezone to **Europe/Paris**
2. Verifies with `timedatectl` + `assert`
3. Switches to **Africa/Abidjan** (GMT)
4. Verifies again

### Play 4 – Load balancer

Configures nginx as a reverse proxy with `least_conn` upstream across all webservers.

### Play 5 – Windows node (stubbed)

> **Limitation:** A real Windows VM could not be provisioned due to Apple Silicon (ARM64)
> incompatibility with the x86 Windows Server ISO, combined with insufficient disk space
> (~11 GB free vs ~20 GB required for Windows Server Core).
>
> The intended workflow using WinRM is fully documented in
> `ansible/roles/windows_webserver/tasks/main.yml` and would execute on a reachable
> Windows node with the following Ansible tasks:
> - `community.windows.win_timezone` → set to `Romance Standard Time` (Europe/Paris)
> - Verify via `win_shell: (Get-TimeZone).Id`
> - `community.windows.win_timezone` → set to `GMT Standard Time` (Africa/Abidjan)

## Running locally

```bash
cd ansible
ansible-playbook -i inventory.ini site.yml

# Skip Windows stub
ansible-playbook -i inventory.ini site.yml --limit '!windows'

# Dry-run
ansible-playbook -i inventory.ini site.yml --check
```
