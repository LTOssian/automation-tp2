# 02 – Configuration du Runner Auto-Hébergé GitHub Actions

## Pourquoi un runner auto-hébergé ?

Un runner auto-hébergé garantit que le pipeline s'exécute sur **votre propre machine** (ou VM), ce qui permet de :
- Contrôler l'environnement (outils, réseau, accès sudo)
- Prouver que le pipeline ne tourne pas sur l'infrastructure partagée de GitHub

## Étapes d'enregistrement

### 1. Accéder aux paramètres du runner

`https://github.com/LTOssian/automation-tp2` → **Settings → Actions → Runners → New self-hosted runner**

### 2. Téléchargement et configuration

```bash
mkdir ~/actions-runner && cd ~/actions-runner
# Télécharger (utiliser l'URL exacte affichée sur GitHub – inclut l'OS/architecture)
curl -o actions-runner.tar.gz -L <URL_DEPUIS_GITHUB>
tar xzf actions-runner.tar.gz

# Enregistrer (le token est affiché sur GitHub – valide 1h)
./config.sh \
  --url https://github.com/LTOssian/automation-tp2 \
  --token <TOKEN_DEPUIS_GITHUB>
```

### 3. Démarrer le runner

```bash
# Temporaire / test
./run.sh

# Persistant – service systemd (recommandé)
sudo ./svc.sh install
sudo ./svc.sh start
sudo ./svc.sh status
```

### 4. Vérification

**Settings → Actions → Runners** → le runner apparaît avec le statut **Idle** (point vert).

## Utilisation dans le pipeline

Dans `.github/workflows/deploy.yml`, chaque job déclare :

```yaml
runs-on: self-hosted
```

Cela garantit que GitHub ne basculera jamais sur un runner partagé hébergé.

## Prérequis sur la machine du runner

| Outil | Commande d'installation |
|---|---|
| Ansible | `sudo apt install ansible` |
| Terraform | Voir [terraform.io/install](https://developer.hashicorp.com/terraform/install) |
| sudo | Requis pour `become: true` dans les playbooks |
