# 05 – Répartition de Charge avec nginx

## Vue d'ensemble

nginx joue à la fois le rôle de **serveur web** (sur les hôtes `webservers`) et de **reverse proxy / load balancer** (sur l'hôte `loadbalancer`).

```
Client → :8081 (LB) → upstream { web1:80, web2:80, ... }
```

> **Note :** Dans cet environnement Docker, le LB écoute sur le port 8081 (et non 80)
> pour coexister avec le serveur web sur le même conteneur.

## Algorithme

`least_conn` — chaque nouvelle requête est transmise au backend ayant le moins de connexions actives. C'est plus adaptatif que le round-robin lorsque les requêtes ont des durées variables.

## Configuration upstream générée (`lb.conf.j2`)

```nginx
upstream backend {
    least_conn;
    server 192.168.1.10:80;   # serveur web 1
    server 192.168.1.11:80;   # serveur web 2
    # ... auto-généré par Ansible depuis groups['webservers']
}

server {
    listen 8081;

    location / {
        proxy_pass         http://backend;
        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_connect_timeout 5s;
        proxy_read_timeout    30s;
    }

    location /health {
        return 200 "OK\n";   # endpoint de vérification de santé
    }
}
```

La liste des serveurs upstream est **rendue dynamiquement** par Ansible — aucune édition manuelle n'est nécessaire lors de l'ajout ou de la suppression de nœuds.

## Ajouter un nouveau serveur web

1. Ajouter son IP dans la variable GitHub Actions `WEB_HOSTS` (tableau JSON).
2. Pousser un commit sur `main`.
3. Terraform régénère l'inventaire → Ansible installe nginx sur le nouveau nœud **et** met à jour automatiquement le bloc upstream du LB.

## Vérification de santé

```bash
curl http://127.0.0.1:8081/health
# → OK
```

## Tester la distribution de charge

```bash
for i in $(seq 1 10); do curl -s http://127.0.0.1:8081/ | grep -o 'Server [0-9]*'; done
```

Les requêtes doivent être réparties entre les nœuds backend.
