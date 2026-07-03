# ─────────────────────────────────────────────
#  StreeIO — Installeur Exécutable (Sans Python)
#  Télécharge le binaire streeio.exe et le configure
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
Write-Host "  $(Color '│' '36')   $(Color 'STREEIO' '96') $(Color '— Installeur Exe' '90')          $(Color '│' '36')"
Write-Host "  $(Color '╰────────────────────────────────────╯' '36')"
Write-Host ""

$installDir = "C:\streeio"
$exePath = "$installDir\streeio.exe"

# ── Étape 1 : Création du dossier de destination ──
if (-not (Test-Path $installDir)) {
    New-Item -ItemType Directory -Path $installDir -Force 2>&1 | Out-Null
}

# ── Étape 2 : Téléchargement du binaire streeio.exe ──
Spinner-Run "Téléchargement de StreeIO (streeio.exe)..." {
    # Supprimer l'ancien fichier s'il existe et est cassé
    if (Test-Path $exePath) { Remove-Item $exePath -Force -ErrorAction SilentlyContinue }

    # On télécharge l'archive ZIP du dépôt qui contourne la limite des 10 Mo
    $zipPath = "$env:TEMP\streeio_exe_dl.zip"
    $extractPath = "$env:TEMP\streeio_exe_ext"
    if (Test-Path $zipPath) { Remove-Item $zipPath -Force -ErrorAction SilentlyContinue }
    if (Test-Path $extractPath) { Remove-Item $extractPath -Recurse -Force -ErrorAction SilentlyContinue }

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri "https://github.com/AdamZoda/stremio/archive/refs/heads/main.zip" -OutFile $zipPath -UseBasicParsing -ErrorAction Stop

    # Extraction
    Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

    # Récupérer l'exécutable depuis le dossier extrait dist/streeio.exe
    $extractedExe = Get-ChildItem -Path $extractPath -Filter "streeio.exe" -Recurse | Select-Object -First 1
    if ($extractedExe) {
        Copy-Item -Path $extractedExe.FullName -Destination $exePath -Force
    }

    # Nettoyage
    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
    Remove-Item $extractPath -Recurse -Force -ErrorAction SilentlyContinue
} "Téléchargement terminé"




# ── Étape 3 : Configuration du PATH permanent ──
if ($installDir -and (Test-Path $installDir)) {
    $currentUserPath = [System.Environment]::GetEnvironmentVariable("Path","User")
    if ($currentUserPath -notlike "*$installDir*") {
        [System.Environment]::SetEnvironmentVariable("Path", "$installDir;$currentUserPath", "User")
    }
    if ($env:Path -notlike "*$installDir*") {
        $env:Path = "$installDir;$env:Path"
    }
}

# ── Lancement ───────────────────────────────────
Write-Host ""
Write-Host "  $(Color '╭────────────────────────────────────╮' '32')"
Write-Host "  $(Color '│' '32')   $(Color '✔ StreeIO configuré avec succès !' '92')  $(Color '│' '32')"
Write-Host "  $(Color '│' '32')   $(Color '🚀 Lancement de l''application...' '36')    $(Color '│' '32')"
Write-Host "  $(Color '╰────────────────────────────────────╯' '32')"
Write-Host ""

Start-Sleep -Seconds 1

if (Test-Path $exePath) {
    & $exePath
} else {
    Write-Host "❌ Erreur: Impossible de trouver l'exécutable $exePath" -ForegroundColor Red
}
