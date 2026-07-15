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

JB Toolkit detecta automáticamente el equipo y adapta sus recomendaciones.

Ejemplos:

### MacBook Air

- AlDente
- ChatGPT
- Microsoft Office
- OneDrive

### Mac mini

- BetterDisplay
- Macs Fan Control
- Tailscale
- Herramientas de productividad

### Equipos con pantallas externas

- BetterDisplay

### Equipos compatibles con Android

- Android Platform Tools
- OpenJDK

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

Configura el sistema automáticamente:

- Homebrew
- Herramientas esenciales
- Aplicaciones recomendadas
- Dependencias técnicas
- Configuración inicial

Además permite instalar aplicaciones opcionales mediante selección interactiva.

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

Prepara equipos completos mediante perfiles de trabajo (beta — planificación):

- Perfiles por tipo de equipo: Home, Office, Professional, Technician, Developer
- Bundles reutilizables de aplicaciones seleccionadas por JB Repair
- JB Picks: recomendaciones curadas con su justificación
- Perfil personalizado combinando bundles
- Revisión completa del plan antes de cualquier cambio

La instalación automática del plan estará disponible en una próxima versión;
por ahora el módulo planifica y muestra exactamente qué se instalaría.

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

# 📦 Aplicaciones compatibles

Dependiendo del hardware y las preferencias del usuario, JB Toolkit puede instalar o actualizar:

### Productividad

- Microsoft Word
- Microsoft Excel
- OneDrive

### Desarrollo

- Visual Studio Code
- Codex
- Antigravity
- Node.js
- PNPM

### Inteligencia Artificial

- ChatGPT

### Android

- Android Platform Tools
- OpenJDK

### Comunicación

- Discord

### Multimedia

- Kdenlive
- GIMP

### Utilidades

- Tailscale
- BetterDisplay
- AlDente
- Macs Fan Control
- Logi Options+

### Navegadores

- Floorp

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
