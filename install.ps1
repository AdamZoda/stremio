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
# Pour éviter tous les problèmes avec OneDrive et les dossiers utilisateur spéciaux,
# on installe directement dans un dossier dédié à la racine du disque C:
$installDir = "C:\streeio"



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
Spinner-Run "Téléchargement de StreeIO..." {
    # 1. Forcer la création du dossier de destination absolue
    if (-not (Test-Path $installDir)) {
        New-Item -ItemType Directory -Path $installDir -Force 2>&1 | Out-Null
    }

    # 2. Télécharger le ZIP depuis GitHub
    $zipPath = "$env:TEMP\streeio_download.zip"
    $extractPath = "$env:TEMP\streeio_extract"

    if (Test-Path $zipPath) { Remove-Item $zipPath -Force -ErrorAction SilentlyContinue }
    if (Test-Path $extractPath) { Remove-Item $extractPath -Recurse -Force -ErrorAction SilentlyContinue }

    # Utilisation d'un User-Agent pour éviter le blocage GitHub
    $webClient = New-Object System.Net.WebClient
    $webClient.Headers.Add("User-Agent", "Mozilla/5.0")
    $webClient.DownloadFile("https://github.com/AdamZoda/stremio/archive/refs/heads/main.zip", $zipPath)

    # 3. Extraction dans un dossier temporaire
    Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

    # 4. Copier proprement les fichiers extraits vers $installDir
    $subFolder = Get-ChildItem $extractPath | Where-Object { $_.PSIsContainer } | Select-Object -First 1
    if ($subFolder) {
        # Nettoyer d'abord pour éviter des conflits
        Remove-Item "$installDir\*" -Recurse -Force -ErrorAction SilentlyContinue
        Copy-Item -Path "$($subFolder.FullName)\*" -Destination $installDir -Recurse -Force
    }

    # 5. Nettoyer les fichiers temporaires
    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
    Remove-Item $extractPath -Recurse -Force -ErrorAction SilentlyContinue
} "Fichiers installés dans $installDir"


# ── Étape 3 : Installation locale de StreeIO et dépendances ──────
Spinner-Run "Installation locale de StreeIO..." {
    # On met à jour pip en premier
    python -m pip install --upgrade pip --quiet --no-warn-script-location 2>&1 | Out-Null
    
    # On se déplace dans le dossier d'installation pour installer le package localement
    Push-Location $installDir
    python -m pip install -e . --quiet --no-warn-script-location 2>&1 | Out-Null
    Pop-Location
} "StreeIO installé avec ses dépendances"

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

# S'assurer que le répertoire d'installation existe avant de s'y déplacer
if (Test-Path $installDir) {
    Set-Location $installDir
    python -m streeio
} else {
    Write-Host "❌ Erreur: Le dossier $installDir n'a pas pu être créé ou trouvé." -ForegroundColor Red
}

