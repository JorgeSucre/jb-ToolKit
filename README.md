# 🍺 JB Toolkit

JB Toolkit es una suite de mantenimiento, diagnóstico, optimización y despliegue para macOS desarrollada por JB Repair.

Diseñada para técnicos, consultores de TI y usuarios avanzados, permite automatizar tareas comunes de soporte, optimizar equipos, instalar herramientas recomendadas y generar documentación técnica profesional.

---

## ✨ Características

### 🔍 Diagnóstico avanzado

- Análisis de CPU, RAM y almacenamiento
- Detección de procesos con alto consumo
- Identificación de archivos grandes
- Evaluación de salud del sistema
- Compatibilidad Intel y Apple Silicon
- Inventario detallado de hardware

### 🧹 Mantenimiento y optimización

- Limpieza de cachés y logs
- Limpieza de Homebrew
- Eliminación de archivos temporales
- Optimizaciones de macOS
- Gestión de elementos de inicio
- Recuperación de espacio en disco

### 📄 Reportes profesionales

- Reporte ejecutivo PDF
- Health Score
- Resumen de mantenimiento
- Inventario técnico del sistema

### 📚 Biblioteca técnica de referencia (offline)

JB Toolkit incluye una base de conocimiento técnico para todas las herramientas soportadas. No es solo un catálogo de aplicaciones: enseña a usarlas.

Cada guía documenta:

- Qué hace la herramienta y cuándo usarla
- Comandos útiles con explicación (para herramientas CLI)
- Flujo de trabajo paso a paso
- Problemas comunes y su solución (troubleshooting)
- Dependencias con otras herramientas
- Casos reales de uso en soporte técnico (JB Repair Use Cases)

Además incluye:

- Categorías — explorar herramientas agrupadas por tipo
- Recomendados para este Mac — sugerencias según hardware detectado, reutilizando el mismo motor de recomendaciones de Initial Setup
- Buscar — búsqueda offline por nombre, paquete o palabra clave

Toda la documentación se encuentra en:

```text
references/tools/*.md
```

Cada herramienta es un archivo Markdown con un pequeño encabezado de metadatos (`title`, `category`, `package`, `install_method`, `keywords`, y opcionalmente `recommended_profiles` / `recommend_reason` / `website`) seguido del contenido. Agregar una nueva herramienta solo requiere:

1. Crear `references/tools/<herramienta>.md` con el encabezado y las secciones de la plantilla.
2. Nada más — la herramienta aparece automáticamente en su categoría, en la búsqueda y, si aplica, en las recomendaciones por hardware.

No hay listas ni `case` estáticos que mantener: el menú, la búsqueda y las recomendaciones se generan leyendo los metadatos de los archivos.

### 🍺 Gestión inteligente de Homebrew

- Instalación automática de Homebrew
- Compatibilidad Intel y Apple Silicon
- Detección y reparación de instalaciones incompletas
- Actualización automática de fórmulas y casks
- Soporte para versiones antiguas de macOS cuando es posible

### 🧠 Recomendaciones según hardware

JB Toolkit detecta automáticamente el equipo y adapta sus recomendaciones.

Ejemplos:

#### MacBook Air

- AlDente
- ChatGPT
- Microsoft Office
- OneDrive

#### Mac mini

- BetterDisplay
- Macs Fan Control
- Tailscale
- Herramientas de productividad

#### Equipos con pantallas externas

- BetterDisplay

#### Equipos compatibles con Android

- Android Platform Tools
- OpenJDK

---

## 💻 Compatibilidad

### Arquitecturas soportadas

- Intel Macs
- Apple Silicon (M1, M2, M3 y M4)

### Versiones recomendadas

- macOS Monterey
- macOS Ventura
- macOS Sonoma
- macOS Sequoia
- macOS Tahoe

---

## 🚀 Instalación

```bash
git clone https://github.com/JorgeSucre/jb-ToolKit.git

cd jb-ToolKit

chmod +x jb
chmod +x core/*.sh
chmod +x core/bootstrap/*.sh
```

---

## ▶️ Uso

Inicia siempre el toolkit mediante:

```bash
./jb
```

- **Recomendados para este Mac**: sugerencias basadas en el hardware detectado (reutiliza el mismo motor de detección que Initial Setup)
- **Buscar**: búsqueda offline por nombre, paquete o palabra clave

Todo funciona completamente sin conexión a internet.

### 🍺 Gestión inteligente de Homebrew

- Instalación automática
- Reparación de instalaciones incompletas
- Compatibilidad Intel y Apple Silicon
- Actualización automática de paquetes
- Detección de entornos existentes

### 🧠 Recomendaciones según hardware

JB Toolkit detecta automáticamente el equipo y adapta sus recomendaciones.

Ejemplos:

- MacBook Air → AlDente
- Mac mini → BetterDisplay y Macs Fan Control
- Equipos Android → Platform Tools y Scrcpy
- Equipos de soporte técnico → RustDesk, OpenBoardView y LocalSend

---

## ⚠️ Importante

No ejecutes directamente los módulos individuales:

```text
bootstrap.sh
diagnostics.sh
maintenance.sh
report.sh
docs.sh
```

El launcher principal:

- Inicializa el entorno
- Gestiona dependencias
- Controla la navegación
- Maneja errores
- Genera logs y snapshots
- Mantiene compatibilidad entre módulos

---

## 🏗️ Arquitectura

```text
jb
├── Bootstrap
├── Diagnostics
├── Maintenance
├── Report
└── Documentation

references/
└── tools/

logs/
├── session_*.log
├── system_snapshot_*.txt
└── jb_report_*.pdf
```

---

## 🛠️ Módulos

### 1. Initial Setup

Configura automáticamente:

- Homebrew
- Herramientas esenciales
- Dependencias recomendadas
- Aplicaciones opcionales
- Configuración inicial

Antes de instalar aplicaciones opcionales, permite revisar su documentación integrada.

---

### 2. Diagnostics

Analiza:

- CPU
- RAM
- Almacenamiento
- Red
- Procesos
- Hardware instalado
- Estado general del sistema

Genera un Health Score para facilitar la evaluación rápida del equipo.

---

### 3. Maintenance

Realiza:

- Limpieza de cachés
- Limpieza de logs
- Limpieza de Homebrew
- Optimización de configuraciones
- Recuperación de espacio en disco

Todas las acciones quedan registradas para futuras referencias.

---

### 4. Report

Genera un reporte ejecutivo PDF con:

- Información del sistema
- Estado de salud
- Resultados de mantenimiento
- Resumen ejecutivo
- Inventario técnico

---

### 5. Documentation — Technical Reference Library

Biblioteca técnica integrada, no solo un catálogo de instalación.

Categorías disponibles:

- Productivity
- Development
- AI
- Android
- Networking
- Repair & Diagnostics
- Monitoring
- Utilities
- Multimedia

Cada guía sigue una plantilla estándar (ver `references/tools/_template.md`):

```text
## What is it?
## When should I use it?
## Recommended for
## Useful Commands
## Workflow
## Troubleshooting
## Dependencies
## JB Repair Use Cases
## References
```

Funciones del módulo:

- **Categorías** — explorar herramientas agrupadas por tipo
- **Recomendados para este Mac** — sugerencias según el hardware detectado, reutilizando el mismo motor de recomendaciones de Initial Setup
- **Buscar** — búsqueda offline por nombre, paquete o palabra clave

Toda la documentación se encuentra en:

```text
references/tools/*.md
```

Cada herramienta es un archivo Markdown con un pequeño encabezado de metadatos (`title`, `category`, `package`, `install_method`, `keywords`, y opcionalmente `recommended_profiles` / `recommend_reason` / `website`) seguido del contenido. Agregar una nueva herramienta solo requiere:

1. Crear `references/tools/<herramienta>.md` con el encabezado y las secciones de la plantilla.
2. Nada más — la herramienta aparece automáticamente en su categoría, en la búsqueda y, si aplica, en las recomendaciones por hardware.

No hay listas ni `case` estáticos que mantener: el menú, la búsqueda y las recomendaciones se generan leyendo los metadatos de los archivos.

---

## 📦 Aplicaciones compatibles

### Productividad

- Microsoft Word
- Microsoft Excel
- OneDrive

### Desarrollo

- Visual Studio Code
- Codex
- Claude Code
- Antigravity
- Node.js
- PNPM

### Inteligencia Artificial

- ChatGPT
- Claude

### Android

- Android Platform Tools
- Scrcpy
- OpenJDK

### Redes y diagnóstico

- Nmap
- iPerf3
- Speedtest CLI
- Smartmontools
- WakeOnLan
- RustDesk

### Reparación y soporte técnico

- OpenBoardView
- RustDesk
- LocalSend

### Multimedia

- FFmpeg
- yt-dlp
- Kdenlive
- GIMP

### Utilidades

- Tailscale
- BetterDisplay
- AlDente
- Macs Fan Control
- Stats
- Logi Options+

### Navegadores

- Floorp

### Recuperación e imágenes

- Balena Etcher

---

## 📁 Archivos generados

### Session Log

```text
logs/session_YYYY-MM-DD_HH-MM-SS.log
```

Registro detallado de ejecución.

### System Snapshot

```text
logs/system_snapshot_YYYY-MM-DD_HH-MM-SS.txt
```

Inventario técnico completo del sistema.

### Executive PDF

```text
logs/jb_report_YYYY-MM-DD_HH-MM-SS.pdf
```

Reporte ejecutivo orientado al cliente.

---

## 📚 Documentation — Technical Reference Library

JB Toolkit incluye una biblioteca técnica offline, pensada para enseñar a usar cada herramienta, no solo para listar aplicaciones instalables.

Las guías explican:

- Qué hace cada herramienta y cuándo utilizarla
- Comandos útiles, con ejemplos explicados
- Flujo de trabajo paso a paso
- Problemas comunes y su solución
- Dependencias con otras herramientas
- Casos reales de soporte técnico (JB Repair Use Cases)

El módulo también ofrece:

- **Recomendados para este Mac**, basado en el mismo motor de detección de hardware que usa Initial Setup
- **Búsqueda offline** por nombre, paquete o palabra clave

Ubicación:

```text
references/tools/*.md
references/tools/_template.md   (plantilla estándar)
```

---

## 🔮 Roadmap

- Mejor soporte para Ventura Intel
- Más perfiles de hardware
- Sistema de plugins
- Catálogo ampliado de herramientas
- Integración con Skills
- Integración con References
- Automatización avanzada para soporte técnico
- Reportes avanzados
- Documentación ampliada

---

## 👨‍💻 Autor

Desarrollado por JB Repair.

Especialistas en:

- Reparación Apple
- Optimización macOS
- Soporte técnico
- Redes
- Starlink
- Automatización

---

## 📄 Licencia

MIT License
