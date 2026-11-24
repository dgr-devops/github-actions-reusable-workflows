#!/usr/bin/env bash
# Script mínimo usado como fixture de lint-shell.
set -euo pipefail

name="${1:-mundo}"
printf 'Hola, %s\n' "$name"
