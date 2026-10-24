#!/usr/bin/env bash
# Herramientas de invitado para quien instaló kubu en una VM antes de que
# existiera el módulo vm-guest. En una máquina real no hace nada.
set -Eeuo pipefail
source "$KUBU_ROOT/lib/common.sh"

in_vm || exit 0
# Hipervisor sin soporte: el módulo no ofrece instalación
[[ $(bash "$KUBU_ROOT/lib/runner.sh" vm-guest info | cut -f5) == 1 ]] || exit 0
bash "$KUBU_ROOT/lib/runner.sh" vm-guest info | cut -f9 | grep -qx 1 && exit 0
bash "$KUBU_ROOT/lib/runner.sh" vm-guest install
