# 01 – Vue d'ensemble de l'infrastructure

## Architecture

```
                    ┌─────────────────────────────┐
                    │   Pipeline GitHub Actions    │
                    │   (runner auto-hébergé)      │
                    └────────────┬────────────────┘
                                 │
               ┌─────────────────▼──────────────────┐
               │         Contrôleur Ansible          │
               │  (machine du runner – exécute les   │
               │   playbooks)                        │
               └───────┬──────────────┬─────────────┘
                       │              │
          ┌────────────▼───┐   ┌──────▼───────────┐
          │  Load Balancer │   │  Serveur(s) Web   │
          │  nginx (LB)    │──▶│  nginx + HTML     │
          └────────────────┘   └──────────────────┘
```

## Composants

| Composant | Rôle |
|---|---|
| GitHub Actions | Orchestration CI/CD |
| Runner auto-hébergé | Exécute les jobs du pipeline en local |
| Terraform | Génère `ansible/inventory.ini` depuis un template |
| Contrôleur Ansible | Lance les playbooks sur les hôtes cibles |
| nginx (webservers) | Sert la page HTML statique |
| nginx (loadbalancer) | Distribue le trafic entre les serveurs web |

## Groupes d'hôtes (inventaire)

| Groupe | IP par défaut | Rôle |
|---|---|---|
| `webservers` | `127.0.0.1` | Cibles de déploiement nginx + HTML |
| `loadbalancer` | `127.0.0.1` | Reverse proxy nginx / upstream |

## Mise à l'échelle

Pour ajouter des serveurs web, renseigner la variable GitHub Actions `WEB_HOSTS` avec un tableau JSON :

```
["192.168.1.10", "192.168.1.11", "192.168.1.12"]
```

Terraform régénère l'inventaire et Ansible reconfigure automatiquement les serveurs web ainsi que le bloc upstream du load balancer.
