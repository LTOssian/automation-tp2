# 07 – Windows VM Setup Attempts & Limitations

## Objective

The TP requires a Windows node managed via WinRM/WinRMS for remote timezone automation.
This document details every approach attempted and why each failed on this specific hardware.

---

## Hardware Context

| Property | Value |
|---|---|
| Machine | Apple Silicon Mac (ARM64 / M-series chip) |
| Free disk space | ~11 GB |
| Hypervisor used | UTM (QEMU-based) |

---

## Attempt 1 — x86 Windows Server 2022 ISO via UTM (Emulation)

### What we tried
Downloaded the official **Windows Server 2022 Evaluation ISO** (x86_64, French build):
```
26100.32230.260111-0550.lt_release_svc_refresh_SERVER_EVAL_x64FRE_fr-fr
```
Created a UTM VM and attempted to boot it.

### Why it failed
The Mac is **ARM64**. UTM can emulate x86 via QEMU TCG but:
- The emulated shell had **no working commands** — the x86 instruction translation was too broken to produce a usable environment
- Boot was partial: dropped into a non-functional CMD-like shell with no `ipconfig`, no `powershell`, nothing

**Root cause:** x86 emulation on Apple Silicon is not production-grade for Windows Server. The CPU instruction set mismatch makes the OS environment unreliable.

---

## Attempt 2 — Native ARM64 Windows Server ISO via uupdump.net

### What we tried
Downloaded an ARM64 build script from **uupdump.net**:
```
26100.8521_arm64_en-us_core_886b936b_convert
```
Attempted to build the ISO on macOS using the provided `uup_download_macos.sh` script.

### Why it failed
The script requires `chntpw`, which depends on `openssl@1.0`. This library **does not build on Apple Silicon**:

```
Error: openssl@1.0 build fails on Apple Silicon (Mac M4)
EC point validation errors during tests
make[1]: *** [test_ec] Error 1
```

This is a [known upstream issue](https://github.com/sidneys/homebrew-homebrew/issues/37) with no fix available.

### Workaround — Build ISO inside Docker
Since the macOS toolchain was broken, we used a Linux Docker container (ARM64 Ubuntu) which has working `chntpw` packages:

```bash
docker run --rm \
  -v "/Users/User11/Downloads/26100.8521_arm64_en-us_core_886b936b_convert:/uup" \
  ubuntu:22.04 bash -c "
    apt-get update -qq &&
    apt-get install -y cabextract wimtools chntpw genisoimage aria2 &&
    cd /uup && bash uup_download_linux.sh
  "
```

This **successfully built** the ISO:
```
26100.1_CORE_ARM64_EN-US.ISO  (3.9 GB)
```

---

## Attempt 3 — Boot ARM64 ISO in UTM

### What we tried
Created a new UTM VM (Virtualize mode, not Emulate) with:
- RAM: 2048 MB | CPU: 2 cores | Disk: 15 GB
- Network: Shared (NAT)
- ISO: `26100.1_CORE_ARM64_EN-US.ISO`

### Problem 1 — EFI Shell instead of installer
The VM dropped into the **UEFI Interactive Shell v2.2** instead of booting the installer.

**Fix:** Manually launched the bootloader from the EFI shell:
```
FS0:
EFI/BOOT/BOOTAA64.EFI
```

Then pressed a key immediately when prompted:
```
Press any key to boot from cd or dvd...
```

This successfully launched the Windows installer.

### Problem 2 — Insufficient disk space
During installation, Windows Server reported:

> **"Cannot be installed on this drive — requires 52 GB or more"**

The VM disk was 15 GB. Increasing it to 60 GB was not possible because the Mac only had **~11 GB of free space** remaining.

**Root cause:** Disk space exhausted — 11 GB free on host < 20 GB minimum required for Windows Server Core installation.

---

## Attempt 4 — Azure Cloud VM (Windows Server 2022 Datacenter)

### Context

After exhausting local options, we pivoted to **Azure for Students** (free credit, subscription `2e32bf2a-6410-4934-8182-fa5199a76f37`, tenant `efrei.net`) to provision a cloud-hosted Windows VM that Ansible could reach over WinRM from the self-hosted runner.

### Setup completed

- Azure CLI installed via `pip3 install azure-cli`
- Authenticated with `az login --allow-no-subscriptions` (required because the student subscription doesn't surface via standard login)
- Resource group `devops-tp2-rg` created successfully in `francecentral`

### Problem 1 — Standard_B1s capacity exhausted in francecentral

```
(SkuNotAvailable) The requested VM size for resource
'Following SKUs have failed for Capacity Restrictions: Standard_B1s'
is currently not available in location 'FranceCentral'.
```

`Standard_B2s` produced the same error. B-series is the only family with non-zero quota on Azure for Students, and Azure's physical capacity in `francecentral` was exhausted at time of attempt.

### Problem 2 — Region policy restricts deployment to francecentral only

Attempting other regions (`northeurope`, `eastus`, `westus2`, `westeurope`, `uksouth`, `australiaeast`, `japaneast`) produced:

```
(RequestDisallowedByAzure) Resource was disallowed by Azure:
This policy maintains a set of best available regions where your
subscription can deploy resources.
```

Only `francecentral`, `australiaeast`, and `southeastasia` accepted resource group creation. VM creation in `australiaeast` and `southeastasia` also returned `disallowed` for actual compute resources.

### Problem 3 — Quota = 0 for all non-B VM families

Testing other VM sizes in `francecentral`:

```
(QuotaExceeded) Current Limit: 0, Current Usage: 0, Additional Required: 2
```

All DSv2, DSv3, DSv4, DSv5, and other families have a hard quota of **0 vCores** on the Azure for Students subscription. Only the B-series had a quota above 0, but no physical capacity was available.

### Result

Azure VM provisioning is impossible on this subscription in any reachable region:

| Family | francecentral | australiaeast | southeastasia |
|---|---|---|---|
| Standard_B* | SkuNotAvailable (capacity) | Disallowed | Disallowed |
| Standard_DS* | QuotaExceeded (limit=0) | Disallowed | Disallowed |
| Standard_D*v3+ | QuotaExceeded (limit=0) | Disallowed | Disallowed |

This is a known constraint of Azure for Students free subscriptions — compute quota is minimal and capacity in European regions is heavily contested.

---

## Conclusion

| Attempt | Blocker |
|---|---|
| x86 ISO emulation on ARM | CPU architecture mismatch — unusable shell |
| macOS ISO build toolchain | `openssl@1.0` fails to compile on Apple Silicon |
| Docker-built ARM ISO | Success — ISO built correctly |
| ARM ISO boot in UTM | EFI workaround needed but worked |
| Windows installation | Host disk space exhausted (11 GB free vs 52 GB required) |

## What the Windows automation would have done

Had the VM been provisioned, the Ansible play would have:

1. Connected via **WinRM HTTP** (port 5985, NTLM auth)
2. Run `community.windows.win_timezone` to set `Romance Standard Time` (Europe/Paris)
3. Verified via `win_shell: (Get-TimeZone).Id`
4. Switched to `GMT Standard Time` (Africa/Abidjan)
5. Verified again

The full code is preserved in `ansible/roles/windows_webserver/tasks/main.yml`.

### WinRM setup commands (for reference)
```powershell
winrm quickconfig -q
winrm set winrm/config/service/auth '@{Basic="true"}'
winrm set winrm/config/service '@{AllowUnencrypted="true"}'
netsh advfirewall firewall add rule name="WinRM HTTP" protocol=TCP dir=in localport=5985 action=allow
```
