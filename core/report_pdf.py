from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib import colors
from datetime import datetime
import subprocess
import os
import sys

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STATE_FILE = os.path.join(BASE_DIR, "logs", "state.env")
def get_state_value(key):
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

timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
OUTPUT = os.path.join(BASE_DIR, "logs", f"jb_report_{timestamp}.pdf")
os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)

def get_output(cmd, default="N/A"):
    try:
        return subprocess.check_output(cmd, text=True, stderr=subprocess.DEVNULL).strip()
    except (subprocess.SubprocessError, FileNotFoundError):
        return default

def vm_stat_value(label):
    output = get_output(["vm_stat"], "")
    for line in output.splitlines():
        if label in line:
            return int(line.split()[-1].replace(".", ""))
    return 0

def memory_free_percent():
    output = get_output(["memory_pressure"], "")
    for line in output.splitlines():
        if "System-wide memory free percentage" in line:
            try:
                return int(line.split(":")[-1].strip().rstrip("%"))
            except ValueError:
                return None
    return None

def brew_package_count():
    brew = get_output(["/bin/zsh", "-lc", "command -v brew"], "")
    if not brew:
        for candidate in ("/opt/homebrew/bin/brew", "/usr/local/bin/brew"):
            if os.path.exists(candidate):
                brew = candidate
                break

    if not brew:
        return "0"

    output = get_output([brew, "list"], "")
    return str(len([line for line in output.splitlines() if line.strip()]))

def disk_usage_percent():
    output = get_output(["df", "-h", "/"], "")
    lines = output.splitlines()
    if len(lines) < 2:
        return 0

    for field in lines[1].split():
        if field.endswith("%"):
            try:
                return int(field.rstrip("%"))
            except ValueError:
                return 0
    return 0

def disk_summary():
    output = get_output(["df", "-h", "/"], "")
    lines = output.splitlines()
    return lines[1] if len(lines) > 1 else "N/A"

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
        alignment=1  # center
    )

    content = []

    def section(title):
        content.append(Paragraph(f"<b>{title}</b>", styles["Heading2"]))
        content.append(Spacer(1, 8))

    def kv_table(data):
        table = Table(data, colWidths=[140, 300])
        table.setStyle(TableStyle([
            ('BACKGROUND', (0,0), (-1,0), colors.lightgrey),
            ('TEXTCOLOR', (0,0), (-1,0), colors.black),
            ('GRID', (0,0), (-1,-1), 0.3, colors.grey),
            ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
            ('WORDWRAP', (0,0), (-1,-1), True),
            ('FONTNAME', (0,0), (-1,0), 'Helvetica-Bold'),
            ('FONTNAME', (0,1), (-1,-1), 'Helvetica'),
            ('BOTTOMPADDING', (0,0), (-1,-1), 8),
            ('TOPPADDING', (0,0), (-1,-1), 6),
        ]))
        content.append(table)
        content.append(Spacer(1, 8))

    def separator():
        content.append(Spacer(1, 8))
        content.append(Paragraph("<font color='#aaaaaa'>──────────────</font>", styles["Normal"]))
        content.append(Spacer(1, 8))

    content.append(Paragraph("<b>JB Toolkit Report</b>", title_style))
    content.append(Spacer(1, 6))
    content.append(Paragraph("Reporte de estado y optimización del sistema", styles["Normal"]))
    content.append(Spacer(1, 10))

    # RAM cálculo consistente
    try:
        page_size = 4096
        total_bytes = int(get_output(["sysctl", "-n", "hw.memsize"], "0"))
        total_mb = total_bytes // (1024 * 1024)
        free_percent = memory_free_percent()

        if free_percent is not None and total_mb > 0:
            used_mb = total_mb * (100 - free_percent) // 100
        else:
            free_pages = vm_stat_value("Pages free")
            speculative_pages = vm_stat_value("Pages speculative")
            free_mb = ((free_pages + speculative_pages) * page_size) // (1024 * 1024)
            used_mb = total_mb - free_mb

        ram_pct = int((used_mb * 100) / total_mb) if total_mb > 0 else 0
    except (TypeError, ValueError):
        used_mb = 0
        total_mb = 0
        ram_pct = 0

    section("Información del sistema")

    system_data = [
        ["Campo", "Valor"],
        ["Fecha", datetime.now().strftime("%Y-%m-%d %H:%M:%S")],
        ["Modelo", get_output(["sysctl", "-n", "hw.model"])],
        ["CPU", get_output(["sysctl", "-n", "hw.brand_string"]) or get_output(["sysctl", "-n", "machdep.cpu.brand_string"])],
        ["RAM", f"{used_mb} MB / {total_mb} MB ({ram_pct}%)"],
        ["Disco", disk_summary()],
        ["Homebrew paquetes", brew_package_count()]
    ]

    kv_table(system_data)
    separator()

    # Score comparison
    score_before = get_state_value("SCORE_BEFORE")
    score_after = get_state_value("SCORE_AFTER")

    try:
        diff = int(score_after) - int(score_before) if score_before != "N/A" else 0
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

    section("Rendimiento del sistema")

    score_data = [
        ["Métrica", "Valor"],
        ["Score anterior", score_before],
        ["Score actual", str(score_after)],
    ]

    if score_before != "N/A":
        if diff > 0:
            score_data.append(["Mejora", f"+{diff} puntos"])
        elif diff < 0:
            score_data.append(["Cambio", f"{diff} puntos"])
        else:
            score_data.append(["Cambio", "Sin cambios"])

    score_data.append(["Estado", status])

    kv_table(score_data)

    # Highlight status
    color = "black"
    if "Excelente" in status:
        color = "green"
    elif "Aceptable" in status:
        color = "orange"
    elif "Requiere" in status:
        color = "red"

    content.append(Paragraph(f"<b><font color='{color}'>{status}</font></b>", status_style))
    content.append(Spacer(1, 8))

    # Score visual card
    content.append(Spacer(1, 8))

    score_color = "#000000"
    if "Excelente" in status:
        score_color = "#2ecc71"
    elif "Aceptable" in status:
        score_color = "#f39c12"
    elif "Requiere" in status:
        score_color = "#e74c3c"

    content.append(Paragraph(
        f"<para align='center'><font size=14><b>{score_after}/100</b></font><br/><font size=10 color='{score_color}'>{status}</font></para>",
        styles["Normal"]
    ))
    content.append(Spacer(1, 8))

    separator()

    # =========================
    # Maintenance summary
    # =========================

    freed_mb = get_state_value("TOTAL_FREED_MB")
    files_removed = get_state_value("FILES_REMOVED")

    # Convert MB to GB if large
    try:
        freed_mb_int = int(freed_mb)
        if freed_mb_int >= 1024:
            freed_display = f"{round(freed_mb_int / 1024, 2)} GB"
        else:
            freed_display = f"{freed_mb_int} MB"
    except (TypeError, ValueError):
        freed_display = "N/A"

    timestamp = get_state_value("TIMESTAMP")

    section("Resultados de mantenimiento")

    maint_data = [
        ["Acción", "Resultado"],
        ["Espacio liberado", freed_display],
        ["Archivos eliminados", files_removed],
        ["Última ejecución", timestamp]
    ]

    kv_table(maint_data)
    separator()

    # =========================
    # Resumen
    # =========================

    summary_text = "Se optimizó el sistema eliminando archivos innecesarios, liberando espacio en disco y mejorando el rendimiento general."

    try:
        if score_before != "N/A":
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
        ["Ruta del reporte", OUTPUT]
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
