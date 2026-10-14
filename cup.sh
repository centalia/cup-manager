#!/bin/bash
set -euo pipefail
# cup — Custom Universal Packager
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

#pkg(){
#  local name="$1"
#  local version
#
#  version=$(get_version_package "$name")
#  save_package "$name" "$PKG_MANAGER" "$version" "" ""
#}

install_package(){
  local name="$1"
  local action
  local version

  echo "==> Installing package: $name"

  $SU $PKG_MANAGER -S --noconfirm "$name"
  version=$(get_version_package "$name")
  action=$(write_package "$name" "$PKG_MANAGER" "$version" "" "")

  echo "==> Package $name has been successfully $action"
}

db_init

while [ -n "${1:-}" ]; do
case "$1" in
  install)
#    shift
#    pkg_name="$1"
#    shift
#
#    echo "==> Installing package: $pkg_name"
##    $SU $PKG_MANAGER -S --noconfirm "$pkg_name"
#    pkg_install "$pkg_name"
#    action=$(install_package "$pkg_name")
#
#    echo "==> Package $pkg_name has been successfully $action"
  shift
  install_package "$@"
  shift
    ;;
  remove)
    shift
    echo "==> Removing package: $1"
    $SU $PKG_MANAGER -Rns --noconfirm "$1"
    exit 0
    ;;
  update)
    echo "==> Full update system"
    $SU $PKG_MANAGER -Syu --noconfirm
    exit 0
    ;;
  search)
    shift
    echo "==> Searching package: $1"
    $SU $PKG_MANAGER -Ss "$1"
    exit 0
    ;;
  clean-cache)
    shift
    echo "==> Cleaning package cache: "
    $SU $PKG_MANAGER -Sc --noconfirm
    exit 0
    ;;
  gitbuild)
    repo="$2"
    shift 2
    no_install=false

    while [ $# -gt 0 ]; do
      if [ "$1" = "--no-install" ]; then
        no_install=true
      fi
      shift
    done

    dir=$(basename "$repo" .git)

    echo "==> Cloning repository $dir"
    git clone "$repo"

    echo "==> Enter in directory: $dir"
    cd "$dir" || exit 1

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
      ./autogen.sh && ./configure || exit 1
      make -j$(nproc)
        if [ "$no_install" != "true" ]; then
          $SU make install
        else
          make
        fi
    elif [ -f configure ]; then
      echo "Found Autotools, pre-genereted"
      ./configure || exit 1
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
        exit 1
    fi
    exit 0
    ;;
  *)
    echo "No parameters found"
    exit 0
    ;;
  esac
done
