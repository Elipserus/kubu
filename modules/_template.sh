# Plantilla de módulo. Copia este fichero como modules/<id>.sh
# (los que empiezan por "_" se ignoran).
#
# Lo más corto: un tipo declarativo (ver lib/kinds.sh)
#   MOD_APT=(paquete)  ·  MOD_FLATPAK=org.app.Id  ·  MOD_NPM=pkg MOD_BIN=bin
#   MOD_WEBAPP_URL=https://... MOD_WEBAPP_ICON=nombre
#
# O funciones propias, todas opcionales: el menú solo ofrece las que existan.
# Se ejecutan con `set -Eeuo pipefail` en un proceso aparte, con los helpers
# de lib/common.sh y lib/ui.sh (step, ok, warn, ui_input, apt_install...).

MOD_NAME="Mi app"
MOD_CATEGORY="Utilidades"
MOD_DESC="Descripción corta (sin comas)"
MOD_DEFAULT=0      # 1 = marcada por defecto en el asistente inicial
MOD_REQUIRED=0     # 1 = se instala siempre en el asistente (no se pregunta)
MOD_PRIORITY=50    # orden de instalación: menor primero

mod_is_installed() { pkg_installed mi-paquete; }

mod_install() {
  step "Instalando mi-paquete" apt_install mi-paquete
  mod_configure
}

mod_configure() {
  local valor
  valor=$(ui_input "Algún ajuste" "valor por defecto")
  ok "Configurado con $valor"
}

# Submenú en Configurar (opcional): "función|Etiqueta". Si existe, Configurar
# muestra mod_status arriba y estas opciones, más "Configuración básica"
# (mod_configure). Cada opción se ejecuta aparte: si falla, el menú sigue.
MOD_MENU=(
  "mi_estado|Ver el estado del servicio"
)

mod_status() {                       # líneas de estado: ui_status / ui_service
  ui_service "Servicio" mi-servicio.service
  ui_status "Versión" "1.0"
}

mi_estado() { systemctl status mi-servicio --no-pager | ui_view "Estado (q para salir)"; }

mod_update()    { step "Actualizando mi-paquete" apt_install --only-upgrade mi-paquete; }
mod_uninstall() { step "Eliminando mi-paquete" apt_purge mi-paquete; }
