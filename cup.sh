#!/bin/bash
set -euo pipefail
# cup
# Author: Centalia

SU="sudo"
PKG_MANAGER="pacman"

DB_DIR=$HOME/.cup
DB_PKGS=$DB_DIR/db.sqlite3

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

source "$SCRIPT_DIR/lib/db.sh"
source "$SCRIPT_DIR/lib/pkg.sh"
source "$SCRIPT_DIR/lib/git.sh"

cmd_modules(){
  local file
  local modules_dir=$SCRIPT_DIR/"modules"
  local module_file
  local module

  if [ -d "$modules_dir" ]; then
    for file in "$modules_dir"/*.sh; do
      if [ ! -f "$file" ]; then continue; fi
      module_file=${file##*/}
      module=${module_file%.sh}
      echo "==> Found Module $module"
    done
    else
      echo "==> Modules not found"
  fi
}

db_init

while [ -n "${1:-}" ]; do
case "$1" in
  install)
    shift
    cmd_install "$@" || exit 1
    set --
  ;;
  remove)
    shift
    cmd_remove "$1"
    shift
    ;;
  update)
    shift
    cmd_update
    ;;
  search)
    shift
    cmd_search "$@"
    set --
    ;;
  clean-cache)
    shift
    cmd_clean_cache
    ;;
  gitbuild)
    shift
    cmd_gitbuild "$@"
    set --
    ;;
  list)
    cmd_list
    set --
    ;;
  fix)
    cmd_fix
    set --
    ;;
  modules)
    cmd_modules
    set --
    ;;
  *)
    if [ -f "$SCRIPT_DIR/modules/$1.sh" ]; then
        source "$SCRIPT_DIR/modules/$1.sh"
        "cmd_install_$1"
    else
        echo "==> Error: Command '$1' not found"
        exit 1
    fi
    set --
    ;;
  esac
done
