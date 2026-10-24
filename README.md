# kubu

Kubuntu 26.04 a tu manera: un instalador y configurador al estilo
[Omakub](https://github.com/omacom/omakub), adaptado a KDE Plasma, con Ghostty
como terminal y una paleta naranja y azul.

## Instalación

En una instalación nueva de Kubuntu 26.04:

    curl -fsSL https://raw.githubusercontent.com/Elipserus/kubu/main/boot.sh | bash

O desde un clon: `bash install.sh`. El asistente te pregunta qué aplicaciones,
lenguajes y bases de datos quieres, tu nombre y email para git, y lo instala
todo de una vez. Después, abre el menú con `kubu`.

## El menú

- **Tema**: Kubu, Tokyo Night, Catppuccin, Nord, Everforest, Gruvbox, Kanagawa,
  Rosé Pine. Cambia Ghostty, btop, zellij, Neovim, VS Code, los colores de KDE y
  el fondo (también el de la pantalla de bloqueo).
- **Fuente**: Ubuntu Mono (por defecto), JetBrains Mono, Cascadia Mono, Fira Mono o Meslo (Nerd Fonts), y
  su tamaño en Ghostty.
- **Aplicaciones**: por categorías. Marca (x) para instalar, desmarca para
  desinstalar.
- **Configurar**: vuelve a aplicar la configuración de kubu a una app. SSH, Docker,
  Bases de datos, Ollama, GitHub CLI, Git, Virt Manager, Tailscale, Syncthing y
  Bitwarden tienen además su propio panel con el estado de sus servicios y opciones
  avanzadas (generar claves SSH y copiarlas a otro equipo, ver logs, arrancar o
  parar contenedores y VMs, conectarte a tu red Tailscale, hacer de Bitwarden el
  gestor de contraseñas de Brave...).
- **Escritorio** (en Aplicaciones › Sistema): barra superior con tu IP (clic: IP
  pública), Spotify (canción y controles) y uso de CPU/RAM; fecha en el
  escritorio; modo oscuro o claro; elegir las apps ancladas en la barra de
  tareas; quitar el brillo de la ventana activa. Las ventanas gelatinosas de
  Kubuntu vienen desactivadas.
- **Actualizar**: kubu (git pull + migraciones), el sistema o apps de fuera de apt.

También por comandos: `kubu list`, `kubu install brave vlc`, `kubu uninstall vlc`,
`kubu theme nord`, `kubu font "Fira Mono"`, `kubu atajos`, `kubu update`.

## Atajos

El asistente ofrece **Atajos de kubu** (marcado por defecto), que añade a KDE:

| Atajo                    | Qué hace                     |
|--------------------------|------------------------------|
| Meta+Intro · Ctrl+Alt+T  | Terminal (Ghostty)           |
| Meta+B                   | Navegador por defecto        |
| Meta+C                   | VS Code (si está instalado)  |
| Meta+Q (y Alt+F4)        | Cerrar la ventana            |
| Meta+F                   | Pantalla completa            |

Si una tecla ya la usaba otro atajo de KDE, se le quita solo esa tecla; al
desinstalar el módulo todo vuelve a como estaba. La chuleta completa (ventanas,
escritorios, pestañas...) sale al terminar la instalación, en el menú
**Atajos** y con `kubu atajos`. Otros atajos útiles:

| Dónde   | Atajo                  | Qué hace                     |
|---------|------------------------|------------------------------|
| Ghostty | ctrl+shift+n           | Nueva ventana                |
| Ghostty | ctrl+shift+t           | Nueva pestaña                |
| Ghostty | ctrl+shift+o / e       | Dividir a la derecha / abajo |
| Ghostty | alt+flechas            | Moverse entre paneles        |
| Ghostty | ctrl+shift+b           | Mostrar / ocultar los bordes |
| KDE     | Meta+arrastrar         | Mover una ventana sin bordes |
| KDE     | Meta+AvPág             | Minimizar la ventana         |
| KDE     | alt+espacio            | Buscar y abrir apps (KRunner)|
| Ghostty | ctrl+shift+,           | Recargar la configuración    |
| Zellij  | ctrl+g                 | Desbloquear modo normal      |
| Bash    | ctrl+r                 | Buscar en el historial (fzf) |

## Alias de terminal

`ls`/`lt` (eza), `cd` (zoxide), `ff` (fzf con vista previa), `n` (nvim),
`g` (git), `d` (docker), `lzg` (lazygit), `lzd` (lazydocker), `y` (yazi),
`gcm "mensaje"` (git commit -m), `compress`/`decompress`,
`web2app Nombre URL icono` para crear tus propias web apps.

## Añadir una aplicación

Crea `modules/<id>.sh`. Para un paquete de apt basta con:

    MOD_NAME="VLC"
    MOD_CATEGORY="Multimedia"
    MOD_DESC="Reproductor de vídeo"
    MOD_APT=(vlc)

Mira `modules/_template.sh` para el resto de opciones.

## Drivers

Si tu equipo necesita drivers privativos (sobre todo gráficas NVIDIA), el
asistente ofrece **Drivers**, marcado por defecto: instala los que recomienda
Ubuntu (los mismos de «Controladores adicionales»). Con gráficas Intel o AMD, o
en una máquina virtual, no aparece porque no hace falta.

## Máquinas virtuales

Si kubu detecta que corre en una VM (KVM/QEMU, VirtualBox, VMware o Hyper-V),
instala al principio las herramientas de invitado y prepara las carpetas
compartidas (VirtualBox: `/media/sf_*`; VMware: `/mnt/hgfs`). En una máquina
real este paso se omite. En Wayland, el portapapeles compartido puede no
funcionar según el hipervisor.

## Ficheros

- Log: `~/.local/state/kubu/kubu.log`
- Copias de seguridad: cada fichero que kubu reemplaza se guarda como `*.kubu-bak`
- Licencia: MIT, basado en Omakub (ver LICENSE)
