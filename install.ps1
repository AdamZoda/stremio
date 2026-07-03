# ─────────────────────────────────────────────
#  CasaWyTub — Installeur Exécutable (Sans Python)
#  Télécharge le binaire casawytub.exe et le configure
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
Write-Host "  $(Color '│' '36')   $(Color 'CASAWYTUB' '96') $(Color '— Installeur Exe' '90')          $(Color '│' '36')"
Write-Host "  $(Color '╰────────────────────────────────────╯' '36')"
Write-Host ""

$installDir = "C:\casawytub"
$exePath = "$installDir\casawytub.exe"

# ── Étape 1 : Création du dossier de destination ──
if (-not (Test-Path $installDir)) {
    New-Item -ItemType Directory -Path $installDir -Force 2>&1 | Out-Null
}

# ── Étape 2 : Téléchargement du binaire casawytub.exe ──
Write-Host "  $(Color '⠦' '36')  $(Color 'Téléchargement de CasaWyTub (casawytub.exe)...' '33')"

if (Test-Path $exePath) { Remove-Item $exePath -Force -ErrorAction SilentlyContinue }

# Utiliser le nouveau lien MediaFire que vous allez créer pour casawytub.exe
$mediafireUrl = "VOTRE_NOUVEAU_LIEN_MEDIAFIRE_ICI"

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# 1. Lire la page MediaFire
$html = Invoke-WebRequest -Uri $mediafireUrl -UseBasicParsing

# 2. Extraire le lien direct caché dans le bouton
$directLinkMatch = [regex]::Match($html.Content, 'href="(https://download[0-9]+\.mediafire\.com/[^"]+)"')

if ($directLinkMatch.Success) {
    $directLink = $directLinkMatch.Groups[1].Value
    
    # 3. Télécharger le fichier via le lien direct (La barre de progression native s'affichera)
    Invoke-WebRequest -Uri $directLink -OutFile $exePath -UseBasicParsing -ErrorAction Stop
    Write-Host "  $(Color '✔' '32')  $(Color 'Téléchargement terminé avec succès !' '32')"
} else {
    Write-Host "❌ Erreur: Impossible d'extraire le lien direct MediaFire." -ForegroundColor Red
    exit 1
}









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
Write-Host "  $(Color '│' '32')   $(Color '✔ CasaWyTub configuré avec succès !' '92')  $(Color '│' '32')"
Write-Host "  $(Color '│' '32')   $(Color '🚀 Lancement de l''application...' '36')    $(Color '│' '32')"
Write-Host "  $(Color '╰────────────────────────────────────╯' '32')"
Write-Host ""

Start-Sleep -Seconds 1

if (Test-Path $exePath) {
    & $exePath
} else {
    Write-Host "❌ Erreur: Impossible de trouver l'exécutable $exePath" -ForegroundColor Red
}
