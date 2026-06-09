from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle
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

# ===========================================================
# System snapshot reader
# ===========================================================

def read_snapshot():
    """
    Parse the system_snapshot_*.txt file recorded at session start.
    Returns a dict of key → value pairs from the snapshot.
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
# Fallback live queries (only used when snapshot is unavailable)
# ===========================================================

def _run(cmd, default="N/A"):
    try:
        return subprocess.check_output(cmd, text=True, stderr=subprocess.DEVNULL).strip()
    except (subprocess.SubprocessError, FileNotFoundError):
        return default

def _fallback_ram():
    """Compute used/total RAM as a last resort."""
    try:
        total_bytes = int(_run(["sysctl", "-n", "hw.memsize"], "0"))
        total_mb = total_bytes // (1024 * 1024)
        if total_mb <= 0:
            return "N/A"

        # Try memory_pressure first
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
        return f"{used_gb} GB / {total_gb} GB ({pct}%)"
    except Exception:
        return "N/A"

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

def _fallback_brew():
    """Return total installed Homebrew package count as a last resort."""
    brew = _run(["/bin/zsh", "-lc", "command -v brew"], "")
    if not brew:
        for candidate in ("/opt/homebrew/bin/brew", "/usr/local/bin/brew"):
            if os.path.exists(candidate):
                brew = candidate
                break
    if not brew:
        return "N/A"
    formulas = _run([brew, "list", "--formula"], "")
    casks = _run([brew, "list", "--cask"], "")
    f_count = len([l for l in formulas.splitlines() if l.strip()])
    c_count = len([l for l in casks.splitlines() if l.strip()])
    return f"{f_count} fórmulas, {c_count} casks"

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
# Data assembly — snapshot first, live fallback if missing
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

# RAM display: snapshot stores total GB; compute used from state or fallback
if ram_str != "N/A":
    # Snapshot has total RAM; for used/pct, derive from live query if needed
    ram_display_base = ram_str  # e.g. "16 GB"
    ram_live = _fallback_ram()
    # Use live data for used/total/pct; it is only queried once per PDF run
    ram_display = ram_live if ram_live != "N/A" else ram_str
else:
    ram_display = _fallback_ram()

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
else:
    if storage != "N/A":
        disk_display = storage
    else:
        disk_display = _fallback_disk()

# Homebrew summary
if formulas != "N/A" and casks != "N/A":
    brew_display = f"{formulas} fórmulas, {casks} casks"
elif brew_ver != "N/A":
    brew_display = brew_ver
else:
    brew_display = _fallback_brew()

# ===========================================================
# State values
# ===========================================================

score_before = get_state_value("SCORE_BEFORE")
score_after  = get_state_value("SCORE_AFTER")
freed_mb     = get_state_value("TOTAL_FREED_MB")
files_removed = get_state_value("FILES_REMOVED")
last_maint   = get_state_value("LAST_MAINTENANCE")

def is_missing_or_na(val):
    return val is None or val == "" or str(val).strip().upper() in ("N/A", "NULL")

if is_missing_or_na(last_maint):
    last_maint_display = "Maintenance no ejecutado"
else:
    last_maint_display = last_maint

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
        status = "🟢 Excelente"
    elif s >= 70:
        status = "🟡 Aceptable"
    else:
        status = "🔴 Requiere atención"
except (TypeError, ValueError):
    status = "N/A"

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

    status_style = ParagraphStyle(
        'StatusStyle',
        parent=styles['Normal'],
        fontSize=11,
        leading=13,
        alignment=1
    )

    content = []

    def section(title):
        content.append(Paragraph(f"<b>{title}</b>", styles["Heading2"]))
        content.append(Spacer(1, 8))

    def kv_table(data):
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

        table = Table(formatted_data, colWidths=[140, 300])
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
        content.append(Spacer(1, 8))
        content.append(Paragraph("<font color='#aaaaaa'>──────────────</font>", styles["Normal"]))
        content.append(Spacer(1, 8))

    # Header
    content.append(Paragraph("<b>JB Toolkit Report</b>", title_style))
    content.append(Spacer(1, 6))
    content.append(Paragraph("Reporte de estado y optimización del sistema", styles["Normal"]))
    content.append(Spacer(1, 10))

    # ----------------------------------------------------------
    # System information — consumed from snapshot
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
        ["Arquitectura", arch],
        ["Homebrew", brew_display],
    ]

    kv_table(system_data)
    separator()

    # ----------------------------------------------------------
    # Performance / score comparison
    # ----------------------------------------------------------
    section("Rendimiento del sistema")

    score_data = [
        ["Métrica", "Valor"],
        ["Score anterior", score_before],
        ["Score actual", str(score_after)],
    ]

    if score_before not in ("N/A", ""):
        if diff > 0:
            score_data.append(["Mejora", f"+{diff} puntos"])
        elif diff < 0:
            score_data.append(["Cambio", f"{diff} puntos"])
        else:
            score_data.append(["Cambio", "Sin cambios"])

    score_data.append(["Estado", status])

    kv_table(score_data)

    color = "black"
    if "Excelente" in status:
        color = "green"
    elif "Aceptable" in status:
        color = "orange"
    elif "Requiere" in status:
        color = "red"

    content.append(Paragraph(f"<b><font color='{color}'>{status}</font></b>", status_style))
    content.append(Spacer(1, 8))

    score_color = "#000000"
    if "Excelente" in status:
        score_color = "#2ecc71"
    elif "Aceptable" in status:
        score_color = "#f39c12"
    elif "Requiere" in status:
        score_color = "#e74c3c"

    content.append(Paragraph(
        f"<para align='center'><font size=14><b>{score_after}/100</b></font><br/>"
        f"<font size=10 color='{score_color}'>{status}</font></para>",
        styles["Normal"]
    ))
    content.append(Spacer(1, 8))

    separator()

    # ----------------------------------------------------------
    # Maintenance summary
    # ----------------------------------------------------------
    section("Resultados de mantenimiento")

    maint_data = [
        ["Acción", "Resultado"],
        ["Espacio liberado", freed_display],
        ["Archivos eliminados", files_removed_display],
        ["Última ejecución", last_maint_display],
    ]

    kv_table(maint_data)
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
    content.append(Spacer(1, 8))

    section("Detalles")
    kv_table([
        ["Campo", "Valor"],
        ["Generado por", "JB Toolkit"],
        ["Ruta del reporte", OUTPUT],
    ])

    doc.build(content)

    if os.path.exists(OUTPUT):
        print(f"📄 PDF generado en {OUTPUT}")
    else:
        print("❌ Error generando PDF")

except Exception as e:
    print("❌ Fallo en generación de PDF")
    print(e)
    sys.exit(1)
