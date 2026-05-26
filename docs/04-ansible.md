# 04 – Ansible Playbook & Roles

## Playbook structure

```
ansible/
├── ansible.cfg
├── site.yml                    # entry-point – five plays
└── roles/
    ├── nginx/                  # installs nginx + deploys HTML page
    ├── timezone/               # timezone automation (Linux)
    ├── loadbalancer/           # nginx reverse proxy on port 8081
    └── windows_webserver/      # Windows stub (see limitations)
```

## Plays in `site.yml`

### Play 1 – Controller fact gathering (localhost)

Displays OS, hostname and IPv4 of the Ansible controller.

### Play 2 – nginx web servers

Installs nginx and deploys the custom HTML page on all `[webservers]` hosts.
nginx serves the page on **port 80**.

### Play 3 – Timezone management (Linux)

```yaml
- name: Timezone management on Linux nodes
  hosts: webservers
  become: true
  roles:
    - timezone
```

The `timezone` role uses direct `/etc/timezone` + `/etc/localtime` file manipulation
(no dependency on `hwclock` or `timedatectl`, which are unavailable inside Docker containers):

1. Writes `Europe/Paris` to `/etc/timezone`, symlinks `/etc/localtime`
2. Reads `/etc/timezone` and asserts it equals `Europe/Paris`
3. Writes `Africa/Abidjan` to `/etc/timezone`, symlinks `/etc/localtime`
4. Reads `/etc/timezone` and asserts it equals `Africa/Abidjan`
5. Displays final timezone via `debug`

### Play 4 – Load balancer

Configures nginx as a reverse proxy with `least_conn` upstream across all webservers.
The load balancer listens on **port 8081** to coexist with the webserver on port 80
(both roles run on the same Docker container in this environment).

```
                   [port 8081]
  client ──► nginx lb ──► upstream { server 127.0.0.1:80; }
                                          ▼
                               nginx webserver [port 80]
                                   /var/www/html/index.html
```

### Play 5 – Windows node (stubbed)

> **Limitation:** A real Windows VM could not be provisioned due to Apple Silicon (ARM64)
> incompatibility with the x86 Windows Server ISO, combined with insufficient disk space
> (~11 GB free vs ~20 GB required for Windows Server Core).
> Full details: `docs/07-windows-vm-attempts.md`
>
> The intended WinRM workflow is fully documented in
> `ansible/roles/windows_webserver/tasks/main.yml` and would execute on a reachable
> Windows node with the following tasks:
> - `community.windows.win_timezone` → `Romance Standard Time` (Europe/Paris)
> - Verify via `win_shell: (Get-TimeZone).Id`
> - `community.windows.win_timezone` → `GMT Standard Time` (Africa/Abidjan)

## Design notes

### SSH key management

SSH keys are stored at `~/.ansible-tp2/ansible_ed25519` (outside the Git workspace) so
that `actions/checkout` clean operations between CI jobs do not delete them. The Docker
container is built with the public key baked into `authorized_keys`. Both the Docker
build job and the Ansible job reference the same stable path via `$HOME/.ansible-tp2/`.

### Docker container as target

The Ubuntu target is a Docker container (`ubuntu-target`) running on the same machine as
the self-hosted runner. Port mapping:

| Host port | Container port | Purpose |
|---|---|---|
| 2222 | 22 | SSH (Ansible) |
| 8080 | 80 | nginx webserver |
| 8081 | 8081 | nginx load balancer |

## Running locally

```bash
cd ansible
ansible-playbook -i inventory.ini site.yml

# Skip Windows stub
ansible-playbook -i inventory.ini site.yml --limit '!windows'

# Dry-run
ansible-playbook -i inventory.ini site.yml --check
```
