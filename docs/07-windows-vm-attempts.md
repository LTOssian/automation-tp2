# 07 – Tentatives de Provisionnement de la VM Windows

## Objectif

Le TP requiert un nœud Windows géré via WinRM pour l'automatisation du fuseau horaire.
Ce document détaille chaque approche tentée et les raisons de l'échec sur ce matériel spécifique.

---

## Contexte matériel

| Propriété | Valeur |
|---|---|
| Machine | Apple Silicon Mac (ARM64 / puce M-series) |
| Espace disque libre | ~11 Go |
| Hyperviseur utilisé | UTM (basé sur QEMU) |

---

## Tentative 1 — ISO Windows Server 2022 x86 via UTM (émulation)

### Ce qui a été tenté
Téléchargement de l'**ISO officielle Windows Server 2022 Evaluation** (x86_64, build française) :
```
26100.32230.260111-0550.lt_release_svc_refresh_SERVER_EVAL_x64FRE_fr-fr
```
Création d'une VM UTM et tentative de démarrage.

### Raison de l'échec
Le Mac est **ARM64**. UTM peut émuler x86 via QEMU TCG, mais :
- Le shell émulé n'avait **aucune commande fonctionnelle** — la traduction des instructions x86 était trop instable pour produire un environnement utilisable
- Le démarrage était partiel : la VM tombait dans un shell CMD non fonctionnel, sans `ipconfig` ni `powershell`

**Cause racine :** L'émulation x86 sur Apple Silicon n'est pas adaptée à Windows Server. L'incompatibilité entre les jeux d'instructions rend l'OS inutilisable.

---

## Tentative 2 — ISO Windows Server ARM64 native via uupdump.net

### Ce qui a été tenté
Téléchargement d'un script de build ARM64 depuis **uupdump.net** :
```
26100.8521_arm64_en-us_core_886b936b_convert
```
Tentative de construction de l'ISO sur macOS avec le script `uup_download_macos.sh` fourni.

### Raison de l'échec
Le script nécessite `chntpw`, qui dépend de `openssl@1.0`. Cette bibliothèque **ne compile pas sur Apple Silicon** :

```
Error: openssl@1.0 build fails on Apple Silicon (Mac M4)
EC point validation errors during tests
make[1]: *** [test_ec] Error 1
```

Il s'agit d'un [problème connu en amont](https://github.com/sidneys/homebrew-homebrew/issues/37) sans correctif disponible.

### Contournement — Construction de l'ISO dans Docker
La chaîne d'outils macOS étant cassée, un conteneur Docker Linux (ARM64 Ubuntu) a été utilisé, qui dispose de packages `chntpw` fonctionnels :

```bash
docker run --rm \
  -v "/Users/User11/Downloads/26100.8521_arm64_en-us_core_886b936b_convert:/uup" \
  ubuntu:22.04 bash -c "
    apt-get update -qq &&
    apt-get install -y cabextract wimtools chntpw genisoimage aria2 &&
    cd /uup && bash uup_download_linux.sh
  "
```

L'ISO a été **construite avec succès** :
```
26100.1_CORE_ARM64_EN-US.ISO  (3,9 Go)
```

---

## Tentative 3 — Démarrage de l'ISO ARM64 dans UTM

### Ce qui a été tenté
Création d'une nouvelle VM UTM (mode Virtualiser, pas Émuler) avec :
- RAM : 2048 Mo | CPU : 2 cœurs | Disque : 15 Go
- Réseau : Partagé (NAT)
- ISO : `26100.1_CORE_ARM64_EN-US.ISO`

### Problème 1 — Shell EFI au lieu de l'installeur
La VM démarrait dans le **Shell Interactif UEFI v2.2** au lieu de lancer l'installeur.

**Correctif :** Lancement manuel du bootloader depuis le shell EFI :
```
FS0:
EFI/BOOT/BOOTAA64.EFI
```

Puis appui rapide sur une touche au message :
```
Press any key to boot from cd or dvd...
```

L'installeur Windows a ensuite démarré correctement.

### Problème 2 — Espace disque insuffisant
Pendant l'installation, Windows Server a signalé :

> **« Impossible d'installer sur ce lecteur — nécessite 52 Go ou plus »**

Le disque VM était de 15 Go. L'augmenter à 60 Go était impossible car le Mac ne disposait que de **~11 Go d'espace libre**.

**Cause racine :** Espace disque épuisé — 11 Go libres sur l'hôte < 20 Go minimum requis pour l'installation de Windows Server Core.

---

## Tentative 4 — VM Azure Cloud (Windows Server 2022 Datacenter)

### Contexte

Après avoir épuisé les options locales, nous nous sommes tournés vers **Azure for Students** (crédit gratuit, abonnement `2e32bf2a-6410-4934-8182-fa5199a76f37`, tenant `efrei.net`) pour provisionner une VM Windows cloud qu'Ansible pourrait atteindre via WinRM depuis le runner auto-hébergé.

### Configuration réalisée

- Azure CLI installé via `pip3 install azure-cli`
- Authentification avec `az login --allow-no-subscriptions` (requis car l'abonnement étudiant n'apparaît pas lors du login standard)
- Groupe de ressources `devops-tp2-rg` créé avec succès dans `francecentral`

### Problème 1 — Capacité Standard_B1s épuisée dans francecentral

```
(SkuNotAvailable) The requested VM size for resource
'Following SKUs have failed for Capacity Restrictions: Standard_B1s'
is currently not available in location 'FranceCentral'.
```

`Standard_B2s` produisait la même erreur. La série B est la seule famille avec un quota non nul sur Azure for Students, et la capacité physique Azure dans `francecentral` était épuisée au moment de la tentative.

### Problème 2 — La politique Azure restreint le déploiement à francecentral

Tentatives dans d'autres régions (`northeurope`, `eastus`, `westus2`, `westeurope`, `uksouth`, `australiaeast`, `japaneast`) :

```
(RequestDisallowedByAzure) Resource was disallowed by Azure:
This policy maintains a set of best available regions where your
subscription can deploy resources.
```

Seules `francecentral`, `australiaeast` et `southeastasia` acceptaient la création de groupes de ressources. La création de VM dans `australiaeast` et `southeastasia` retournait également `disallowed` pour les ressources compute.

### Problème 3 — Quota = 0 pour toutes les familles non-B

Test d'autres tailles de VM dans `francecentral` :

```
(QuotaExceeded) Current Limit: 0, Current Usage: 0, Additional Required: 2
```

Toutes les familles DSv2, DSv3, DSv4, DSv5 et autres ont un quota fixe de **0 vCores** sur l'abonnement Azure for Students. Seule la série B disposait d'un quota supérieur à 0, mais aucune capacité physique n'était disponible.

### Résultat

Le provisionnement d'une VM Azure est impossible sur cet abonnement dans toute région accessible :

| Famille | francecentral | australiaeast | southeastasia |
|---|---|---|---|
| Standard_B* | SkuNotAvailable (capacité) | Interdit | Interdit |
| Standard_DS* | QuotaExceeded (limite=0) | Interdit | Interdit |
| Standard_D*v3+ | QuotaExceeded (limite=0) | Interdit | Interdit |

Il s'agit d'une contrainte connue des abonnements gratuits Azure for Students — le quota compute est minimal et la capacité dans les régions européennes est fortement sollicitée.

---

## Conclusion

| Tentative | Bloquant |
|---|---|
| Émulation x86 ISO sur ARM | Incompatibilité CPU — shell inutilisable |
| Chaîne d'outils ISO macOS | `openssl@1.0` ne compile pas sur Apple Silicon |
| ISO ARM construite via Docker | Succès — ISO construite correctement |
| Démarrage ISO ARM dans UTM | Contournement EFI nécessaire mais fonctionnel |
| Installation Windows | Espace disque épuisé (11 Go libres vs 52 Go requis) |
| VM Azure cloud | Quota 0 vCores + capacité B-series épuisée dans toutes les régions accessibles |

## Ce qu'aurait fait l'automatisation Windows

Si la VM avait été provisionnée, le play Ansible aurait :

1. Connecté via **WinRM HTTP** (port 5985, authentification NTLM)
2. Exécuté `community.windows.win_timezone` pour définir `Romance Standard Time` (Europe/Paris)
3. Vérifié via `win_shell: (Get-TimeZone).Id`
4. Basculé sur `GMT Standard Time` (Africa/Abidjan)
5. Vérifié à nouveau

Le code complet est conservé dans `ansible/roles/windows_webserver/tasks/main.yml`.

### Commandes WinRM de configuration (pour référence)
```powershell
winrm quickconfig -q
winrm set winrm/config/service/auth '@{Basic="true"}'
winrm set winrm/config/service '@{AllowUnencrypted="true"}'
netsh advfirewall firewall add rule name="WinRM HTTP" protocol=TCP dir=in localport=5985 action=allow
```
