# ─────────────────────────────────────────────
#  StreeIO — Installeur v3.0
#  Simple: pip install depuis GitHub + lancement direct
# ─────────────────────────────────────────────

$ESC = [char]27
function Color($text, $code) { "$ESC[${code}m$text$ESC[0m" }

function Run-WithSpinner {
    param([string]$Label, [string]$SuccessLabel, [scriptblock]$Command)

    # Lancer le job via Start-Job (subprocess réel, accès aux variables)
    $job = Start-Job -ScriptBlock $Command

    $frames = @("⠋","⠙","⠹","⠸","⠼","⠴","⠦","⠧","⠇","⠏")
    $i = 0
    while ($job.State -eq 'Running') {
        Write-Host "`r  $(Color $frames[$i % 10] '36')  $(Color $Label '33')   " -NoNewline
        Start-Sleep -Milliseconds 100
        $i++
    }

    $output = Receive-Job $job
    $state  = $job.State
    Remove-Job $job

    if ($state -eq 'Completed') {
        Write-Host "`r  $(Color '✔' '32')  $(Color $SuccessLabel '32')        "
    } else {
        Write-Host "`r  $(Color '✖  Erreur lors de : ' '91')$Label"
        Write-Host $output
        exit 1
    }
}

# ── Header ──────────────────────────────────────
Clear-Host
Write-Host ""
Write-Host "  $(Color '╭────────────────────────────────────╮' '36')"
Write-Host "  $(Color '│' '36')   $(Color 'STREEIO' '96') $(Color '— Installeur v3.0' '90')          $(Color '│' '36')"
Write-Host "  $(Color '╰────────────────────────────────────╯' '36')"
Write-Host ""

# ── Étape 1 : Python ────────────────────────────
if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    Run-WithSpinner "Installation de Python 3.11..." "Python 3.11 installé" {
        winget install Python.Python.3.11 --silent --accept-package-agreements --accept-source-agreements 2>&1
    }
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
        Write-Host "  $(Color '✖  Python introuvable. Installez manuellement : https://python.org' '91')"
        exit 1
    }
} else {
    Write-Host "  $(Color '✔' '32')  $(Color 'Python détecté' '32')"
}

# ── Étape 2 : Installation de StreeIO via pip ───
# Pas de téléchargement manuel, pas de dossier — pip fait tout
Run-WithSpinner "Installation de StreeIO..." "StreeIO installé" {
    python -m pip install --upgrade pip --quiet --no-warn-script-location 2>&1 | Out-Null
    python -m pip install git+https://github.com/AdamZoda/stremio.git --force-reinstall --quiet --no-warn-script-location 2>&1
}

# ── Étape 3 : PATH permanent ─────────────────────
$scriptsDir = python -c "import sys, os; print(os.path.join(os.path.dirname(sys.executable), 'Scripts'))" 2>$null
if ($scriptsDir -and (Test-Path $scriptsDir)) {
    $userPath = [System.Environment]::GetEnvironmentVariable("Path","User")
    if ($userPath -notlike "*$scriptsDir*") {
        [System.Environment]::SetEnvironmentVariable("Path", "$scriptsDir;$userPath", "User")
    }
    $env:Path = "$scriptsDir;$env:Path"
}

# ── Lancement ────────────────────────────────────
Write-Host ""
Write-Host "  $(Color '╭────────────────────────────────────╮' '32')"
Write-Host "  $(Color '│' '32')   $(Color '✔ Prêt ! Lancement de StreeIO...' '92')   $(Color '│' '32')"
Write-Host "  $(Color '╰────────────────────────────────────╯' '32')"
Write-Host ""

Start-Sleep -Seconds 1

python -m streeio
