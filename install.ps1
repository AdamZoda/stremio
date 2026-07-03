# ─────────────────────────────────────────────
#  StreeIO — Installeur Premium
#  Masque tout le output pip, affiche un loader animé propre
# ─────────────────────────────────────────────

$ESC = [char]27
function Color($text, $code) { "$ESC[${code}m$text$ESC[0m" }

function Show-Step {
    param($icon, $label, $color)
    Write-Host "`r  $icon  $(Color $label $color)" -NoNewline
}

function Spinner-Run {
    param($label, [ScriptBlock]$job, $successLabel)

    $frames = @("⠋","⠙","⠹","⠸","⠼","⠴","⠦","⠧","⠇","⠏")
    $i = 0
    $done = $false

    # Lance le job en arrière-plan
    $async = [System.Threading.Tasks.Task]::Run([System.Action]{
        $job.Invoke() | Out-Null
        $script:done = $true
    })

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
Write-Host "  $(Color '│' '36')   $(Color 'STREEIO' '96') $(Color '— Installeur v1.0' '90')          $(Color '│' '36')"
Write-Host "  $(Color '╰────────────────────────────────────╯' '36')"
Write-Host ""

# ── Étape 1 : Python ────────────────────────────
$hasPython = [bool](Get-Command python -ErrorAction SilentlyContinue)

if (-not $hasPython) {
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

# ── Étape 2 : pip ───────────────────────────────
Spinner-Run "Mise à jour de pip..." {
    python -m pip install --upgrade pip --quiet --no-warn-script-location 2>&1 | Out-Null
} "pip à jour"

# ── Étape 3 : StreeIO ───────────────────────────
Spinner-Run "Téléchargement de StreeIO..." {
    python -m pip install git+https://github.com/AdamZoda/stremio.git --force-reinstall --quiet --no-warn-script-location 2>&1 | Out-Null
} "StreeIO installé"

# ── Étape 4 : Rafraîchir PATH ───────────────────
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# ── Lancement ───────────────────────────────────
Write-Host ""
Write-Host "  $(Color '╭────────────────────────────────────╮' '32')"
Write-Host "  $(Color '│' '32')   $(Color '✔ Installation réussie !' '92')            $(Color '│' '32')"
Write-Host "  $(Color '│' '32')   $(Color 'Lancement de StreeIO...' '36')           $(Color '│' '32')"
Write-Host "  $(Color '╰────────────────────────────────────╯' '32')"
Write-Host ""

Start-Sleep -Seconds 1

if (Get-Command streeio -ErrorAction SilentlyContinue) {
    streeio
} else {
    Write-Host "  $(Color '⚠  Ouvrez un nouveau terminal et tapez : streeio' '93')"
}
