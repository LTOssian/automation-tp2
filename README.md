# TP2 – Infrastructure DevOps & Automatisation avec Ansible et Terraform

**École :** EFREI | **Promotion :** M1-DEV1 2026 | **Cours :** DevOps – Culture, Pratiques et Outils  
**Professeur :** Issiaka KONE

---

## Présentation

Ce projet automatise le déploiement d'un **serveur web nginx** servant une page HTML statique,
via un pipeline entièrement automatisé :

```
GitHub Actions (runner auto-hébergé)
    ├── Job 1 – Terraform   →  génère ansible/inventory.ini depuis un template Jinja2-like
    ├── Job 2 – Docker      →  construit et démarre le conteneur Ubuntu cible
    └── Job 3 – Ansible     →  installe nginx & déploie la page HTML sur les hôtes cibles
```

---

## Documentation

La documentation complète est disponible dans le dossier [`docs/`](docs/README.md) :

| Section | Fichier |
|---|---|
| Vue d'ensemble de l'architecture | [docs/01-infrastructure.md](docs/01-infrastructure.md) |
| Runner auto-hébergé | [docs/02-runner-setup.md](docs/02-runner-setup.md) |
| Terraform & inventaire dynamique | [docs/03-terraform.md](docs/03-terraform.md) |
| Playbook Ansible & rôles | [docs/04-ansible.md](docs/04-ansible.md) |
| Load balancer nginx | [docs/05-load-balancing.md](docs/05-load-balancing.md) |
| Pipeline CI/CD | [docs/06-pipeline.md](docs/06-pipeline.md) |
| Tentatives VM Windows | [docs/07-windows-vm-attempts.md](docs/07-windows-vm-attempts.md) |

---

## Structure du dépôt

```
TP2/
├── .github/workflows/deploy.yml  # Pipeline GitHub Actions (3 jobs)
├── terraform/
│   ├── main.tf                   # Config Terraform – génère l'inventaire via templatefile()
│   └── inventory.tpl             # Template Jinja2-like pour l'inventaire Ansible
├── docker/
│   ├── docker-compose.yml        # Conteneur ubuntu-target (SSH + nginx)
│   ├── gen-keys.sh               # Génère la paire de clés SSH ED25519
│   └── ubuntu-target/            # Dockerfile + authorized_keys
├── ansible/
│   ├── ansible.cfg               # Configuration Ansible du projet
│   ├── site.yml                  # Playbook principal (5 plays)
│   └── roles/
│       ├── nginx/                # Installe nginx + déploie la page HTML
│       ├── timezone/             # Gestion du fuseau horaire (Linux, compatible Docker)
│       ├── loadbalancer/         # Reverse proxy nginx sur le port 8081
│       └── windows_webserver/    # Rôle Windows (stub documenté)
├── docs/                         # Documentation complète du TP
└── screenshots/                  # Captures d'écran du pipeline
```

---

## Architecture

| Composant | Technologie | Rôle |
|---|---|---|
| CI/CD | GitHub Actions | Orchestre les jobs du pipeline |
| Runner | Runner auto-hébergé (local) | Exécuteur exclusif du pipeline |
| IaC | Terraform + `templatefile()` | Génère `ansible/inventory.ini` |
| Gestion de config | Ansible | Installe nginx, déploie le HTML, gère le fuseau horaire |
| Serveur web | nginx (Docker) | Sert la page HTML statique (port 8080) |
| Load balancer | nginx (Docker) | Distribue le trafic (port 8081) |

---

## Exécution en local

### 1. Générer l'inventaire avec Terraform

```bash
cd terraform
terraform init
terraform apply -auto-approve
```

### 2. Démarrer le conteneur cible

```bash
cd docker
bash gen-keys.sh
docker compose up -d --build
```

### 3. Lancer le playbook Ansible

```bash
cd ansible
ansible-playbook -i inventory.ini site.yml
```

### 4. Vérifier

```bash
curl http://127.0.0.1:8080        # page nginx
curl http://127.0.0.1:8081/health # load balancer → OK
```

---

## Prérequis

- Runner GitHub Actions auto-hébergé enregistré sur ce dépôt
- Terraform ≥ 1.0 installé sur la machine du runner
- Ansible ≥ 2.12 installé sur la machine du runner
- Docker + Docker Compose installés sur la machine du runner
