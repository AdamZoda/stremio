#!/bin/bash
# ─────────────────────────────────────────────
#  StreeIO — Installeur Premium (macOS / Linux)
#  Loader animé, pip silencieux, lancement auto
# ─────────────────────────────────────────────

RED='\033[0;91m'; GREEN='\033[0;92m'; CYAN='\033[0;96m'
YELLOW='\033[0;93m'; BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

spinner_run() {
    local label="$1"
    local success="$2"
    shift 2
    local cmd=("$@")
    local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    local i=0

    "${cmd[@]}" > /tmp/streeio_install.log 2>&1 &
    local pid=$!

    while kill -0 $pid 2>/dev/null; do
        local frame="${frames[$((i % 10))]}"
        printf "\r  ${CYAN}${frame}${NC}  ${YELLOW}${label}${NC}   "
        sleep 0.08
        ((i++))
    done

    wait $pid
    local exit_code=$?

    if [ $exit_code -eq 0 ]; then
        printf "\r  ${GREEN}✔${NC}  ${GREEN}${success}${NC}        \n"
    else
        printf "\r  ${RED}✖${NC}  ${RED}Échec : ${label}${NC}\n"
        cat /tmp/streeio_install.log
        exit 1
    fi
}

# ── Header ──────────────────────────────────────
clear
echo ""
echo -e "  ${CYAN}╭────────────────────────────────────╮${NC}"
echo -e "  ${CYAN}│${NC}   ${BOLD}STREEIO${NC} ${DIM}— Installeur v1.0${NC}          ${CYAN}│${NC}"
echo -e "  ${CYAN}╰────────────────────────────────────╯${NC}"
echo ""

# ── Étape 1 : Python ────────────────────────────
if command -v python3 &>/dev/null; then
    echo -e "  ${GREEN}✔${NC}  ${GREEN}Python détecté${NC}"
    PYTHON=python3
elif command -v python &>/dev/null; then
    echo -e "  ${GREEN}✔${NC}  ${GREEN}Python détecté${NC}"
    PYTHON=python
else
    if command -v brew &>/dev/null; then
        spinner_run "Installation de Python..." "Python installé" brew install python3
    elif command -v apt-get &>/dev/null; then
        spinner_run "Installation de Python..." "Python installé" sudo apt-get install -y python3 python3-pip git
    else
        echo -e "  ${RED}✖  Python introuvable. Installez-le : https://python.org${NC}"
        exit 1
    fi
    PYTHON=python3
fi

# ── Étape 2 : pip ───────────────────────────────
spinner_run "Mise à jour de pip..." "pip à jour" \
    $PYTHON -m pip install --upgrade pip --quiet --no-warn-script-location

# ── Étape 3 : StreeIO ───────────────────────────
spinner_run "Téléchargement de StreeIO..." "StreeIO installé" \
    $PYTHON -m pip install git+https://github.com/AdamZoda/stremio.git --force-reinstall --quiet --no-warn-script-location

# ── Rafraîchir PATH ─────────────────────────────
export PATH="$HOME/.local/bin:$PATH"

# ── Lancement ───────────────────────────────────
echo ""
echo -e "  ${GREEN}╭────────────────────────────────────╮${NC}"
echo -e "  ${GREEN}│${NC}   ${GREEN}✔ Installation réussie !${NC}            ${GREEN}│${NC}"
echo -e "  ${GREEN}│${NC}   ${CYAN}Lancement de StreeIO...${NC}           ${GREEN}│${NC}"
echo -e "  ${GREEN}╰────────────────────────────────────╯${NC}"
echo ""

sleep 1

# Lancer via python -m streeio (fonctionne toujours, pas besoin que streeio soit dans PATH)
$PYTHON -m streeio
