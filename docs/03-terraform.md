# 03 – Terraform & Génération Dynamique de l'Inventaire

## Objectif

Terraform remplace l'`inventory.ini` statique par un fichier **généré dynamiquement** à chaque exécution du pipeline, grâce à un template Jinja2-like (`inventory.tpl`).

## Fichiers

| Fichier | Rôle |
|---|---|
| `terraform/main.tf` | Déclare les variables et la ressource `local_file` |
| `terraform/inventory.tpl` | Template rendu en `ansible/inventory.ini` |
| `ansible/inventory.ini` | Fichier de sortie généré — **ne jamais versionner ce fichier** |

## Fonctionnement

`main.tf` utilise la fonction native Terraform `templatefile()` :

```hcl
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/inventory.tpl", {
    web_hosts  = var.web_hosts    # liste des IPs des serveurs web
    lb_host    = var.lb_host      # IP du load balancer
    user       = var.ansible_user
    connection = var.ansible_connection
  })
  filename = "${path.module}/../ansible/inventory.ini"
}
```

Le template (`inventory.tpl`) itère sur la liste `web_hosts` :

```
[webservers]
%{ for idx, h in web_hosts ~}
${h} ansible_user=${user} ansible_connection=${connection} server_id=${idx + 1}
%{ endfor ~}

[loadbalancer]
${lb_host} ansible_user=${user} ansible_connection=${connection}
```

## Variables

| Variable | Valeur par défaut | Surcharge via |
|---|---|---|
| `web_hosts` | `["127.0.0.1"]` | Variable GitHub Actions `WEB_HOSTS` (tableau JSON) |
| `lb_host` | `127.0.0.1` | Variable GitHub Actions `LB_HOST` |
| `ansible_user` | `ubuntu` | Variable GitHub Actions `ANSIBLE_USER` |
| `ansible_connection` | `local` | Variable GitHub Actions `ANSIBLE_CONNECTION` |

## Exécution en local

```bash
cd terraform
terraform init
terraform apply -auto-approve
cat ../ansible/inventory.ini   # inspecter le fichier généré
```
