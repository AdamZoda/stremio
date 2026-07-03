Write-Host "🚀 Installation de StreeIO..." -ForegroundColor Cyan

# 1. Vérification de Python
if (!(Get-Command python -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Python n'est pas installé sur votre PC !" -ForegroundColor Red
    Write-Host "Téléchargement automatique de Python en cours..." -ForegroundColor Yellow
    winget install Python.Python.3.11 --silent --accept-package-agreements --accept-source-agreements
    if (!(Get-Command python -ErrorAction SilentlyContinue)) {
        Write-Host "❌ Échec de l'installation automatique de Python. Veuillez l'installer manuellement : https://python.org" -ForegroundColor Red
        exit 1
    }
}

# 2. Installation de StreeIO
Write-Host "📦 Téléchargement et installation de StreeIO depuis GitHub..." -ForegroundColor Yellow
python -m pip install --upgrade pip
python -m pip install git+https://github.com/AdamZoda/stremio.git --force-reinstall

# 3. Vérification finale
if (Get-Command streeio -ErrorAction SilentlyContinue) {
    Write-Host "`n✅ StreeIO a été installé avec succès !" -ForegroundColor Green
    Write-Host "👉 Ouvrez un nouveau terminal et tapez : streeio" -ForegroundColor Cyan
} else {
    Write-Host "`n⚠ Installation terminée, mais les variables d'environnement ne sont pas à jour." -ForegroundColor Yellow
    Write-Host "👉 Veuillez fermer et rouvrir votre terminal, puis tapez : streeio" -ForegroundColor Cyan
}
