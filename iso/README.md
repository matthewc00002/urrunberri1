# UrrunBerri OS — ISO Installer

**Openema SARL — Mathieu Cadi**

Deux methodes pour creer une ISO d'installation UrrunBerri OS sur Debian 13 Trixie.

## Option 1 — ISO Online (Netinst remastered)

Prend l'ISO netinst Debian standard et injecte la configuration UrrunBerri.
Petite (~400 Mo), mais necessite Internet pendant l'installation.

```bash
sudo bash iso/build-netinst-iso.sh
```

**Resultat :** `/tmp/urrunberri-iso-build/urrunberri-os-netinst.iso`

## Option 2 — ISO Offline (simple-cdd)

Cree une ISO complete avec tous les paquets pre-inclus.
Plus grosse (~800 Mo), mais aucun Internet requis sur la machine cible.

```bash
sudo bash iso/build-offline-iso.sh
```

**Resultat :** `/tmp/urrunberri-offline-build/urrunberri-os-offline.iso`

## Ce que l'ISO demande

L'installeur pose les questions essentielles — aucune valeur par defaut n'est imposee :

| Question | Pre-rempli |
|----------|-----------|
| Langue | Non |
| Hostname | Non |
| Domaine | Non |
| Adresse IP | Non |
| Masque de sous-reseau | Non |
| Passerelle | Non |
| Serveur DNS | Non |
| Mot de passe root | Non |

Tout le reste est automatique : partitionnement (disque entier), paquets, configuration systeme, installation UrrunBerri OS.

## Ce qui est automatise

- Clavier AZERTY francais
- Fuseau horaire Europe/Paris
- Partitionnement automatique (disque entier)
- Compte utilisateur matt (mot de passe: openema)
- Installation de curl, ca-certificates, openssh-server, sudo
- SSH avec PermitRootLogin active
- Installation UrrunBerri OS au premier demarrage (Option 1) ou pendant l'install (Option 2)

## Graver sur USB

```bash
sudo dd if=urrunberri-os-*.iso of=/dev/sdX bs=4M status=progress
```

Remplacer `/dev/sdX` par le bon peripherique (verifier avec `lsblk`).

## Construction

Les scripts doivent etre executes en root sur une machine Debian.
Espace disque temporaire necessaire : ~2 Go.

## Fichiers

| Fichier | Description |
|---------|-------------|
| `iso/preseed.cfg` | Configuration preseed Debian |
| `iso/build-netinst-iso.sh` | Script de construction Option 1 (online) |
| `iso/build-offline-iso.sh` | Script de construction Option 2 (offline) |
