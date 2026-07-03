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
    # URL directe vers le fichier brut du dépôt
    $url = "https://raw.githubusercontent.com/AdamZoda/stremio/main/dist/streeio.exe"
    
    $webClient = New-Object System.Net.WebClient
    $webClient.Headers.Add("User-Agent", "Mozilla/5.0")
    $webClient.DownloadFile($url, $exePath)
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
