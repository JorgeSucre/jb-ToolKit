# 🍺 JB Toolkit

JB Toolkit es una suite de mantenimiento, diagnóstico, optimización y despliegue para macOS desarrollada por JB Repair.

Diseñada para técnicos, consultores de TI y usuarios avanzados, permite automatizar tareas comunes de soporte, mejorar el rendimiento del sistema y generar documentación técnica de forma rápida y consistente.

---

# ✨ Características

## 🔍 Diagnóstico del sistema

- Análisis de CPU, RAM y almacenamiento
- Detección de procesos con alto consumo
- Identificación de archivos grandes
- Evaluación de salud del sistema
- Compatibilidad con Intel y Apple Silicon
- Inventario detallado de hardware

## 🧹 Mantenimiento y optimización

- Limpieza de cachés de usuario y sistema
- Limpieza de logs
- Limpieza de Homebrew
- Eliminación de archivos temporales
- Optimización de configuraciones de macOS
- Gestión de elementos de inicio

## 📄 Reportes profesionales

JB Toolkit genera automáticamente:

- Reportes ejecutivos PDF
- Inventarios completos del sistema
- Logs de sesión para soporte técnico

Archivos generados:

text logs/session_YYYY-MM-DD_HH-MM-SS.log logs/system_snapshot_YYYY-MM-DD_HH-MM-SS.txt logs/jb_report_YYYY-MM-DD_HH-MM-SS.pdf 

## 🍺 Gestión inteligente de Homebrew

- Instalación automática de Homebrew
- Compatibilidad Intel y Apple Silicon
- Detección y reparación de instalaciones incompletas
- Actualización automática de fórmulas y casks
- Soporte para versiones antiguas de macOS cuando es posible

## 🧠 Recomendaciones según hardware

JB Toolkit detecta automáticamente el equipo y ofrece aplicaciones recomendadas
según el modelo, definidas como datos en el catálogo:

### MacBook Air / MacBook Pro

- AlDente

### MacBook Pro, Mac mini, Mac Studio e iMac

- Macs Fan Control

### Mac mini, Mac Studio y equipos con pantallas externas

- BetterDisplay

---

# 💻 Compatibilidad

Compatible con:

- Intel Macs
- Apple Silicon (M1, M2, M3 y M4)

Versiones recomendadas:

- macOS Monterey
- macOS Ventura
- macOS Sonoma
- macOS Sequoia
- macOS Tahoe

---

# 📋 Requisitos

- Conexión a internet
- Terminal.app o iTerm2
- Permisos administrativos recomendados
- Al menos 2 GB de espacio libre para operaciones de mantenimiento

---

# 🚀 Instalación

Clona el repositorio:

bash git clone https://github.com/JorgeSucre/jb-ToolKit.git 

Ingresa al directorio:

bash cd jb-ToolKit 

Otorga permisos de ejecución:

bash chmod +x jb chmod +x core/*.sh chmod +x core/bootstrap/*.sh 

---

# ▶️ Uso

Inicia siempre la herramienta utilizando el launcher principal:

bash ./jb 

o

bash bash jb 

---

# ⚠️ Importante

No ejecutes módulos individuales directamente:

text bootstrap.sh diagnostics.sh maintenance.sh report.sh 

El launcher:

- Inicializa correctamente el entorno
- Gestiona dependencias
- Controla navegación entre módulos
- Maneja errores
- Genera logs y snapshots
- Mantiene compatibilidad entre componentes

---

# 🛠️ Módulos

## 1. Bootstrap

Asistente de preparación inicial del equipo:

- Command Line Tools y Homebrew
- Herramientas base verificadas (fastfetch)
- Actualización opcional de paquetes pendientes
- Detección de hardware y recomendaciones según el modelo
- Asistente de despliegue: una pregunta — ¿cómo se usará este Mac? — y el
  resto lo resuelve el módulo Deployment (mismo catálogo, mismo planificador,
  mismo instalador)

---

## 2. Diagnostics

Analiza:

- CPU
- RAM
- Almacenamiento
- Red
- Procesos
- Estado general del sistema
- Hardware instalado

Genera un Health Score para facilitar la evaluación rápida del equipo.

---

## 3. Maintenance

Realiza:

- Limpieza de cachés
- Limpieza de logs
- Limpieza Homebrew
- Optimización de configuraciones
- Recuperación de espacio en disco

Todas las acciones quedan registradas para futuras referencias.

---

## 4. Deployment

Prepara equipos completos mediante un flujo único:

Catálogo → Aplicaciones → Aplicaciones seleccionadas → Plan de instalación → Ejecución

- Presets rápidos (Home, Office, Business, Engineering, Creative, Education,
  Technician, Developer): cada uno precarga una selección de aplicaciones que
  el técnico puede revisar, agregar o quitar libremente antes de instalar —
  no son un modo de ejecución aparte, solo un punto de partida
- Catálogo de aplicaciones agrupado por categoría (una aplicación, una
  categoría) con selección numerada continua
- JB Picks: recomendaciones curadas por JB Repair con su justificación,
  navegables desde el mismo catálogo
- Recomendaciones automáticas según el hardware detectado, incorporadas a la
  misma selección — nunca un flujo separado
- Revisión completa del plan y verificación previa (pre-flight) antes de
  cualquier cambio en el sistema
- Instalación aplicación por aplicación: un fallo nunca detiene el resto
- Aplicaciones sin soporte en Homebrew se reportan honestamente como
  "instalación manual requerida", con su página de descarga — nunca como fallos
- Resultado con desglose veraz: instaladas, ya instaladas, excluidas por
  compatibilidad, manuales y fallidas (con su motivo)

Cada despliegue queda documentado: el plan exportado y el registro de la
transacción se guardan en logs/ para soporte y auditoría.

---

## 5. Report

Genera un reporte ejecutivo en PDF con:

- Información del sistema
- Estado de salud
- Resultados de mantenimiento
- Resumen ejecutivo
- Inventario técnico

Ideal para entregar a clientes después de un servicio de mantenimiento.

---

# 📦 Aplicaciones del catálogo

Todo el software desplegable vive en el catálogo (`catalog/`): cada
aplicación pertenece a exactamente una categoría, y esa categoría es
puramente de navegación — nunca afecta cómo se instala. El catálogo actual
incluye:

### Utilidades

- AppCleaner
- Keka
- Rectangle
- OpenLogi
- Mole
- Android Platform Tools

### Hardware

- AlDente
- Macs Fan Control
- BetterDisplay
- Stats

### Productividad

- Microsoft Word
- Microsoft Excel
- OneDrive
- PDFgear (instalación manual — no disponible en Homebrew)
- ChatGPT

### Desarrollo

- Git
- Visual Studio Code
- Node.js
- pnpm
- Docker Desktop
- Codex
- Google Antigravity

### Redes

- Tailscale
- Wireshark
- Nmap
- Angry IP Scanner

### Multimedia

- Kdenlive
- GIMP

### Comunicación

- Discord

### Navegadores

- Floorp

Agregar una aplicación nueva es editar un archivo de texto en `catalog/` —
sin cambios de código. Ver [catalog/README.md](catalog/README.md).

---

# 📁 Estructura de artefactos

## Session Log

Registro detallado de la ejecución del toolkit.

text logs/session_*.log 

## System Snapshot

Inventario completo del sistema.

text logs/system_snapshot_*.txt 

Incluye:

- Hardware
- CPU
- RAM
- Almacenamiento
- Interfaces de red
- Pantallas conectadas
- Homebrew
- Fastfetch

## Executive PDF

Reporte orientado al cliente.

text logs/jb_report_*.pdf 

---

# 🔮 Roadmap

Próximas mejoras:

- Validación ampliada en Ventura Intel
- Más perfiles de hardware
- Soporte para plugins
- Integraciones remotas
- Reportes avanzados
- Automatización adicional para soporte técnico

---

# 👨‍💻 Autor

Desarrollado por JB Repair.

Especialistas en:

- Reparación Apple
- Optimización macOS
- Redes y conectividad
- Starlink
- Automatización
- Infraestructura tecnológica

---

# 📄 Licencia

MIT Lice
