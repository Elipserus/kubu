#!/usr/bin/env bash
# Instalación en una línea:
#   curl -fsSL https://raw.githubusercontent.com/Elipserus/kubu/main/boot.sh | bash
set -Eeuo pipefail

KUBU_REPO="${KUBU_REPO:-https://github.com/Elipserus/kubu.git}"
KUBU_REF="${KUBU_REF:-main}"
KUBU_PATH="$HOME/.local/share/kubu"

printf '\033[38;5;208m%s\033[0m\n' ' ____  __.     ___.' '|    |/ _|__ _\_ |__  __ __' '|      < |  |  \ __ \|  |  \'
printf '\033[38;5;33m%s\033[0m\n'  '|    |  \|  |  / \_\ \  |  /' '|____|__ \____/|___  /____/' '        \/         \/'
echo
echo "=> kubu es para instalaciones nuevas de Kubuntu 26.04"
echo -e "\nEmpezando (o cancela con ctrl+c)..."

if [[ $EUID -eq 0 ]]; then
  echo "Ejecútalo como tu usuario normal: kubu usará sudo cuando lo necesite." >&2
  exit 1
fi

sudo apt-get update -qq
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq git curl >/dev/null

echo "Clonando kubu..."
rm -rf "$KUBU_PATH"
git clone -q --branch "$KUBU_REF" "$KUBU_REPO" "$KUBU_PATH"

# Con `curl | bash` stdin es la tubería: el asistente necesita el terminal
if [[ ! -t 0 ]] && { : </dev/tty; } 2>/dev/null; then
  exec bash "$KUBU_PATH/install.sh" </dev/tty
fi
exec bash "$KUBU_PATH/install.sh"
