# 04 – Playbook Ansible & Rôles

## Structure du playbook

```
ansible/
├── ansible.cfg
├── site.yml                    # point d'entrée – cinq plays
└── roles/
    ├── nginx/                  # installe nginx + déploie la page HTML
    ├── timezone/               # gestion du fuseau horaire (Linux)
    ├── loadbalancer/           # reverse proxy nginx sur le port 8081
    └── windows_webserver/      # stub Windows (voir limitations)
```

## Plays dans `site.yml`

### Play 1 – Collecte de faits sur le contrôleur (localhost)

Affiche l'OS, le hostname et l'IPv4 du contrôleur Ansible.

### Play 2 – Serveurs web nginx

Installe nginx et déploie la page HTML personnalisée sur tous les hôtes `[webservers]`.
nginx sert la page sur le **port 80**.

### Play 3 – Gestion du fuseau horaire (Linux)

```yaml
- name: Gestion du fuseau horaire sur les nœuds Linux
  hosts: webservers
  become: true
  roles:
    - timezone
```

Le rôle `timezone` utilise la manipulation directe des fichiers `/etc/timezone` + `/etc/localtime`
(sans dépendance à `hwclock` ni `timedatectl`, non disponibles dans les conteneurs Docker) :

1. Écrit `Europe/Paris` dans `/etc/timezone`, crée le lien symbolique `/etc/localtime`
2. Lit `/etc/timezone` et vérifie que la valeur est bien `Europe/Paris`
3. Écrit `Africa/Abidjan` dans `/etc/timezone`, met à jour le lien symbolique
4. Lit `/etc/timezone` et vérifie que la valeur est bien `Africa/Abidjan`
5. Affiche le fuseau horaire final via `debug`

### Play 4 – Load balancer

Configure nginx en reverse proxy avec upstream `least_conn` sur tous les serveurs web.
Le load balancer écoute sur le **port 8081** pour coexister avec le serveur web sur le port 80
(les deux rôles tournent sur le même conteneur Docker dans cet environnement).

```
                   [port 8081]
  client ──► nginx lb ──► upstream { server 127.0.0.1:80; }
                                          ▼
                               nginx webserver [port 80]
                                   /var/www/html/index.html
```

### Play 5 – Nœud Windows (stub)

> **Limitation :** Il n'a pas été possible de provisionner une VM Windows réelle.
> Quatre approches ont été tentées (émulation UTM x86, ISO ARM64 via uupdump, VM Azure cloud)
> et ont toutes échoué pour des raisons matérielles ou de quota cloud.
> Le détail complet est disponible dans `docs/07-windows-vm-attempts.md`.
>
> Le workflow WinRM prévu est entièrement documenté dans
> `ansible/roles/windows_webserver/tasks/main.yml` et s'exécuterait sur un nœud Windows
> accessible avec les tâches suivantes :
> - `community.windows.win_timezone` → `Romance Standard Time` (Europe/Paris)
> - Vérification via `win_shell: (Get-TimeZone).Id`
> - `community.windows.win_timezone` → `GMT Standard Time` (Africa/Abidjan)

## Notes de conception

### Gestion des clés SSH

Les clés SSH sont stockées dans `~/.ansible-tp2/ansible_ed25519` (hors du workspace Git) afin
que les opérations `git clean` de `actions/checkout` entre les jobs CI ne les suppriment pas.
Le conteneur Docker est construit avec la clé publique intégrée dans `authorized_keys`.
Le job Docker et le job Ansible référencent le même chemin stable via `$HOME/.ansible-tp2/`.

### Conteneur Docker comme cible

La cible Ubuntu est un conteneur Docker (`ubuntu-target`) tournant sur la même machine que le
runner auto-hébergé. Correspondance des ports :

| Port hôte | Port conteneur | Usage |
|---|---|---|
| 2222 | 22 | SSH (Ansible) |
| 8080 | 80 | nginx webserver |
| 8081 | 8081 | nginx load balancer |

## Exécution en local

```bash
cd ansible
ansible-playbook -i inventory.ini site.yml

# Exclure le stub Windows
ansible-playbook -i inventory.ini site.yml --limit '!windows'

# Simulation (dry-run)
ansible-playbook -i inventory.ini site.yml --check
```
