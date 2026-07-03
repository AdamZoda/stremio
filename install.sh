#!/bin/bash
set -e

echo -e "\033[36m🚀 Installation de StreeIO...\033[0m"

# 1. Vérification de Python
if ! command -v python3 &> /dev/null; then
    echo -e "\033[31m❌ Python3 n'est pas détecté. Tentative d'installation...\033[0m"
    if command -v brew &> /dev/null; then
        brew install python3
    elif command -v apt-get &> /dev/null; then
        sudo apt-get update && sudo apt-get install -y python3 python3-pip git
    else
        echo -e "\033[31m❌ Impossible d'installer Python automatiquement. Installez python3 et pip manuellement.\033[0m"
        exit 1
    fi
fi

# 2. Installation de StreeIO
echo -e "\033[33m📦 Téléchargement et installation de StreeIO depuis GitHub...\033[0m"
python3 -m pip install --upgrade pip
python3 -m pip install git+https://github.com/AdamZoda/stremio.git --force-reinstall

# 3. Vérification finale
if command -v streeio &> /dev/null; then
    echo -e "\033[32m\n✅ StreeIO a été installé avec succès !\033[0m"
    echo -e "\033[36m👉 Tapez simplement : streeio\033[0m"
else
    echo -e "\033[33m\n⚠ Installation terminée, mais le chemin d'exécution n'est pas mis à jour dans le PATH.\033[0m"
    echo -e "\033[36m👉 Redémarrez votre terminal, puis tapez : streeio\033[0m"
fi
