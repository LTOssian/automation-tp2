# 04 – Ansible Playbook & Roles

## Playbook structure

```
ansible/
├── ansible.cfg         # project-level config (inventory, roles_path, become)
├── site.yml            # entry-point – three plays
└── roles/
    ├── nginx/          # web server role
    │   ├── tasks/main.yml
    │   ├── handlers/main.yml
    │   └── files/index.html
    └── loadbalancer/   # LB role
        ├── tasks/main.yml
        ├── handlers/main.yml
        └── templates/lb.conf.j2
```

## Plays in `site.yml`

### Play 1 – Controller fact gathering (localhost)

```yaml
- name: Gather facts on Ansible Controller
  hosts: localhost
  connection: local
  gather_facts: true
```

Displays OS, hostname and IPv4 of the machine running Ansible.

### Play 2 – nginx web servers

```yaml
- name: Deploy nginx + HTML page on web servers
  hosts: webservers
  become: true
  roles:
    - nginx
```

The `nginx` role:
1. Installs the `nginx` package
2. Copies `files/index.html` to `/var/www/html/index.html`
3. Ensures nginx is started and enabled

### Play 3 – Load balancer

```yaml
- name: Configure nginx load balancer
  hosts: loadbalancer
  become: true
  roles:
    - loadbalancer
```

The `loadbalancer` role:
1. Installs nginx
2. Renders `lb.conf.j2` (upstream block auto-populated from `groups['webservers']`)
3. Enables the site and removes the default site

## Running locally

```bash
cd ansible
ansible-playbook -i inventory.ini site.yml

# Dry-run (no changes applied)
ansible-playbook -i inventory.ini site.yml --check
```
