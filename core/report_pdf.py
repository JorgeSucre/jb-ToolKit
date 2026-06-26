from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, HRFlowable
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib import colors
from datetime import datetime
import subprocess
import os
import sys

# ===========================================================
# Paths
# ===========================================================

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STATE_FILE = os.path.join(BASE_DIR, "logs", "state.env")

# ===========================================================
# State helpers
# ===========================================================

def get_state_value(key):
    """Read a value from logs/state.env by key."""
    if not os.path.exists(STATE_FILE):
        return "N/A"
    try:
        with open(STATE_FILE) as f:
            for line in f:
                if line.startswith(f"{key}="):
                    return line.strip().split("=", 1)[1]
    except OSError:
        pass
    return "N/A"

def is_missing_or_na(val):
    return val is None or val == "" or str(val).strip().upper() in ("N/A", "NULL")

# ===========================================================
# System snapshot reader
# ===========================================================

def read_snapshot():
    """
    Parse the system_snapshot_*.txt file recorded at session start.
    Returns a dict of key -> value pairs from the snapshot.
    Snapshot format:  Key: value
    """
    snapshot_basename = get_state_value("LAST_SYSTEM_SNAPSHOT")
    if snapshot_basename == "N/A":
        return {}

    snapshot_path = os.path.join(BASE_DIR, "logs", snapshot_basename)
    if not os.path.exists(snapshot_path):
        return {}

    data = {}
    try:
        with open(snapshot_path) as f:
            for line in f:
                if ": " in line:
                    key, _, value = line.partition(": ")
                    data[key.strip()] = value.strip()
    except OSError:
        pass
    return data

# ===========================================================
# Fallback live queries (only used when snapshot/state is missing)
# ===========================================================

def _run(cmd, default="N/A"):
    try:
        return subprocess.check_output(cmd, text=True, stderr=subprocess.DEVNULL).strip()
    except (subprocess.SubprocessError, FileNotFoundError):
        return default

def _fallback_ram_components():
    """Best-effort live RAM read. Returns (used_gb, total_gb, pct) or None."""
    try:
        total_bytes = int(_run(["sysctl", "-n", "hw.memsize"], "0"))
        total_mb = total_bytes // (1024 * 1024)
        if total_mb <= 0:
            return None

        mp_out = _run(["memory_pressure"], "")
        free_pct = None
        for line in mp_out.splitlines():
            if "System-wide memory free percentage" in line:
                try:
                    free_pct = int(line.split(":")[-1].strip().rstrip("%"))
                except ValueError:
                    pass
                break

        if free_pct is not None:
            used_mb = total_mb * (100 - free_pct) // 100
        else:
            vm = _run(["vm_stat"], "")
            def _vm_val(label):
                for l in vm.splitlines():
                    if label in l:
                        try:
                            return int(l.split()[-1].replace(".", ""))
                        except ValueError:
                            return 0
                return 0
            free_pages = _vm_val("Pages free") + _vm_val("Pages speculative")
            free_mb = (free_pages * 4096) // (1024 * 1024)
            used_mb = total_mb - free_mb

        used_gb = round(used_mb / 1024, 1)
        total_gb = total_mb // 1024
        pct = int(used_mb * 100 / total_mb) if total_mb > 0 else 0
        return used_gb, total_gb, pct
    except Exception:
        return None

def _fallback_disk():
    """Return disk summary as a last resort."""
    out = _run(["df", "-H", "/"], "")
    lines = out.splitlines()
    if len(lines) < 2:
        return "N/A"
    parts = lines[1].split()
    if len(parts) >= 5:
        size = parts[1].replace("G", " GB").replace("M", " MB").replace("T", " TB")
        used = parts[2].replace("G", " GB").replace("M", " MB").replace("T", " TB")
        pct = parts[4]
        return (
            f"Capacidad total: {size}<br/>"
            f"Espacio utilizado: {used}<br/>"
            f"Uso del disco: {pct}"
        )
    return "N/A"

def _fallback_brew_counts():
    """Return (formula_count, cask_count) from a live brew query, or None."""
    brew = _run(["/bin/zsh", "-lc", "command -v brew"], "")
    if not brew:
        for candidate in ("/opt/homebrew/bin/brew", "/usr/local/bin/brew"):
            if os.path.exists(candidate):
                brew = candidate
                break
    if not brew:
        return None
    formulas = _run([brew, "list", "--formula"], "")
    casks = _run([brew, "list", "--cask"], "")
    f_count = len([l for l in formulas.splitlines() if l.strip()])
    c_count = len([l for l in casks.splitlines() if l.strip()])
    return f_count, c_count

# ===========================================================
# Client-friendly formatting helpers
# ===========================================================
# These exist so the same wording is produced whether the data came from
# the snapshot/state (preferred) or a live fallback query — clients only
# ever see one consistent phrasing.

def format_ram(total_gb, used_gb, pct):
    return (
        f"RAM total: {total_gb} GB<br/>"
        f"RAM utilizada: {used_gb} GB ({pct}% en uso)"
    )

def format_homebrew(formula_count, cask_count):
    total = formula_count + cask_count
    cmd_word = "herramienta de línea de comandos" if formula_count == 1 else "herramientas de línea de comandos"
    cask_word = "aplicación instalada" if cask_count == 1 else "aplicaciones instaladas"
    return (
        f"{total} herramientas instaladas mediante Homebrew<br/>"
        f"({formula_count} {cmd_word}, {cask_count} {cask_word})"
    )

ARCH_DISPLAY_NAMES = {
    "arm64": "Apple Silicon",
    "x86_64": "Intel",
}

def format_arch(raw_arch):
    return ARCH_DISPLAY_NAMES.get(raw_arch, raw_arch)

# ===========================================================
# Application inventory (bridged from the shared bash detection layer)
# ===========================================================
# report.sh computes this using detect_app_state()/compute_hardware_
# recommendations() — the same functions Bootstrap uses — and passes the
# result through JB_APP_INVENTORY so detection logic is never duplicated
# here. Format per line: "Label|state:method".

def parse_app_inventory():
    raw = os.environ.get("JB_APP_INVENTORY", "")
    items = []
    for line in raw.splitlines():
        if "|" not in line:
            continue
        label, _, state_method = line.partition("|")
        state, _, method = state_method.partition(":")
        label = label.strip()
        if not label:
            continue
        items.append((label, state.strip(), method.strip()))
    return items

# ===========================================================
# Session install inventory (bridged from JB_INSTALLED_APPS_SESSION)
# ===========================================================
# report.sh resolves package ids from state.env's INSTALLED_APPS_SESSION
# (written by Bootstrap — see bootstrap.sh/packages.sh) into display
# labels and passes them here newline-separated, so this file never needs
# its own copy of the id -> label catalog.

def parse_installed_session():
    raw = os.environ.get("JB_INSTALLED_APPS_SESSION", "")
    return [line.strip() for line in raw.splitlines() if line.strip()]

# ===========================================================
# Privacy inventory (bridged from JB_PRIVACY_INVENTORY / JB_FILEVAULT_STATUS)
# ===========================================================
# Detection only, computed once by core/diagnostics.sh and persisted to
# state.env (FILEVAULT_STATUS, PRIVACY_INVENTORY) — report.sh resolves
# those into environment variables for this script the same way it
# already bridges JB_APP_INVENTORY. Never re-detected here.

def parse_privacy_inventory():
    raw = os.environ.get("JB_PRIVACY_INVENTORY", "")
    items = []
    for line in raw.splitlines():
        line = line.strip()
        if not line or "|" not in line:
            continue
        label, _, state = line.partition("|")
        label = label.strip()
        if not label:
            continue
        items.append((label, state.strip()))
    return items

# ===========================================================
# Executive Recommendations (bridged from JB_RECOMMENDATIONS)
# ===========================================================
# report.sh computes the candidate list and priority weights by reading
# state.env values already collected elsewhere — no new detection, no
# recalculation here. Already capped at 5 entries by report.sh.

def parse_recommendations():
    raw = os.environ.get("JB_RECOMMENDATIONS", "")
    items = []
    for line in raw.splitlines():
        line = line.strip()
        if not line or "|" not in line:
            continue
        _, _, text = line.partition("|")
        text = text.strip()
        if text:
            items.append(text)
    return items

# ===========================================================
# Maintenance history (read directly — flat file, no database)
# ===========================================================
# core/maintenance/state.sh appends one line per completed run:
# "timestamp|profile|score_after". Read the same way state.env/the
# snapshot are read: directly from the shared file, never recalculated.

HISTORY_FILE = os.path.join(BASE_DIR, "logs", "maintenance_history.log")

def read_maintenance_history(limit=5):
    """Return up to `limit` most recent (timestamp, profile, score) entries."""
    if not os.path.exists(HISTORY_FILE):
        return []
    entries = []
    try:
        with open(HISTORY_FILE) as f:
            for line in f:
                line = line.strip()
                if not line or "|" not in line:
                    continue
                parts = line.split("|")
                if len(parts) != 3:
                    continue
                entries.append(tuple(parts))
    except OSError:
        return []
    return list(reversed(entries))[:limit]

def inventory_status_text(state, method):
    if state == "installed":
        if method == "manual":
            return "Instalada (instalación manual)"
        if method == "app-store":
            return "Instalada (App Store)"
        return "Instalada"
    if state == "update":
        return "Actualización disponible"
    return "No instalada"

# ===========================================================
# Output path
# ===========================================================

timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
OUTPUT = os.environ.get(
    "JB_PDF_OUTPUT",
    os.path.join(BASE_DIR, "logs", f"jb_report_{timestamp}.pdf")
)
os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)

# ===========================================================
# Data assembly — snapshot/state first, live fallback if missing
# ===========================================================

snapshot = read_snapshot()

def snap(key, fallback="N/A"):
    return snapshot.get(key, fallback)

# Hardware
model    = snap("Model")
cpu      = snap("CPU")
ram_str  = snap("RAM")      # e.g. "16 GB"
storage  = snap("Storage")  # e.g. "245G total, 96G used..."
arch     = snap("Architecture")
uptime   = snap("Uptime")
brew_ver = snap("Homebrew")
formulas = snap("Installed formulas")
casks    = snap("Installed casks")
macos    = snap("macOS")

# RAM: prefer the already-collected total (snapshot) + usage percentage
# (state.env, written by Diagnostics) over recalculating live — only
# fall back to a live query when one of those is unavailable.
ram_display = None

ram_total_gb = None
if ram_str != "N/A":
    try:
        ram_total_gb = int(float(ram_str.split()[0]))
    except (ValueError, IndexError):
        ram_total_gb = None

ram_used_pct = get_state_value("RAM_USED_PCT")

if ram_total_gb is not None and not is_missing_or_na(ram_used_pct):
    try:
        pct = int(ram_used_pct)
        used_gb = round(ram_total_gb * pct / 100, 1)
        ram_display = format_ram(ram_total_gb, used_gb, pct)
    except ValueError:
        ram_display = None

if ram_display is None:
    components = _fallback_ram_components()
    if components:
        used_gb, total_gb, pct = components
        ram_display = format_ram(total_gb, used_gb, pct)
    else:
        ram_display = "RAM: información no disponible"

# Disk
capacidad = snap("Capacidad total")
utilizado = snap("Espacio utilizado")
uso = snap("Uso del disco")

if capacidad != "N/A" and utilizado != "N/A" and uso != "N/A":
    disk_display = (
        f"Capacidad total: {capacidad}<br/>"
        f"Espacio utilizado: {utilizado}<br/>"
        f"Uso del disco: {uso}"
    )
elif storage != "N/A":
    disk_display = storage
else:
    disk_display = _fallback_disk()

# Homebrew summary
brew_display = None
try:
    brew_display = format_homebrew(int(formulas), int(casks))
except (TypeError, ValueError):
    brew_display = None

if brew_display is None:
    counts = _fallback_brew_counts()
    if counts:
        brew_display = format_homebrew(*counts)
    elif brew_ver != "N/A":
        brew_display = brew_ver
    else:
        brew_display = "Homebrew no disponible"

arch_display = format_arch(arch) if arch != "N/A" else "N/A"

# ===========================================================
# State values
# ===========================================================

score_before = get_state_value("SCORE_BEFORE")
score_after  = get_state_value("SCORE_AFTER")
freed_mb     = get_state_value("TOTAL_FREED_MB")
files_removed = get_state_value("FILES_REMOVED")
last_maint   = get_state_value("LAST_MAINTENANCE")
performance_profile = get_state_value("PERFORMANCE_PROFILE")

if is_missing_or_na(last_maint):
    last_maint_display = "Maintenance no ejecutado"
else:
    last_maint_display = last_maint

if is_missing_or_na(performance_profile) or performance_profile == "none":
    profile_display = "Ningún perfil aplicado"
else:
    profile_display = performance_profile

try:
    if is_missing_or_na(freed_mb):
        freed_display = "No se realizaron tareas de mantenimiento"
    else:
        freed_int = int(freed_mb)
        freed_display = f"{round(freed_int / 1024, 2)} GB" if freed_int >= 1024 else f"{freed_int} MB"
except (TypeError, ValueError):
    freed_display = "No se realizaron tareas de mantenimiento"

if is_missing_or_na(files_removed):
    files_removed_display = "Sin resultados de mantenimiento en esta sesión"
else:
    files_removed_display = files_removed

try:
    diff = int(score_after) - int(score_before) if score_before not in ("N/A", "") else 0
except (TypeError, ValueError):
    diff = 0

try:
    s = int(score_after)
    if s >= 90:
        status = "Excelente"
    elif s >= 70:
        status = "Aceptable"
    else:
        status = "Requiere atención"
except (TypeError, ValueError):
    status = "N/A"

app_inventory = parse_app_inventory()
installed_session = parse_installed_session()
maintenance_history = read_maintenance_history()
privacy_inventory = parse_privacy_inventory()
filevault_status = os.environ.get("JB_FILEVAULT_STATUS", "N/A")
recommendations = parse_recommendations()
recommendations_priority = os.environ.get("JB_RECOMMENDATIONS_PRIORITY", "")
network_download = os.environ.get("JB_NETWORK_DOWNLOAD", "N/A")
network_upload = os.environ.get("JB_NETWORK_UPLOAD", "N/A")
network_latency = os.environ.get("JB_NETWORK_LATENCY", "N/A")

# ===========================================================
# PDF rendering
# ===========================================================

try:
    doc = SimpleDocTemplate(OUTPUT, rightMargin=25, leftMargin=25, topMargin=25, bottomMargin=25)
    styles = getSampleStyleSheet()

    title_style = ParagraphStyle(
        'TitleStyle',
        parent=styles['Title'],
        fontSize=16,
        leading=18,
        alignment=1
    )

    content = []

    def section(title):
        content.append(Paragraph(f"<b>{title}</b>", styles["Heading2"]))
        content.append(Spacer(1, 8))

    def kv_table(data, col_widths=None):
        formatted_data = []
        formatted_data.append(data[0]) # Header row
        for row in data[1:]:
            formatted_row = []
            for cell in row:
                if isinstance(cell, str):
                    cell_html = cell.replace("\n", "<br/>")
                    formatted_row.append(Paragraph(cell_html, styles["Normal"]))
                else:
                    formatted_row.append(cell)
            formatted_data.append(formatted_row)

        table = Table(formatted_data, colWidths=col_widths or [140, 300])
        table.setStyle(TableStyle([
            ('BACKGROUND', (0,0), (-1,0), colors.lightgrey),
            ('TEXTCOLOR', (0,0), (-1,0), colors.black),
            ('GRID', (0,0), (-1,-1), 0.3, colors.grey),
            ('VALIGN', (0,0), (-1,-1), 'TOP'),
            ('WORDWRAP', (0,0), (-1,-1), True),
            ('BOTTOMPADDING', (0,0), (-1,-1), 8),
            ('TOPPADDING', (0,0), (-1,-1), 6),
        ]))
        content.append(table)
        content.append(Spacer(1, 8))

    def separator():
        # A drawn rule, not a row of Unicode dash characters — renders
        # identically in every PDF viewer because it uses PDF line-drawing
        # operators instead of relying on a font glyph that the base
        # Helvetica font does not actually contain.
        content.append(Spacer(1, 6))
        content.append(HRFlowable(width="100%", thickness=0.6, color=colors.HexColor("#cccccc")))
        content.append(Spacer(1, 10))

    # Header
    content.append(Paragraph("<b>JB Toolkit Report</b>", title_style))
    content.append(Spacer(1, 6))
    content.append(Paragraph("Reporte de estado y optimización del sistema", styles["Normal"]))
    content.append(Spacer(1, 10))

    # ----------------------------------------------------------
    # Estado general del equipo — leads with the verdict, in line
    # with how a technician would open an in-person report.
    # ----------------------------------------------------------
    section("Estado general del equipo")

    if status == "N/A":
        content.append(Paragraph(
            "<para align='center'>Ejecuta Diagnostics para calcular el estado del sistema.</para>",
            styles["Normal"]
        ))
        content.append(Spacer(1, 10))
        score_data = None
    else:
        score_color = "#000000"
        if status == "Excelente":
            score_color = "#2ecc71"
        elif status == "Aceptable":
            score_color = "#f39c12"
        elif status == "Requiere atención":
            score_color = "#e74c3c"

        content.append(Paragraph(
            f"<para align='center'><font size=22><b>{score_after}/100</b></font><br/>"
            f"<font size=12 color='{score_color}'><b>{status}</b></font></para>",
            styles["Normal"]
        ))
        content.append(Spacer(1, 10))

        score_data = [["Métrica", "Valor"]]
        if score_before not in ("N/A", ""):
            score_data.append(["Score anterior", score_before])
        score_data.append(["Score actual", str(score_after)])

        if score_before not in ("N/A", ""):
            if diff > 0:
                score_data.append(["Mejora", f"+{diff} puntos"])
            elif diff < 0:
                score_data.append(["Cambio", f"{diff} puntos"])
            else:
                score_data.append(["Cambio", "Sin cambios"])

    if score_data is not None:
        kv_table(score_data)
    separator()

    # ----------------------------------------------------------
    # System information — consumed from snapshot/state
    # ----------------------------------------------------------
    section("Información del sistema")

    system_data = [
        ["Campo", "Valor"],
        ["Fecha", datetime.now().strftime("%Y-%m-%d %H:%M:%S")],
        ["Modelo", model],
        ["macOS", macos],
        ["CPU", cpu],
        ["RAM", ram_display],
        ["Disco", disk_display],
        ["Arquitectura", arch_display],
        ["Software instalado", brew_display],
    ]

    # Optional — only present once Diagnostics has run an (opt-in) speed
    # test at least once; never measured here.
    if network_download != "N/A":
        system_data.append([
            "Velocidad de internet",
            f"Descarga: {network_download} Mbps<br/>"
            f"Subida: {network_upload} Mbps<br/>"
            f"Latencia: {network_latency} ms",
        ])

    kv_table(system_data)
    separator()

    # ----------------------------------------------------------
    # Maintenance summary
    # ----------------------------------------------------------
    section("Resultados de mantenimiento")

    maint_data = [
        ["Acción", "Resultado"],
        ["Perfil aplicado", profile_display],
        ["Espacio liberado", freed_display],
        ["Archivos eliminados", files_removed_display],
        ["Última ejecución", last_maint_display],
    ]

    kv_table(maint_data)
    separator()

    # ----------------------------------------------------------
    # Application inventory — concise, hardware-relevant only.
    # Omitted entirely when there is nothing to show (e.g. no
    # hardware-specific recommendation applies to this Mac), rather
    # than rendering an empty or "no data" section.
    # ----------------------------------------------------------
    if app_inventory:
        section("Aplicaciones recomendadas")

        inventory_data = [["Aplicación", "Estado"]]
        for label, state, method in app_inventory:
            inventory_data.append([label, inventory_status_text(state, method)])

        kv_table(inventory_data)
        separator()

    # ----------------------------------------------------------
    # Session install inventory — only packages that actually went from
    # not-installed to installed/updated during this Bootstrap run.
    # Omitted entirely when nothing was installed this session.
    # ----------------------------------------------------------
    if installed_session:
        section("Software instalado durante esta sesión")

        for label in installed_session:
            content.append(Paragraph(f"✓ {label}", styles["Normal"]))
        content.append(Spacer(1, 8))
        separator()

    # ----------------------------------------------------------
    # Privacy Inventory — detection only, computed once by Diagnostics.
    # Omitted entirely when Diagnostics hasn't run yet (no state for
    # either FileVault or the vendor inventory).
    # ----------------------------------------------------------
    if filevault_status != "N/A" or privacy_inventory:
        section("Privacy Inventory")

        privacy_data = [["Elemento", "Estado"]]
        if filevault_status != "N/A":
            privacy_data.append(["FileVault", filevault_status])
        for label, state in privacy_inventory:
            privacy_data.append([label, state])

        kv_table(privacy_data)
        separator()

    # ----------------------------------------------------------
    # Overall Recommendation — pure synthesis, already capped at 5 items
    # and pre-sorted by priority in report.sh. Omitted entirely when no
    # candidate applied (a genuinely healthy, recently-maintained Mac).
    # ----------------------------------------------------------
    if recommendations:
        section("Overall Recommendation")

        # Plain "N/5" rather than Unicode star glyphs — the base Helvetica
        # font ReportLab uses here doesn't contain the star character (the
        # same class of issue already documented for separator() above),
        # so this avoids rendering as a missing-glyph box in the PDF.
        if recommendations_priority:
            content.append(Paragraph(
                f"<para align='center'><font size=14><b>Priority: {recommendations_priority}/5</b></font></para>",
                styles["Normal"]
            ))
            content.append(Spacer(1, 8))

        for rec in recommendations:
            content.append(Paragraph(f"- {rec}", styles["Normal"]))
        content.append(Spacer(1, 8))
        separator()

    # ----------------------------------------------------------
    # Recent maintenance history — last 5 completed runs, newest first.
    # Read directly from the flat history file; omitted entirely the
    # first time Maintenance has ever run (file doesn't exist yet).
    # ----------------------------------------------------------
    if maintenance_history:
        section("Historial reciente de mantenimiento")

        history_data = [["Fecha", "Perfil", "Score"]]
        for hist_timestamp, hist_profile, hist_score in maintenance_history:
            history_data.append([hist_timestamp, hist_profile, hist_score])

        kv_table(history_data, col_widths=[160, 140, 140])
        separator()

    # ----------------------------------------------------------
    # Summary
    # ----------------------------------------------------------
    maintenance_performed = False

    try:
        freed_int = int(freed_mb) if not is_missing_or_na(freed_mb) else 0
        removed_int = int(files_removed) if not is_missing_or_na(files_removed) else 0
        maintenance_performed = freed_int > 0 or removed_int > 0
    except (TypeError, ValueError):
        maintenance_performed = False

    if maintenance_performed:
        summary_text = (
            "Se optimizó el sistema eliminando archivos innecesarios, "
            "liberando espacio en disco y mejorando el rendimiento general."
        )
    else:
        summary_text = (
            "Se verificó el estado general del sistema. "
            "No fue necesario realizar tareas de limpieza adicionales."
        )

    try:
        if score_before not in ("N/A", ""):
            if diff > 10:
                summary_text += " Se detectó una mejora significativa en el rendimiento."
            elif diff > 0:
                summary_text += " Se detectó una mejora ligera en el sistema."
            elif diff < 0:
                summary_text += " Se detectó una ligera degradación en el rendimiento."
    except (TypeError, ValueError):
        pass

    section("Resumen")
    content.append(Paragraph(summary_text, styles["Normal"]))
    content.append(Spacer(1, 10))
    content.append(Paragraph(
        "<font size=8 color='#888888'>Reporte generado automáticamente por JB Toolkit.</font>",
        styles["Normal"]
    ))

    # ----------------------------------------------------------
    # Footer metadata. JB_VERSION is exported once, by core/utils.sh
    # ("export JB_VERSION=...") — the single source of truth every module
    # (banner, state.env, snapshot, this PDF) reads from; never hardcoded
    # here.
    # ----------------------------------------------------------
    jb_version = os.environ.get("JB_VERSION", "N/A")
    generated_at = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    content.append(Spacer(1, 4))
    content.append(Paragraph(
        f"<font size=8 color='#888888'>Generated: {generated_at}<br/>"
        f"Toolkit Version: {jb_version}</font>",
        styles["Normal"]
    ))

    doc.build(content)

    if os.path.exists(OUTPUT):
        print(f"PDF generado en {OUTPUT}")
    else:
        print("Error generando PDF")

except Exception as e:
    print("Fallo en generación de PDF")
    print(e)
    sys.exit(1)
