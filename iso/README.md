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

L'installeur ne pose que les questions essentielles :

| Question | Defaut |
|----------|--------|
| Langue | (choix utilisateur) |
| Hostname | (choix utilisateur) |
| Adresse IP | (choix utilisateur) |
| Masque | (choix utilisateur) |
| Passerelle | (choix utilisateur) |
| DNS | (choix utilisateur) |
| Mot de passe root | (choix utilisateur) |

Tout le reste (partitionnement, paquets, configuration) est automatique.

## Graver sur USB

```bash
sudo dd if=urrunberri-os-*.iso of=/dev/sdX bs=4M status=progress
```

Remplacer `/dev/sdX` par le bon peripherique (verifier avec `lsblk`).

## Construction

Les scripts de construction doivent etre executes sur une machine Debian (la machine dual-boot par exemple). Ils necessitent un acces root et environ 2 Go d'espace disque temporaire.

## Fichiers

| Fichier | Description |
|---------|-------------|
| `iso/preseed.cfg` | Configuration preseed Debian |
| `iso/build-netinst-iso.sh` | Script de construction Option 1 |
| `iso/build-offline-iso.sh` | Script de construction Option 2 |
