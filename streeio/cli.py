#!/usr/bin/env python3
"""
StreeIO CLI v4.3.0
Extracteur local YouTube → MP4 / MP3
Terminal UI inspirée de Claude Code
Auto-installation des dépendances au premier lancement
"""

import os
import sys
import shutil
import time
import re
import subprocess
import threading
from pathlib import Path

# ──────────────────────────────────────────────────────────────
# COULEURS ANSI & STYLES
# ──────────────────────────────────────────────────────────────

class C:
    """Palette de couleurs ANSI 256 + styles."""
    RST      = "\033[0m"
    BOLD     = "\033[1m"
    DIM      = "\033[2m"
    ITALIC   = "\033[3m"
    ULINE    = "\033[4m"
    # Couleurs principales
    CYAN     = "\033[38;5;87m"
    MAGENTA  = "\033[38;5;205m"
    GREEN    = "\033[38;5;84m"
    RED      = "\033[38;5;203m"
    YELLOW   = "\033[38;5;221m"
    ORANGE   = "\033[38;5;215m"
    BLUE     = "\033[38;5;75m"
    PURPLE   = "\033[38;5;141m"
    WHITE    = "\033[38;5;255m"
    GRAY     = "\033[38;5;245m"
    DARK     = "\033[38;5;239m"
    # Backgrounds
    BG_DARK  = "\033[48;5;234m"
    BG_CYAN  = "\033[48;5;30m"
    BG_RED   = "\033[48;5;52m"
    BG_GREEN = "\033[48;5;22m"

# Cacher le curseur / le réafficher
HIDE_CURSOR = "\033[?25l"
SHOW_CURSOR = "\033[?25h"


def term_width():
    """Largeur du terminal, fallback 80."""
    return shutil.get_terminal_size((80, 24)).columns


def clear_screen():
    os.system("cls" if os.name == "nt" else "clear")


# ──────────────────────────────────────────────────────────────
# SPINNER ANIMÉ
# ──────────────────────────────────────────────────────────────

class Spinner:
    """Spinner animé style Claude Code pour les opérations longues."""

    FRAMES_DOTS = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
    FRAMES_BARS = ["▰▱▱▱▱", "▰▰▱▱▱", "▰▰▰▱▱", "▰▰▰▰▱", "▰▰▰▰▰", "▱▰▰▰▰", "▱▱▰▰▰", "▱▱▱▰▰", "▱▱▱▱▰", "▱▱▱▱▱"]

    def __init__(self, message, color=C.CYAN, frames=None):
        self.message = message
        self.color = color
        self.frames = frames or self.FRAMES_DOTS
        self._stop = threading.Event()
        self._thread = None
        self.success_msg = None
        self.error_msg = None

    def _spin(self):
        i = 0
        sys.stdout.write(HIDE_CURSOR)
        while not self._stop.is_set():
            frame = self.frames[i % len(self.frames)]
            line = f"\r  {self.color}{frame}{C.RST}  {C.WHITE}{self.message}{C.RST}  "
            sys.stdout.write(line)
            sys.stdout.flush()
            i += 1
            time.sleep(0.08)
        sys.stdout.write(SHOW_CURSOR)

    def start(self):
        self._thread = threading.Thread(target=self._spin, daemon=True)
        self._thread.start()
        return self

    def stop(self, success=True, message=None):
        self._stop.set()
        if self._thread:
            self._thread.join()
        # Effacer la ligne
        sys.stdout.write(f"\r{' ' * term_width()}\r")
        sys.stdout.flush()
        if message:
            if success:
                sys.stdout.write(f"  {C.GREEN}✔{C.RST}  {C.WHITE}{message}{C.RST}\n")
            else:
                sys.stdout.write(f"  {C.RED}✖{C.RST}  {C.WHITE}{message}{C.RST}\n")
        sys.stdout.flush()

    def __enter__(self):
        return self.start()

    def __exit__(self, *args):
        self.stop()


# ──────────────────────────────────────────────────────────────
# COMPOSANTS UI
# ──────────────────────────────────────────────────────────────

def draw_box(lines, title="", border_color=C.CYAN, padding=1):
    """Dessine un panneau encadré style Claude Code."""
    w = term_width() - 2
    inner_w = w - 2 - (padding * 2)

    # Top border
    top = f"{border_color}╭{'─' * w}╮{C.RST}"
    if title:
        title_str = f" {title} "
        t_len = len(title) + 2
        left_seg = 2
        right_seg = w - left_seg - t_len
        if right_seg < 0:
            right_seg = 0
        top = f"{border_color}╭──{C.RST}{C.BOLD}{C.WHITE} {title} {C.RST}{border_color}{'─' * right_seg}╮{C.RST}"

    print(top)

    # Padding top
    for _ in range(padding):
        print(f"{border_color}│{C.RST}{' ' * w}{border_color}│{C.RST}")

    # Content lines
    for line in lines:
        clean = re.sub(r'\033\[[0-9;]*m', '', line)
        space_needed = inner_w - len(clean)
        if space_needed < 0:
            space_needed = 0
        pad_str = ' ' * padding
        print(f"{border_color}│{C.RST}{pad_str}{line}{' ' * space_needed}{pad_str}{border_color}│{C.RST}")

    # Padding bottom
    for _ in range(padding):
        print(f"{border_color}│{C.RST}{' ' * w}{border_color}│{C.RST}")

    # Bottom border
    print(f"{border_color}╰{'─' * w}╯{C.RST}")


def draw_divider(char="─", color=C.DARK):
    w = term_width()
    print(f"{color}{char * w}{C.RST}")


def draw_header():
    """Affiche le header ASCII art style Claude Code."""
    logo_lines = [
        f"{C.CYAN}{C.BOLD}  ┌─┐┌┬┐┬─┐┌─┐┌─┐ ┬┌─┐",
        f"  └─┐ │ ├┬┘├┤ ├┤  ││ │",
        f"  └─┘ ┴ ┴└─└─┘└─┘o┴└─┘{C.RST}",
    ]
    version = f"{C.GRAY}v4.3.0{C.RST}"
    subtitle = f"{C.DIM}{C.WHITE}Extracteur Local YouTube → MP4 / MP3{C.RST}"

    print()
    for l in logo_lines:
        print(f"  {l}")
    print(f"  {' ' * 34}{version}")
    print()
    print(f"  {subtitle}")
    draw_divider()


def draw_status(icon, label, value, label_color=C.GRAY, value_color=C.WHITE):
    """Affiche une ligne de statut key: value."""
    print(f"  {icon}  {label_color}{label}{C.RST}  {value_color}{value}{C.RST}")


def draw_step(number, text, color=C.CYAN):
    """Affiche un indicateur d'étape numérotée."""
    print(f"\n  {color}{C.BOLD}[{number}]{C.RST}  {C.WHITE}{C.BOLD}{text}{C.RST}")
    print(f"  {C.DARK}{'─' * (term_width() - 6)}{C.RST}")


def draw_option(key, icon, label, desc, selected=False):
    """Affiche une option de menu."""
    if selected:
        marker = f"{C.CYAN}{C.BOLD}›{C.RST}"
        key_style = f"{C.CYAN}{C.BOLD}{key}{C.RST}"
        label_style = f"{C.WHITE}{C.BOLD}{label}{C.RST}"
    else:
        marker = f"{C.DARK}›{C.RST}"
        key_style = f"{C.GRAY}{key}{C.RST}"
        label_style = f"{C.WHITE}{label}{C.RST}"
    print(f"  {marker}  {key_style}  {icon}  {label_style}  {C.DARK}— {desc}{C.RST}")


def draw_success(message):
    """Affiche un message de succès."""
    print()
    draw_box(
        [f"{C.GREEN}{C.BOLD}✔  {message}{C.RST}"],
        title="Succès",
        border_color=C.GREEN,
        padding=1
    )


def draw_error(message):
    """Affiche un message d'erreur."""
    print()
    draw_box(
        [f"{C.RED}{C.BOLD}✖  {message}{C.RST}"],
        title="Erreur",
        border_color=C.RED,
        padding=1
    )


def draw_warning(message):
    """Affiche un avertissement."""
    print(f"\n  {C.YELLOW}⚠  {message}{C.RST}")


def draw_info(message):
    """Affiche une info."""
    print(f"  {C.BLUE}ℹ  {C.GRAY}{message}{C.RST}")


def prompt(label, default=None):
    """Prompt stylé avec valeur par défaut."""
    default_hint = f" {C.DARK}({default}){C.RST}" if default else ""
    try:
        value = input(f"\n  {C.CYAN}{C.BOLD}›{C.RST}  {C.WHITE}{label}{default_hint}{C.CYAN} › {C.RST}").strip()
    except (EOFError, KeyboardInterrupt):
        print()
        sys.exit(0)
    return value if value else default


# ──────────────────────────────────────────────────────────────
# AUTO-INSTALLATION DES DÉPENDANCES
# ──────────────────────────────────────────────────────────────

def pip_install(package):
    """Installe un package via pip, retourne True si succès."""
    try:
        result = subprocess.run(
            [sys.executable, "-m", "pip", "install", "--upgrade", package],
            capture_output=True,
            text=True,
            timeout=300,
        )
        return result.returncode == 0
    except Exception:
        return False


def get_local_bin_dir():
    """Détermine le dossier local contenant les binaires de secours."""
    p = Path.home() / ".streeio" / "bin"
    p.mkdir(parents=True, exist_ok=True)
    return p


def download_file(url, dest_path):
    """Télécharge un fichier de manière robuste (urllib, curl, powershell)."""
    import urllib.request
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req, timeout=60) as r:
            with open(dest_path, 'wb') as f:
                f.write(r.read())
        return True
    except Exception:
        pass
        
    try:
        res = subprocess.run(["curl", "-L", "-o", str(dest_path), url], capture_output=True)
        if res.returncode == 0 and dest_path.exists():
            return True
    except Exception:
        pass
        
    if sys.platform == "win32":
        try:
            res = subprocess.run([
                "powershell", "-Command", 
                f"[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '{url}' -OutFile '{dest_path}'"
            ], capture_output=True)
            if res.returncode == 0 and dest_path.exists():
                return True
        except Exception:
            pass
            
    return False


def download_ffmpeg_binary():
    """Télécharge et extrait les binaires statiques de FFmpeg et FFprobe."""
    import zipfile
    
    local_dir = get_local_bin_dir()
    system = sys.platform
    
    # Sources principales (GitHub Releases) et miroirs
    if system == "win32":
        sources = [
            {
                "ffmpeg": "https://github.com/ffbinaries/ffbinaries-prebuilt/releases/download/v4.4.1/ffmpeg-4.4.1-win-64.zip",
                "ffprobe": "https://github.com/ffbinaries/ffbinaries-prebuilt/releases/download/v4.4.1/ffprobe-4.4.1-win-64.zip"
            },
            {
                "ffmpeg": "https://node.ffbinaries.com/bin/windows-64/ffmpeg.zip",
                "ffprobe": "https://node.ffbinaries.com/bin/windows-64/ffprobe.zip"
            }
        ]
    elif system == "darwin":
        sources = [
            {
                "ffmpeg": "https://github.com/ffbinaries/ffbinaries-prebuilt/releases/download/v4.4.1/ffmpeg-4.4.1-osx-64.zip",
                "ffprobe": "https://github.com/ffbinaries/ffbinaries-prebuilt/releases/download/v4.4.1/ffprobe-4.4.1-osx-64.zip"
            },
            {
                "ffmpeg": "https://node.ffbinaries.com/bin/osx-64/ffmpeg.zip",
                "ffprobe": "https://node.ffbinaries.com/bin/osx-64/ffprobe.zip"
            }
        ]
    else:
        sources = [
            {
                "ffmpeg": "https://github.com/ffbinaries/ffbinaries-prebuilt/releases/download/v4.4.1/ffmpeg-4.4.1-linux-64.zip",
                "ffprobe": "https://github.com/ffbinaries/ffbinaries-prebuilt/releases/download/v4.4.1/ffprobe-4.4.1-linux-64.zip"
            },
            {
                "ffmpeg": "https://node.ffbinaries.com/bin/linux-64/ffmpeg.zip",
                "ffprobe": "https://node.ffbinaries.com/bin/linux-64/ffprobe.zip"
            }
        ]
        
    for source in sources:
        try:
            for component, url in source.items():
                zip_name = f"{component}_temp.zip"
                zip_path = local_dir / zip_name
                
                # Téléchargement robuste
                if not download_file(url, zip_path):
                    raise Exception("Download failed")
                        
                # Extraction
                with zipfile.ZipFile(zip_path, 'r') as zip_ref:
                    zip_ref.extractall(local_dir)
                    
                # Nettoyage
                if zip_path.exists():
                    zip_path.unlink()
                    
                # Renommer si nécessaire (ex: ffmpeg-4.4.1-win-64 en ffmpeg.exe)
                ext = ".exe" if system == "win32" else ""
                extracted_file = None
                for f in local_dir.iterdir():
                    if f.name.startswith(component) and f.name.endswith(ext) and f.name != f"{component}{ext}":
                        extracted_file = f
                        break
                if extracted_file:
                    target_path = local_dir / f"{component}{ext}"
                    if target_path.exists():
                        target_path.unlink()
                    extracted_file.rename(target_path)

            # Droits d'exécution sur Unix
            if system != "win32":
                for name in ["ffmpeg", "ffprobe"]:
                    binary_path = local_dir / name
                    if binary_path.exists():
                        binary_path.chmod(0o755)
                        
            # Mise à jour du PATH au runtime
            if str(local_dir) not in os.environ["PATH"]:
                os.environ["PATH"] = str(local_dir) + os.pathsep + os.environ["PATH"]
                
            return True
        except Exception:
            continue
            
    return False


def check_yt_dlp():
    """Vérifie si yt-dlp est importable."""
    try:
        import yt_dlp  # noqa: F401
        return True
    except ImportError:
        return False


def check_ffmpeg():
    """Vérifie que FFmpeg et FFprobe sont accessibles (système ou local)."""
    if shutil.which("ffmpeg") is not None and shutil.which("ffprobe") is not None:
        return True
        
    local_dir = get_local_bin_dir()
    ext = ".exe" if sys.platform == "win32" else ""
    ffmpeg_path = local_dir / f"ffmpeg{ext}"
    ffprobe_path = local_dir / f"ffprobe{ext}"
    
    if ffmpeg_path.exists() and ffprobe_path.exists():
        if str(local_dir) not in os.environ["PATH"]:
            os.environ["PATH"] = str(local_dir) + os.pathsep + os.environ["PATH"]
        return True
        
    return False


def first_launch_setup():
    """
    Écran de premier lancement : vérifie et installe automatiquement
    toutes les dépendances avec des loaders animés.
    Retourne True si tout est prêt, False sinon.
    """
    yt_ok = check_yt_dlp()
    ff_ok = check_ffmpeg()

    # Si tout est déjà installé, pas besoin du setup
    if yt_ok and ff_ok:
        return True

    # ── Écran de setup ──
    print()
    draw_box(
        [
            f"{C.WHITE}{C.BOLD}Bienvenue dans StreeIO !{C.RST}",
            f"",
            f"{C.GRAY}Première utilisation détectée.{C.RST}",
            f"{C.GRAY}Installation automatique des outils nécessaires...{C.RST}",
        ],
        title="Setup",
        border_color=C.MAGENTA,
    )
    print()

    all_ok = True

    # ── 1. Installation de yt-dlp ──
    if not yt_ok:
        spinner = Spinner("Installation de yt-dlp (moteur de téléchargement)...", color=C.CYAN)
        spinner.start()
        success = pip_install("yt-dlp")
        if success:
            spinner.stop(success=True, message=f"yt-dlp installé avec succès")
        else:
            spinner.stop(success=False, message=f"Échec de l'installation de yt-dlp")
            all_ok = False
    else:
        print(f"  {C.GREEN}✔{C.RST}  {C.WHITE}yt-dlp déjà installé{C.RST}")

    # ── 2. Installation de FFmpeg ──
    if not ff_ok:
        spinner = Spinner("Installation de FFmpeg (encodeur audio/vidéo)...", color=C.CYAN)
        spinner.start()
        success = download_ffmpeg_binary()
        if success:
            spinner.stop(success=True, message=f"FFmpeg et FFprobe installés avec succès")
        else:
            spinner.stop(success=False, message=f"Échec du téléchargement automatique de FFmpeg")
            all_ok = False
    else:
        print(f"  {C.GREEN}✔{C.RST}  {C.WHITE}FFmpeg déjà installé{C.RST}")

    print()

    # ── Vérification finale ──
    if not check_yt_dlp():
        draw_error("Impossible d'installer yt-dlp. Vérifiez votre connexion internet.")
        print()
        draw_box(
            [
                f"{C.WHITE}Installez manuellement :{C.RST}",
                f"",
                f"  {C.CYAN}pip install yt-dlp{C.RST}",
                f"",
                f"{C.GRAY}Puis relancez StreeIO.{C.RST}",
            ],
            title="Installation manuelle",
            border_color=C.YELLOW,
        )
        print()
        return False

    if not check_ffmpeg():
        draw_error("Impossible d'installer FFmpeg. Vérifiez votre connexion internet.")
        print()
        draw_box(
            [
                f"{C.WHITE}FFmpeg est requis pour le traitement audio/vidéo.{C.RST}",
                f"{C.WHITE}Téléchargez-le ou installez-le manuellement sur votre PATH.{C.RST}",
            ],
            title="Erreur FFmpeg",
            border_color=C.RED,
        )
        print()
        return False

    # ── Succès ──
    draw_divider("─", C.DARK)
    time.sleep(0.3)

    # Petite animation de chargement final
    frames = ["▰▱▱▱▱▱▱▱", "▰▰▱▱▱▱▱▱", "▰▰▰▱▱▱▱▱", "▰▰▰▰▱▱▱▱",
              "▰▰▰▰▰▱▱▱", "▰▰▰▰▰▰▱▱", "▰▰▰▰▰▰▰▱", "▰▰▰▰▰▰▰▰"]
    sys.stdout.write(HIDE_CURSOR)
    for i, frame in enumerate(frames):
        pct = int((i + 1) / len(frames) * 100)
        sys.stdout.write(f"\r  {C.CYAN}{frame}{C.RST}  {C.GRAY}Initialisation...{C.RST}  {C.WHITE}{pct}%{C.RST}  ")
        sys.stdout.flush()
        time.sleep(0.12)
    sys.stdout.write(f"\r{' ' * term_width()}\r")
    sys.stdout.write(SHOW_CURSOR)
    sys.stdout.flush()

    print(f"  {C.GREEN}{C.BOLD}✔  Environnement prêt !{C.RST}")
    print()
    time.sleep(0.5)

    return True


# ──────────────────────────────────────────────────────────────
# PROGRESS HOOK (barre de progression yt-dlp)
# ──────────────────────────────────────────────────────────────

class ProgressDisplay:
    """Hook de progression pour yt-dlp avec barre animée."""

    def __init__(self):
        self.started = False

    def hook(self, d):
        if d['status'] == 'downloading':
            total = d.get('total_bytes') or d.get('total_bytes_estimate') or 0
            downloaded = d.get('downloaded_bytes', 0)
            speed = d.get('speed')
            eta = d.get('eta')

            if total > 0:
                pct = downloaded / total
                bar_width = term_width() - 40
                if bar_width < 10:
                    bar_width = 10
                filled = int(bar_width * pct)
                empty = bar_width - filled

                bar = f"{C.CYAN}{'█' * filled}{C.DARK}{'░' * empty}{C.RST}"
                pct_str = f"{C.WHITE}{C.BOLD}{pct * 100:5.1f}%{C.RST}"

                # Taille
                dl_mb = downloaded / (1024 * 1024)
                tot_mb = total / (1024 * 1024)
                size_str = f"{C.GRAY}{dl_mb:.1f}/{tot_mb:.1f} MB{C.RST}"

                # Vitesse
                if speed:
                    speed_mb = speed / (1024 * 1024)
                    speed_str = f"{C.GREEN}{speed_mb:.1f} MB/s{C.RST}"
                else:
                    speed_str = f"{C.DARK}--- MB/s{C.RST}"

                # ETA
                if eta:
                    eta_str = f"{C.YELLOW}{eta}s{C.RST}"
                else:
                    eta_str = f"{C.DARK}---{C.RST}"

                line = f"\r  {bar}  {pct_str}  {size_str}  {speed_str}  {eta_str}  "
                sys.stdout.write(line)
                sys.stdout.flush()

        elif d['status'] == 'finished':
            sys.stdout.write("\r" + " " * term_width() + "\r")
            sys.stdout.flush()
            filesize = d.get('total_bytes') or d.get('total_bytes_estimate') or 0
            if filesize:
                mb = filesize / (1024 * 1024)
                print(f"  {C.GREEN}█{'█' * (term_width() - 38)}█{C.RST}  {C.GREEN}{C.BOLD}100.0%{C.RST}  {C.GRAY}{mb:.1f} MB{C.RST}  {C.GREEN}✔{C.RST}")
            else:
                print(f"  {C.GREEN}{'█' * (term_width() - 20)}{C.RST}  {C.GREEN}{C.BOLD}100.0%{C.RST}  {C.GREEN}✔{C.RST}")


# ──────────────────────────────────────────────────────────────
# LOGIQUE PRINCIPALE
# ──────────────────────────────────────────────────────────────

def get_download_folder():
    """Détermine le dossier de téléchargement."""
    home = Path.home()
    candidates = ["Downloads", "Téléchargements", "Desktop", "Bureau"]
    for c in candidates:
        p = home / c
        if p.exists() and p.is_dir():
            return p
    return home


def check_for_updates():
    """Vérifie si une mise à jour est requise ou disponible depuis GitHub."""
    import urllib.request
    import json
    
    current_version = "4.3.0"
    url = "https://raw.githubusercontent.com/AdamZoda/stremio/main/version.json"
    
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req, timeout=3) as response:
            data = json.loads(response.read().decode('utf-8'))
            
        latest = data.get("latest_version", current_version)
        min_ver = data.get("min_version", current_version)
        status = data.get("status", "active")
        msg = data.get("message", "")
        
        # 1. Désactivation à distance (Kill Switch)
        if status == "disabled" or status == "deprecated":
            print()
            draw_box(
                [
                    f"{C.RED}{C.BOLD}Cette application a été temporairement désactivée.{C.RST}",
                    f"",
                    f"{C.WHITE}{msg}{C.RST}" if msg else f"{C.GRAY}Veuillez contacter l'administrateur.{C.RST}"
                ],
                title="Service Suspendu",
                border_color=C.RED
            )
            print()
            sys.exit(1)
            
        # 2. Comparaison de version
        def parse_ver(v):
            return [int(x) for x in re.sub(r'[^\d.]', '', v).split('.')]
            
        try:
            if parse_ver(current_version) < parse_ver(min_ver):
                print()
                draw_box(
                    [
                        f"{C.RED}{C.BOLD}Mise à jour obligatoire requise !{C.RST}",
                        f"",
                        f"{C.GRAY}Votre version actuelle : {C.RED}{current_version}{C.RST}",
                        f"{C.GRAY}Version minimale requise : {C.GREEN}{min_ver}{C.RST}",
                        f"",
                        f"{C.WHITE}{msg if msg else 'Veuillez mettre à jour pour continuer.'}{C.RST}"
                    ],
                    title="Mise à jour requise",
                    border_color=C.RED
                )
                print()
                sys.exit(1)
        except Exception:
            pass
            
        # 3. Notification de mise à jour disponible
        try:
            if parse_ver(current_version) < parse_ver(latest):
                print()
                draw_box(
                    [
                        f"{C.YELLOW}{C.BOLD}Une mise à jour de StreeIO est disponible ! ({latest}){C.RST}",
                        f"",
                        f"{C.GRAY}Version actuelle : {current_version}{C.RST}",
                        f"",
                        f"{C.WHITE}Mettez à jour avec : {C.CYAN}pip install --upgrade git+https://github.com/AdamZoda/stremio.git{C.RST}"
                    ],
                    title="Mise à jour disponible",
                    border_color=C.YELLOW
                )
                print()
        except Exception:
            pass
            
    except Exception:
        # Si hors-ligne ou erreur, on continue
        pass


def show_welcome():
    """Écran d'accueil complet avec auto-setup."""
    clear_screen()
    draw_header()
    print()

    # ── Auto-installation si nécessaire ──
    if not first_launch_setup():
        sys.exit(1)

    # ── Vérification des mises à jour à distance ──
    check_for_updates()

    # ── Affichage de l'environnement ──
    dl_folder = get_download_folder()
    ff_ok = check_ffmpeg()

    draw_status("🐍", "Python", f"{sys.version.split()[0]}", value_color=C.GREEN)
    draw_status("📦", "yt-dlp", "installé", value_color=C.GREEN)
    draw_status(
        "🎞️ ", "FFmpeg",
        "disponible" if ff_ok else "non trouvé (audio seul)",
        value_color=C.GREEN if ff_ok else C.YELLOW
    )
    draw_status("📂", "Destination", str(dl_folder), value_color=C.PURPLE)

    print()
    draw_divider()

    return dl_folder


def fetch_info(url):
    """Récupère les métadonnées de la vidéo."""
    import yt_dlp

    spinner = Spinner("Récupération des métadonnées...", color=C.BLUE)
    spinner.start()

    opts = {
        'quiet': True,
        'no_warnings': True,
        'noplaylist': True,
    }

    try:
        with yt_dlp.YoutubeDL(opts) as ydl:
            info = ydl.extract_info(url, download=False)
        spinner.stop(success=True, message="Métadonnées récupérées")
    except Exception as e:
        spinner.stop(success=False, message=f"Erreur : {e}")
        return None

    return info


def display_video_info(info):
    """Affiche les métadonnées de la vidéo dans un panneau."""
    title = info.get('title', 'Inconnu')
    channel = info.get('uploader', info.get('channel', 'Inconnu'))
    duration = info.get('duration', 0)
    views = info.get('view_count', 0)

    # Formatage de la durée
    if duration:
        mins, secs = divmod(int(duration), 60)
        hours, mins = divmod(mins, 60)
        if hours:
            dur_str = f"{hours}h {mins:02d}m {secs:02d}s"
        else:
            dur_str = f"{mins}m {secs:02d}s"
    else:
        dur_str = "Inconnue"

    # Formatage des vues
    if views:
        if views >= 1_000_000:
            views_str = f"{views / 1_000_000:.1f}M vues"
        elif views >= 1_000:
            views_str = f"{views / 1_000:.1f}K vues"
        else:
            views_str = f"{views} vues"
    else:
        views_str = "—"

    # Troncature du titre si trop long
    max_title = term_width() - 20
    if len(title) > max_title:
        title = title[:max_title - 3] + "..."

    lines = [
        f"{C.WHITE}{C.BOLD}{title}{C.RST}",
        f"",
        f"{C.GRAY}Chaîne    {C.RST}  {C.WHITE}{channel}{C.RST}",
        f"{C.GRAY}Durée     {C.RST}  {C.CYAN}{dur_str}{C.RST}",
        f"{C.GRAY}Vues      {C.RST}  {C.PURPLE}{views_str}{C.RST}",
    ]

    print()
    draw_box(lines, title="Vidéo trouvée", border_color=C.CYAN)


def run_download(url, mode, dl_folder):
    """Lance le téléchargement avec barre de progression."""
    import yt_dlp

    progress = ProgressDisplay()

    opts = {
        'outtmpl': str(dl_folder / '%(title)s.%(ext)s'),
        'noplaylist': True,
        'quiet': True,
        'no_warnings': True,
        'progress_hooks': [progress.hook],
    }

    local_dir = get_local_bin_dir()
    ext = ".exe" if sys.platform == "win32" else ""
    if (local_dir / f"ffmpeg{ext}").exists():
        opts['ffmpeg_location'] = str(local_dir)

    if mode == "audio":
        opts.update({
            'format': 'bestaudio/best',
            'postprocessors': [{
                'key': 'FFmpegExtractAudio',
                'preferredcodec': 'mp3',
                'preferredquality': '320',
            }]
        })
    else:
        opts.update({
            'format': 'bestvideo[height<=1080]+bestaudio/best',
            'merge_output_format': 'mp4',
        })

    draw_step("↓", f"Téléchargement {'Audio MP3 320kbps' if mode == 'audio' else 'Vidéo MP4 1080p'}",
              color=C.MAGENTA)
    print()

    try:
        with yt_dlp.YoutubeDL(opts) as ydl:
            ydl.download([url])

        draw_success(f"Fichier sauvegardé dans : {dl_folder}")

    except Exception as e:
        draw_error(str(e))
        return False

    return True


def show_help():
    """Affiche l'aide."""
    print()
    lines = [
        f"{C.WHITE}{C.BOLD}Commandes disponibles :{C.RST}",
        f"",
        f"  {C.CYAN}stream{C.RST}  {C.DARK}│{C.RST}  {C.GRAY}Lancer un nouveau téléchargement{C.RST}",
        f"  {C.CYAN}help{C.RST}    {C.DARK}│{C.RST}  {C.GRAY}Afficher cette aide{C.RST}",
        f"  {C.CYAN}clear{C.RST}   {C.DARK}│{C.RST}  {C.GRAY}Effacer l'écran{C.RST}",
        f"  {C.CYAN}info{C.RST}    {C.DARK}│{C.RST}  {C.GRAY}Infos sur l'environnement{C.RST}",
        f"  {C.CYAN}quit{C.RST}    {C.DARK}│{C.RST}  {C.GRAY}Quitter StreeIO{C.RST}",
        f"",
        f"{C.DARK}Vous pouvez aussi coller directement une URL.{C.RST}",
    ]
    draw_box(lines, title="Aide", border_color=C.BLUE)
    print()


def show_info():
    """Affiche les infos système."""
    dl_folder = get_download_folder()
    ff_ok = check_ffmpeg()
    print()
    draw_status("🐍", "Python", sys.version.split()[0], value_color=C.GREEN)
    draw_status("📦", "yt-dlp", "installé", value_color=C.GREEN)
    draw_status("🎞️ ", "FFmpeg", "oui" if ff_ok else "non", value_color=C.GREEN if ff_ok else C.YELLOW)
    draw_status("📂", "Destination", str(dl_folder), value_color=C.PURPLE)
    draw_status("💻", "Terminal", f"{term_width()}×{shutil.get_terminal_size().lines}", value_color=C.GRAY)
    draw_status("🖥️ ", "OS", sys.platform, value_color=C.GRAY)
    print()


def interactive_download(initial_url=None):
    """Flux de téléchargement interactif."""
    dl_folder = get_download_folder()

    # ── Étape 1 : URL ──
    if initial_url:
        url = initial_url
        print(f"\n  {C.CYAN}›{C.RST}  {C.GRAY}URL détectée :{C.RST} {C.WHITE}{url}{C.RST}")
    else:
        draw_step("1", "Collez l'URL de la vidéo")
        url = prompt("URL")

    if not url:
        draw_error("URL vide ou invalide.")
        return

    # ── Récupération des infos ──
    info = fetch_info(url)
    if not info:
        return

    display_video_info(info)

    # ── Étape 2 : Choix du format ──
    draw_step("2", "Choisissez le format de sortie")
    print()
    draw_option("1", "🎵", "Audio MP3", "320 kbps — Musique, Podcasts")
    draw_option("2", "🎬", "Vidéo MP4", "1080p HD — Clips, Tutoriels")
    print()

    choice = prompt("Votre choix", default="2")
    mode = "audio" if choice == "1" else "video"

    # ── Étape 3 : Confirmation ──
    fmt_label = f"{C.MAGENTA}Audio MP3 320kbps{C.RST}" if mode == "audio" else f"{C.CYAN}Vidéo MP4 1080p{C.RST}"
    print()
    draw_divider("─", C.DARK)
    draw_info(f"Format : {fmt_label}")
    draw_info(f"Destination : {C.PURPLE}{dl_folder}{C.RST}")
    draw_divider("─", C.DARK)

    confirm = prompt("Lancer le téléchargement ? (O/n)", default="O")
    if confirm.lower() in ("n", "non", "no"):
        draw_warning("Téléchargement annulé.")
        return

    # ── Étape 4 : Téléchargement ──
    run_download(url, mode, dl_folder)


def is_url(text):
    """Vérifie si un texte ressemble à une URL."""
    return bool(re.match(r'https?://', text, re.IGNORECASE))


# ──────────────────────────────────────────────────────────────
# BOUCLE REPL INTERACTIVE
# ──────────────────────────────────────────────────────────────

def repl():
    """Boucle interactive style Claude Code."""
    dl_folder = show_welcome()
    print()
    draw_info("Tapez une commande ou collez une URL. Tapez 'help' pour l'aide.")
    print()

    while True:
        try:
            cmd = input(f"  {C.CYAN}{C.BOLD}streeio{C.RST} {C.DARK}›{C.RST} ").strip()
        except (EOFError, KeyboardInterrupt):
            print(f"\n\n  {C.GRAY}À bientôt ! 👋{C.RST}\n")
            break

        if not cmd:
            continue

        cmd_lower = cmd.lower()

        if cmd_lower in ("quit", "exit", "q"):
            print(f"\n  {C.GRAY}À bientôt ! 👋{C.RST}\n")
            break
        elif cmd_lower == "help":
            show_help()
        elif cmd_lower == "clear":
            clear_screen()
            draw_header()
            print()
        elif cmd_lower == "info":
            show_info()
        elif cmd_lower == "stream":
            interactive_download()
            print()
        elif is_url(cmd):
            interactive_download(initial_url=cmd)
            print()
        else:
            draw_warning(f"Commande inconnue : '{cmd}'. Tapez 'help' pour l'aide.")
            print()


# ──────────────────────────────────────────────────────────────
# MODE UNE COMMANDE (arguments CLI)
# ──────────────────────────────────────────────────────────────

def oneshot():
    """Mode exécution directe avec arguments."""
    url = sys.argv[1]

    dl_folder = show_welcome()

    # Détection du mode via flags
    mode = "video"
    if "--audio" in sys.argv or "-a" in sys.argv or "--mp3" in sys.argv:
        mode = "audio"
    elif "--video" in sys.argv or "-v" in sys.argv or "--mp4" in sys.argv:
        mode = "video"

    info = fetch_info(url)
    if not info:
        sys.exit(1)

    display_video_info(info)
    run_download(url, mode, dl_folder)
    print()


# ──────────────────────────────────────────────────────────────
# POINT D'ENTRÉE
# ──────────────────────────────────────────────────────────────

def main():
    # Si des arguments sont passés, mode one-shot
    if len(sys.argv) > 1:
        arg = sys.argv[1]
        if arg in ("--help", "-h"):
            clear_screen()
            draw_header()
            print()
            lines = [
                f"{C.WHITE}{C.BOLD}Usage :{C.RST}",
                f"",
                f"  {C.CYAN}streeio{C.RST}                      {C.GRAY}Mode interactif (REPL){C.RST}",
                f"  {C.CYAN}streeio{C.RST} {C.WHITE}<url>{C.RST}                {C.GRAY}Télécharger une vidéo (MP4){C.RST}",
                f"  {C.CYAN}streeio{C.RST} {C.WHITE}<url>{C.RST} {C.YELLOW}--audio{C.RST}        {C.GRAY}Télécharger en audio (MP3){C.RST}",
                f"  {C.CYAN}streeio{C.RST} {C.WHITE}<url>{C.RST} {C.YELLOW}--video{C.RST}        {C.GRAY}Télécharger en vidéo (MP4){C.RST}",
                f"",
                f"{C.DARK}Alias : -a (audio), -v (vidéo), --mp3, --mp4{C.RST}",
            ]
            draw_box(lines, title="StreeIO CLI — Aide", border_color=C.BLUE)
            print()
            sys.exit(0)
        elif arg in ("--version", "-V"):
            print(f"{C.CYAN}StreeIO{C.RST} {C.GRAY}v4.3.0{C.RST}")
            sys.exit(0)
        elif is_url(arg):
            oneshot()
        else:
            draw_error(f"Argument non reconnu : '{arg}'")
            print(f"  {C.GRAY}Utilisez --help pour voir les options.{C.RST}\n")
            sys.exit(1)
    else:
        # Mode interactif
        repl()


if __name__ == "__main__":
    main()
