#!/usr/bin/env bash
# Ejecuta una acción de un módulo en un proceso aislado.
# Así cada módulo puede definir las mismas funciones (mod_install, ...) sin
# pisarse, y `set -e` funciona dentro aunque el llamador use `if` o `||`.
#
# Uso: runner.sh <id_módulo> <info|install|uninstall|configure|update>
#      runner.sh <id_módulo> run <función>   (una opción de MOD_MENU)
set -Eeuo pipefail

: "${KUBU_ROOT:?KUBU_ROOT no definido}"
source "$KUBU_ROOT/lib/common.sh"
source "$KUBU_ROOT/lib/ui.sh"
source "$KUBU_ROOT/lib/kinds.sh"

id=$1 action=$2
file="$KUBU_ROOT/modules/$id.sh"
[[ -f $file ]] || die "Módulo desconocido: $id"

MOD_ID=$id
# shellcheck source=/dev/null
source "$file"
kind_apply_defaults

# Opciones del submenú: "Configuración básica" (mod_configure) + MOD_MENU
menu_entries() {
  declare -F mod_configure >/dev/null && echo "mod_configure|Configuración básica"
  [[ -n ${MOD_MENU+x} ]] && printf '%s\n' "${MOD_MENU[@]}"
  return 0
}

# Submenú del módulo: estado arriba (mod_status) y una opción por línea.
# Cada opción se ejecuta en su propio runner para que un fallo no cierre el menú.
menu_loop() {
  local e choice
  local -A fns=()
  local -a labels=()
  while IFS= read -r e; do
    fns[${e#*|}]=${e%%|*}
    labels+=("${e#*|}")
  done < <(menu_entries)
  while true; do
    ui_header
    ui_section "$MOD_NAME" "${MOD_DESC:-}"
    if declare -F mod_status >/dev/null; then echo; mod_status || true; fi
    echo
    choice=$(ui_choose "¿Qué quieres hacer?" "${labels[@]}" "<< Volver") || return 0
    [[ $choice == "<< Volver" ]] && return 0
    echo
    bash "$KUBU_ROOT/lib/runner.sh" "$id" run "${fns[$choice]}" || err "No se pudo completar: $choice"
    ui_pause
  done
}

case $action in
  info)
    flags=()
    for a in install uninstall configure update; do
      declare -F "mod_$a" >/dev/null && flags+=(1) || flags+=(0)
    done
    # configure = 2: el módulo tiene submenú propio
    [[ -n ${MOD_MENU+x} ]] && flags[2]=2
    installed=0
    mod_is_installed 2>/dev/null && installed=1
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$id" "$MOD_NAME" "${MOD_CATEGORY:-Otros}" \
      "${MOD_DESC:-}" "${flags[@]}" "$installed" "${MOD_REQUIRED:-0}" "${MOD_DEFAULT:-0}" "${MOD_PRIORITY:-50}"
    ;;
  run)
    fn=${3:-}
    menu_entries | cut -d'|' -f1 | grep -qx -- "$fn" || die "$MOD_NAME no tiene la opción '$fn'"
    "$fn"
    ;;
  configure)
    if [[ -n ${MOD_MENU+x} && -z ${KUBU_FIRST_RUN:-} ]]; then
      menu_loop
    else
      declare -F mod_configure >/dev/null || die "$MOD_NAME no soporta 'configure'"
      mod_configure
    fi
    ;;
  *)
    declare -F "mod_$action" >/dev/null || die "$MOD_NAME no soporta '$action'"
    "mod_$action"
    ;;
esac
