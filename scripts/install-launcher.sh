#!/bin/bash
# =============================================================================
#  UrrunBerri OS — Lanceur d'installation
#  Openema SARL — Mathieu Cadi
#
#  Utilisation : bash install-launcher.sh
# =============================================================================

set -e

echo "============================================="
echo "   UrrunBerri OS - Installation"
echo "   Openema SARL"
echo "============================================="
echo ""

# Verifier que wget est installe
if ! command -v wget >/dev/null 2>&1; then
    echo "[UrrunBerri OS] Installation de wget..."
    apt-get update -qq
    apt-get install -y wget
fi

echo "[UrrunBerri OS] Telechargement et installation en cours..."
echo ""

# Telecharger et executer le script d'installation
wget -qO- https://raw.githubusercontent.com/matthewc00002/urrunberri1/main/scripts/install.sh | bash

echo ""
echo "[UrrunBerri OS] Termine. Redemarrez avec : reboot"
