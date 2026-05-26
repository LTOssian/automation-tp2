# 06 – Déroulement du Pipeline CI/CD

## Déclencheur

Tout push sur la branche `main` déclenche automatiquement le pipeline.

## Vue d'ensemble du pipeline

```
push sur main
    │
    ├──────────────────────────────────────────┐
    │  Job 1 : terraform (runner auto-hébergé) │
    │  1. checkout                             │
    │  2. setup terraform                      │
    │  3. terraform init                       │
    │  4. terraform validate                   │
    │  5. terraform apply  →  inventory.ini    │
    └──────────────────────────────────────────┘
    │
    ├──────────────────────────────────────────┐
    │  Job 2 : docker (runner auto-hébergé)    │
    │  1. checkout                             │
    │  2. gen-keys.sh  →  ~/.ansible-tp2/      │
    │  3. docker compose up -d --build         │
    │  4. attente SSH (15 tentatives × 3s)     │
    └──────────────────────────────────────────┘
    │ needs: [terraform, docker]
    ▼
┌──────────────────────────────────────────────┐
│  Job 3 : ansible (runner auto-hébergé)       │
│  1. checkout                                 │
│  2. gen-keys.sh  (clé déjà présente → skip)  │
│  3. écriture inventory.ini (heredoc shell)   │
│     ansible_ssh_private_key_file=            │
│       ~/.ansible-tp2/ansible_ed25519         │
│  4. vérification pip / ansible --version     │
│  5. ssh-keygen -R '[127.0.0.1]:2222'         │
│  6. ansible-playbook site.yml                │
│     ├── play 1 : collecte de faits (localhost)│
│     ├── play 2 : déploiement nginx + HTML    │
│     ├── play 3 : fuseau horaire Paris→Abidjan│
│     ├── play 4 : configuration load balancer │
│     └── play 5 : stub Windows (injoignable)  │
└──────────────────────────────────────────────┘
```

## Décisions clés du pipeline

| Décision | Raison |
|---|---|
| `runs-on: self-hosted` | Garantit l'exécution sur le runner local, jamais sur un runner partagé |
| Clé SSH dans `~/.ansible-tp2/` | Survit aux opérations `git clean` entre les jobs (les fichiers gitignorés sont supprimés par checkout) |
| Inventaire écrit via heredoc | Pas de transfert d'artefact ; `$HOME` s'étend correctement dans le chemin de la clé |
| `ssh-keygen -R '[127.0.0.1]:2222'` | Efface l'entrée known_hosts obsolète quand le conteneur est reconstruit |
| `needs: [terraform, docker]` | Impose l'exécution séquentielle (conteneur prêt avant Ansible) |
| `ignore_unreachable: true` sur le play Windows | Permet au pipeline de réussir même si la VM Windows n'est pas provisionnée |

## Résolution des problèmes

### `Permission denied (publickey)` sur la connexion SSH Ansible

La clé privée SSH `~/.ansible-tp2/ansible_ed25519` doit :
1. Appartenir à l'utilisateur runner (`User11`), pas à `root`
2. Correspondre à la clé publique intégrée dans l'image Docker (`docker/ubuntu-target/authorized_keys`)

Si la propriété est incorrecte : `sudo chown -R User11:staff ~/.ansible-tp2`

Si la clé a changé (nouvelle clé, ancien conteneur) : relancer `docker/gen-keys.sh` puis
`docker compose up -d --build` dans le répertoire `docker/`.

### Le runner perd la communication avec le serveur

Il s'agit d'un problème réseau transitoire lors du nettoyage post-job de GitHub Actions. Relancer
le job depuis l'interface Actions (`Re-run failed jobs`). Le playbook lui-même s'exécute correctement.

## Preuve d'exécution sur le runner local

Dans l'interface GitHub Actions, l'en-tête du log de chaque job affiche le nom du runner.
Il doit indiquer le nom du runner auto-hébergé (ex. `self-hosted`) — et non un runner hébergé par GitHub.
