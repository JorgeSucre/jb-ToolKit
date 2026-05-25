🍺 JB Toolkit

JB Toolkit es una suite de mantenimiento, diagnóstico y optimización para macOS creada por  jb.repair￼.

Está diseñada para:

* limpiar sistemas macOS
* automatizar tareas comunes
* diagnosticar problemas
* optimizar rendimiento
* instalar herramientas útiles automáticamente
* generar reportes técnicos simples

Todo desde una interfaz rápida en Terminal, pensada tanto para técnicos como para usuarios avanzados.

⸻

✨ Características

* 🔍 Diagnóstico completo del sistema
* 🧹 Limpieza automática de cachés y logs
* ⚡ Optimización de rendimiento macOS
* 🍺 Integración inteligente con Homebrew
* 🧠 Detección automática Intel / Apple Silicon
* 🌡️ Detección de hardware y ventiladores
* 🔋 Optimización para laptops y desktops
* 📦 Instalación automática de herramientas esenciales
* 📄 Exportación de reportes
* ☁️ Detección de iCloud Drive
* 🖥️ Interfaz simple y rápida en Terminal

⸻

🧠 Arquitectura

El proyecto ahora utiliza una estructura modular:

core/
├── bootstrap.sh
├── diagnostics.sh
├── maintenance.sh
├── report.sh
├── utils.sh
└── bootstrap/
    ├── brew.sh
    ├── hardware.sh
    ├── packages.sh
    ├── stages.sh
    └── ui.sh

Esto permite:

* mantenimiento más sencillo
* código reutilizable
* mejor estabilidad
* escalabilidad futura

⸻

💻 Requisitos

* macOS Monterey o superior recomendado
* Conexión a internet
* Permisos administrativos (recomendado)
* Terminal.app o iTerm2

Compatible con:

* Intel Macs
* Apple Silicon (M1/M2/M3/M4)

⸻

▶️ Instalación

Clona el repositorio:

git clone https://github.com/JorgeSucre/jb-ToolKit.git

Entra al directorio:

cd jb-ToolKit

Da permisos de ejecución:

chmod +x jb
chmod +x core/*.sh
chmod +x core/bootstrap/*.sh

⸻

▶️ Cómo ejecutar JB Toolkit

La forma correcta de iniciar la herramienta es:

./jb

o:

bash jb

⸻

⚠️ IMPORTANTE

NO ejecutes directamente:

bootstrap.sh
maintenance.sh
diagnostics.sh

El launcher jb es quien:

* inicializa correctamente el entorno
* carga dependencias
* controla navegación
* maneja errores
* mantiene compatibilidad entre módulos

⸻

📦 Initial Setup

La primera ejecución puede:

* instalar Homebrew
* instalar herramientas CLI
* descargar dependencias
* sincronizar paquetes
* detectar hardware
* optimizar el sistema

La primera vez puede tardar varios minutos dependiendo de:

* conexión a internet
* velocidad del Mac
* arquitectura Intel / Apple Silicon

⸻

🛠️ Herramientas incluidas

Algunas herramientas que JB Toolkit puede instalar:

* htop
* btop
* ncdu
* dust
* fastfetch
* wget
* eza
* mac-cleanup-go

Y opcionalmente:

* navegador alternativo
* herramientas térmicas
* utilidades de batería

⸻

🔧 Funciones principales

1. Initial Setup

Configura automáticamente:

* Homebrew
* herramientas esenciales
* perfiles hardware
* optimizaciones base

⸻

2. Diagnostics

Analiza:

* CPU
* RAM
* disco
* procesos
* temperatura
* salud del sistema
* aplicaciones pesadas
* archivos grandes

⸻

3. Maintenance

Realiza:

* limpieza de cachés
* limpieza de logs
* limpieza Homebrew
* optimización de rendimiento
* detección de archivos innecesarios
* optimizaciones visuales macOS

⸻

4. Report

Genera reportes exportables del estado del sistema.

⸻

⚡ Optimización de rendimiento

Maintenance incluye perfiles de optimización:

1) Ligera (recomendado)
2) Agresiva
3) Restaurar valores por defecto

Puede:

* reducir animaciones
* reducir transparencias
* optimizar apps de inicio
* reducir procesos no esenciales
* minimizar telemetría

⸻

🧪 Estado actual del proyecto

JB Toolkit continúa en desarrollo activo.

Objetivos futuros:

* mejor reporting
* soporte extendido Apple Silicon
* automatización avanzada
* exportación PDF
* perfiles técnicos avanzados
* sistema de plugins

⸻

👨‍💻 Autor

Desarrollado por  jb.repair￼

Especialistas en:

* reparación Apple
* optimización macOS
* soporte técnico
* infraestructura
* automatización

⸻

📄 Licencia

MIT License.
