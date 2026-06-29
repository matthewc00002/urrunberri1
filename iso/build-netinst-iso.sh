#!/bin/bash
# =============================================================================
#  UrrunBerri OS — Build Preseeded Debian ISO (Option 1 — Online)
#  Openema SARL — Mathieu Cadi
#
#  This script takes a standard Debian 13 netinst ISO and injects the
#  UrrunBerri preseed.cfg. The resulting ISO installs Debian with minimal
#  user interaction, then automatically installs UrrunBerri OS on first boot.
#
#  Requires: xorriso, cpio, gzip, curl, root access
#  Run on: Debian dual-boot machine
#
#  Usage: sudo bash build-netinst-iso.sh
# =============================================================================

set -e

WORK_DIR="/tmp/urrunberri-iso-build"
DEBIAN_ISO_URL="https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-13.0.0-amd64-netinst.iso"
DEBIAN_ISO="$WORK_DIR/debian-netinst.iso"
PRESEED_URL="https://raw.githubusercontent.com/matthewc00002/urrunberri1/iso/iso/preseed.cfg"
OUTPUT_ISO="$WORK_DIR/urrunberri-os-netinst.iso"

echo "=================================================="
echo "  UrrunBerri OS — ISO Builder (Online / Netinst)"
echo "  Openema SARL"
echo "=================================================="
echo ""

[[ $EUID -ne 0 ]] && echo "[ERREUR] Lancez en root : sudo bash $0" && exit 1

# ── INSTALL DEPENDENCIES ─────────────────────────────────────────────────────
echo "[1/6] Installation des dependances..."
apt-get update -qq
apt-get install -y xorriso cpio gzip curl

# ── DOWNLOAD DEBIAN ISO ──────────────────────────────────────────────────────
mkdir -p "$WORK_DIR"
if [[ ! -f "$DEBIAN_ISO" ]]; then
    echo "[2/6] Telechargement de l'ISO Debian 13 netinst..."
    curl -fSL -o "$DEBIAN_ISO" "$DEBIAN_ISO_URL"
else
    echo "[2/6] ISO Debian deja presente, skip."
fi

# ── EXTRACT ISO ──────────────────────────────────────────────────────────────
echo "[3/6] Extraction de l'ISO..."
rm -rf "$WORK_DIR/iso-extract"
mkdir -p "$WORK_DIR/iso-extract"
xorriso -osirrox on -indev "$DEBIAN_ISO" -extract / "$WORK_DIR/iso-extract" 2>/dev/null
chmod -R u+w "$WORK_DIR/iso-extract"

# ── INJECT PRESEED ───────────────────────────────────────────────────────────
echo "[4/6] Injection du preseed UrrunBerri..."
curl -fsSL -o "$WORK_DIR/iso-extract/preseed.cfg" "$PRESEED_URL"

# Modify GRUB to auto-select preseed
if [[ -f "$WORK_DIR/iso-extract/boot/grub/grub.cfg" ]]; then
    sed -i 's|set default=.*|set default=0|' "$WORK_DIR/iso-extract/boot/grub/grub.cfg"
    sed -i 's|set timeout=.*|set timeout=5|' "$WORK_DIR/iso-extract/boot/grub/grub.cfg"
    # Add preseed to first menu entry
    sed -i '0,/---/{s|---|file=/cdrom/preseed.cfg ---|1}' "$WORK_DIR/iso-extract/boot/grub/grub.cfg"
fi

# Modify isolinux for BIOS boot
if [[ -f "$WORK_DIR/iso-extract/isolinux/isolinux.cfg" ]]; then
    sed -i 's/timeout 0/timeout 50/' "$WORK_DIR/iso-extract/isolinux/isolinux.cfg"
fi
if [[ -f "$WORK_DIR/iso-extract/isolinux/txt.cfg" ]]; then
    sed -i '0,/append/{s|append |append preseed/file=/cdrom/preseed.cfg |1}' "$WORK_DIR/iso-extract/isolinux/txt.cfg"
fi

# ── REBUILD ISO ──────────────────────────────────────────────────────────────
echo "[5/6] Reconstruction de l'ISO..."
cd "$WORK_DIR/iso-extract"

# Fix MD5
find . -type f ! -name "md5sum.txt" -exec md5sum {} \; > md5sum.txt 2>/dev/null || true

xorriso -as mkisofs \
    -r -V "UrrunBerri OS" \
    -o "$OUTPUT_ISO" \
    -J -joliet-long \
    -b isolinux/isolinux.bin \
    -c isolinux/boot.cat \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
    -eltorito-alt-boot \
    -e boot/grub/efi.img \
    -no-emul-boot \
    -isohybrid-gpt-basdat \
    "$WORK_DIR/iso-extract" 2>/dev/null

cd /

# ── DONE ──────────────────────────────────────────────────────────────────────
echo "[6/6] Nettoyage..."
rm -rf "$WORK_DIR/iso-extract"

ISO_SIZE=$(du -h "$OUTPUT_ISO" | cut -f1)
echo ""
echo "=================================================="
echo "  ISO generee : $OUTPUT_ISO"
echo "  Taille : $ISO_SIZE"
echo ""
echo "  Graver sur USB :"
echo "  sudo dd if=$OUTPUT_ISO of=/dev/sdX bs=4M status=progress"
echo ""
echo "  L'ISO va :"
echo "  1. Demander : langue, hostname, IP, mot de passe root"
echo "  2. Installer Debian 13 automatiquement"
echo "  3. Au premier demarrage : installer UrrunBerri OS"
echo "  4. Redemarrer sur UrrunBerri OS pret a l'emploi"
echo "=================================================="
