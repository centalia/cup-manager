#!/bin/bash
set -euo pipefail
# cup
# Author: Centalia

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
  exists=$(sqlite3 "$DB_PKGS" "SELECT EXISTS(SELECT 1 FROM packages \
                                WHERE name='$name')")
      if [ "$exists" = "1"  ]; then
        sqlite3 "$DB_PKGS" "UPDATE packages SET version = '$version', update_date = (datetime('now', 'localtime')) \
                            WHERE name='$name'"
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

check_yay(){
  local tmp_dir

  if command -v yay >/dev/null 2>&1; then
    echo "==> Yay installed"
  else
    echo "==> Yay not installed. Do you want too install?"
    echo "Type yes - to agree"
    echo "Type no - to disagree"
    read answer
    case "$answer" in
      yes)
          #TODO: @Refactoring - Сделать нормальную обработку yes/no (принимать y, Y, yes, YES, игнорировать пробелы)
          #Паттерн [Yy]|[Yy][Ee][Ss)
        echo "==> Install yay"

        echo "==> Checking dependencies"
        if command -v git >/dev/null 2>&1; then #TODO: @Refactoring - Объединить два if
          echo "Git installed"
        else
          cmd_install git
        fi

        if command -v makepkg >/dev/null 2>&1; then
          echo "Base-devel installed"
        else
          cmd_install base-devel
        fi

        echo "==> Create temporary folder"
        tmp_dir=$(mktemp -d)

        echo "Cloning and building repo yay to $tmp_dir"
        (
          cd $tmp_dir
          cmd_gitbuild https://aur.archlinux.org/yay.git
        )
        echo "Cleaning $tmp_dir"
        rm -rf "$tmp_dir"
        ;;
      *)
        echo "==> Cancelled"
        return 1
      ;;
    esac
  fi
}

cmd_install(){
  local pkg_name=""
  local action
  local version
  local use_yay=false


#  while [ $# -gt 0 ]; do
#    case "$1" in
#      --aur|-a)
#        use_yay=true
#      ;;
#      -*)
#        echo "Unknown flag"
#        return 1
#      ;;
#      *)
#        pkg_name="$1"
#    esac
#    shift
#  done

  if [ "$1" = "--aur" ] || [ "$1" = "-a" ]; then
    use_yay=true
    shift
  fi

  local pkg_name="$1"

  if [ $# -gt 1 ]; then
    echo "==> Error: Too many arguments."
    return 1
  fi

  if [ -z "$pkg_name" ]; then
    echo "==> Error: no package name provided"
    return 1
  fi

  echo "==> Installing package: $pkg_name"

  if [ "$use_yay" = "true" ]; then
    if yay -S --noconfirm "$pkg_name"; then
      version=$(get_version_package "$pkg_name")
      action=$(write_package "$pkg_name" "yay" "$version" "" "")
      echo "==> Package $pkg_name has been successfully $action via yay"
    else
      echo "==> Failed to install $pkg_name"
      return 1
    fi
  else
    if $SU $PKG_MANAGER -S --noconfirm "$pkg_name"; then
      version=$(get_version_package "$pkg_name")
      action=$(write_package "$pkg_name" "$PKG_MANAGER" "$version" "" "")
      echo "==> Package $pkg_name has been successfully $action via $PKG_MANAGER"
    else
      echo "==> Failed to install $pkg_name"
      return 1
    fi
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
    (
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
    )
    return $?
}

cmd_list(){
  local count
  count=$(sqlite3 "$DB_PKGS" "\
  SELECT COUNT(*) \
  FROM packages")
  if [ "$count" -eq 0 ]; then
    echo "==> No packages tracked yet"
    return 0
  else
    echo "==> Tracked $count packages"
    echo " "
    sqlite3 -header -column "$DB_PKGS" "\
      SELECT name, version, source, install_date, update_date \
      FROM packages \
      ORDER BY name;"
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
  list)
    cmd_list
    set --
    ;;
  *)
    echo "No parameters found"
    exit 0
    ;;
  esac
done
