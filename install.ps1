# ─────────────────────────────────────────────
#  StreeIO — Installeur Premium v2.0
#  Installe dans Downloads\streeio
#  Ouvre un nouveau terminal et lance StreeIO auto
# ─────────────────────────────────────────────

$ESC = [char]27
function Color($text, $code) { "$ESC[${code}m$text$ESC[0m" }

function Spinner-Run {
    param($label, [ScriptBlock]$job, $successLabel)
    $frames = @("⠋","⠙","⠹","⠸","⠼","⠴","⠦","⠧","⠇","⠏")
    $i = 0
    $async = [System.Threading.Tasks.Task]::Run([System.Action]{ $job.Invoke() | Out-Null })
    while (-not $async.IsCompleted) {
        $frame = $frames[$i % $frames.Length]
        Write-Host "`r  $(Color $frame '36')  $(Color $label '33')   " -NoNewline
        Start-Sleep -Milliseconds 80
        $i++
    }
    Write-Host "`r  $(Color '✔' '32')  $(Color $successLabel '32')        "
}

# ── Header ──────────────────────────────────────
Clear-Host
Write-Host ""
Write-Host "  $(Color '╭────────────────────────────────────╮' '36')"
Write-Host "  $(Color '│' '36')   $(Color 'STREEIO' '96') $(Color '— Installeur v2.0' '90')          $(Color '│' '36')"
Write-Host "  $(Color '╰────────────────────────────────────╯' '36')"
Write-Host ""

# ── Dossier d'installation ──────────────────────
$installDir = "$env:USERPROFILE\Downloads\streeio"

# ── Étape 1 : Python ────────────────────────────
if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    Spinner-Run "Installation de Python 3.11..." {
        winget install Python.Python.3.11 --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
    } "Python 3.11 installé"
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
        Write-Host "  $(Color '✖  Python introuvable. Installez manuellement : https://python.org' '91')"
        exit 1
    }
} else {
    Write-Host "  $(Color '✔' '32')  $(Color 'Python détecté' '32')"
}

# ── Étape 2 : Téléchargement des fichiers ───────
Spinner-Run "Téléchargement de StreeIO dans Downloads..." {
    # Supprimer l'ancienne version si elle existe
    if (Test-Path $installDir) {
        Remove-Item $installDir -Recurse -Force 2>&1 | Out-Null
    }
    New-Item -ItemType Directory -Path $installDir -Force 2>&1 | Out-Null

    # Télécharger le zip depuis GitHub
    $zipPath = "$env:TEMP\streeio_download.zip"
    $extractPath = "$env:TEMP\streeio_extract"

    Invoke-WebRequest -Uri "https://github.com/AdamZoda/stremio/archive/refs/heads/main.zip" -OutFile $zipPath -UseBasicParsing

    if (Test-Path $extractPath) { Remove-Item $extractPath -Recurse -Force }
    Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

    # Copier le contenu dans Downloads\streeio
    $extracted = Get-ChildItem $extractPath | Select-Object -First 1
    Copy-Item -Path "$($extracted.FullName)\*" -Destination $installDir -Recurse -Force

    # Nettoyer temp
    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
    Remove-Item $extractPath -Recurse -Force -ErrorAction SilentlyContinue
} "Fichiers installés dans Downloads\streeio"

# ── Étape 3 : pip + dépendances ─────────────────
Spinner-Run "Mise à jour de pip..." {
    python -m pip install --upgrade pip --quiet --no-warn-script-location 2>&1 | Out-Null
} "pip à jour"

Spinner-Run "Installation des dépendances (yt-dlp)..." {
    python -m pip install yt-dlp --quiet --no-warn-script-location 2>&1 | Out-Null
} "yt-dlp installé"

# ── Étape 4 : PATH permanent ────────────────────
$scriptsDir = python -c "import sys, os; print(os.path.join(os.path.dirname(sys.executable), 'Scripts'))" 2>$null
if ($scriptsDir -and (Test-Path $scriptsDir)) {
    $currentUserPath = [System.Environment]::GetEnvironmentVariable("Path","User")
    if ($currentUserPath -notlike "*$scriptsDir*") {
        [System.Environment]::SetEnvironmentVariable("Path", "$scriptsDir;$currentUserPath", "User")
    }
    if ($env:Path -notlike "*$scriptsDir*") {
        $env:Path = "$scriptsDir;$env:Path"
    }
}

# ── Lancement dans le terminal courant ──────────
Write-Host ""
Write-Host "  $(Color '╭────────────────────────────────────╮' '32')"
Write-Host "  $(Color '│' '32')   $(Color '✔ StreeIO installé dans Downloads !' '92')  $(Color '│' '32')"
Write-Host "  $(Color '│' '32')   $(Color '🚀 Lancement...' '36')                      $(Color '│' '32')"
Write-Host "  $(Color '╰────────────────────────────────────╯' '32')"
Write-Host ""

Start-Sleep -Seconds 1

# Aller dans Downloads\streeio et lancer streeio dans le même terminal
Set-Location $installDir
python -m streeio
