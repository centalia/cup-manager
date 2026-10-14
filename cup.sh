#!/bin/bash
set -euo pipefail
# cup
# Author: Centalia
# License: MIT

SU="sudo"
PKG_MANAGER="pacman"

DB_DIR=$HOME/.cup
DB_PKGS=$DB_DIR/db.sqlite3

db_init(){
  mkdir -p "$DB_DIR"
  sqlite3 "$DB_PKGS" "CREATE TABLE IF NOT EXISTS packages(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    source TEXT NOT NULL,
    version TEXT,
    install_date TEXT DEFAULT (datetime('now', 'localtime')),
    update_date TEXT,
    repo_url TEXT,
    build_type TEXT
  );"
}

write_package(){
  local name="$1"
  local source="$2"
  local version="$3"
  local repo_url="$4"
  local build_type="$5"

  local exists
  exists=$(sqlite3 "$DB_PKGS" "SELECT EXISTS(SELECT 1 FROM packages WHERE name='$name')")
      if [ "$exists" = "1"  ]; then
        sqlite3 "$DB_PKGS" "UPDATE packages SET version = '$version', update_date = (datetime('now', 'localtime')) WHERE name='$name'"
        echo "updated"
      else
        sqlite3 "$DB_PKGS" "INSERT INTO packages(name, source, version, repo_url, build_type)
        VALUES ('$name', '$source', '$version', '$repo_url', '$build_type')"
        echo "installed"
      fi

}

get_version_package(){
  local name="$1"
  local pkg_version
  pkg_version=$($SU $PKG_MANAGER -Qi $name | grep "Version" | awk '{print $3}' )

  if [ -z "$pkg_version" ]; then
    echo "==> Error getting version"
    return 1
  fi

  echo $pkg_version
}

cmd_install(){
  local name="$1"
  local action
  local version

  echo "==> Installing package: $name"
  if $SU $PKG_MANAGER -S --noconfirm "$name"; then
    version=$(get_version_package "$name")
    action=$(write_package "$name" "$PKG_MANAGER" "$version" "" "")
    echo "==> Package $name has been successfully $action"
  else
    echo "==> Failed to install $name"
    return 1
  fi
}

cmd_search(){
  local name="$1"

  echo "==> Searching package: $name"
  $SU $PKG_MANAGER -Ss "$name"
}

cmd_remove(){
  local name="$1"

  echo "==> Removing package: $name"
  $SU $PKG_MANAGER -Rns --noconfirm "$name"
}

cmd_update(){
  echo "==> Full update system"
  $SU $PKG_MANAGER -Syu --noconfirm
}

cmd_clean_cache(){

  echo "==> Cleaning package cache: "
  $SU $PKG_MANAGER -Sc --noconfirm
}

cmd_gitbuild(){
  local repo="$1"
  shift
  local no_install=false

    while [ $# -gt 0 ]; do
      if [ "$1" = "--no-install" ]; then
        no_install=true
      fi
      shift
    done

  local dir
  dir=$(basename "$repo" .git)

    echo "==> Cloning repository $dir"
    git clone "$repo" || return 1

    echo "==> Enter in directory: $dir"
    cd "$dir" || return 1

    echo "==> Building package: $dir (no_install: $no_install )"
    if [ -f PKGBUILD ]; then
      echo "==> Found PKGBUILD"
        if [ "$no_install" != "true" ]; then
          makepkg -sric
        else
          makepkg -src
        fi
    elif [ -f autogen.sh ]; then
      echo "Found Autotools"
      ./autogen.sh && ./configure || return 1
      make -j$(nproc)
        if [ "$no_install" != "true" ]; then
          $SU make install
        else
          make
        fi
    elif [ -f configure ]; then
      echo "Found Autotools, pre-genereted"
      ./configure || return 1
      make -j$(nproc)
        if [ "$no_install" != "true" ]; then
          $SU make install
        else
          make
        fi
    elif [ -f Makefile ] || [ -f makefile ]; then
      echo "==> Found Makefile"
      make -j$(nproc)
        if [ "$no_install" != "true" ]; then
          $SU make install
        else
          make
        fi
    else
        echo "Error: Not found PKGBUILD or Makefile"
        return 1
    fi
    return 0
}

db_init

while [ -n "${1:-}" ]; do
case "$1" in
  install)
    shift
    cmd_install "$1" || exit 1
    shift
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
    cmd_search "$1"
    shift
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
  *)
    echo "No parameters found"
    exit 0
    ;;
  esac
done
