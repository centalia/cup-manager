get_version_package(){
  local name="${1:-}"
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
      [Yy]|[Yy][Ee][Ss])
        echo "==> Install yay"

        echo "==> Checking dependencies"
        if command -v git >/dev/null 2>&1; then
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
  local action
  local version
  local use_yay=false
  local refresh=false

  if [ "${1:-}" = "--aur" ] || [ "${1:-}" = "-a" ]; then
    use_yay=true
    shift
  fi

  if [ "${1:-}" = "--refresh" ]; then
    refresh=true
    shift
  fi

  if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    cmd_help_install
    shift
  fi

  local pkg_name="${1:-}"

  if [ $# -gt 1 ]; then
    echo "==> Error: Too many arguments."
    return 1
  fi

  if [ -z "$pkg_name" ]; then
    echo "==> Error: no package name provided"
    return 1
  fi

  if  [ "$use_yay" = "true" ]; then
    if ! command -v yay >/dev/null 2>&1; then
      echo "==> Error: yay is not installed. Run 'cup yay' to install it first."
      return 1
    fi
    echo "==> Installing package: $pkg_name via yay"
    if [ "$refresh" = "true" ]; then
      if ! yay -Sy; then
        echo "Error: failed to refresh package databases, check mirrors"
        return 1
      fi
    fi
    if yay -S "$pkg_name"; then
      version=$(get_version_package "$pkg_name")
      action=$(write_package "$pkg_name" "yay" "$version" "" "")
      echo "==> Package $pkg_name has been successfully $action via yay"
    else
      echo "==> Failed to install $pkg_name"
      return 1
    fi
    else
    if [ "$refresh" = "true" ]; then
      if ! $SU $PKG_MANAGER -Sy; then
        echo "Error: failed to refresh package databases, check mirrors"
        return 1
      fi
    fi

    echo "==> Installing package: $pkg_name via $PKG_MANAGER"

    if $SU $PKG_MANAGER -S "$pkg_name"; then
      version=$(get_version_package "$pkg_name")
      action=$(write_package "$pkg_name" "$PKG_MANAGER" "$version" "" "")
      echo "==> Package $pkg_name has been successfully $action via $PKG_MANAGER"
    else
      if [ "$refresh" = "true" ]; then
        echo "==> Error: failed to install $pkg_name (database already refreshed)"
        return 1
      fi

      echo "==> Install failed, refreshing package databases (partial upgrade risk)"
      if ! $SU $PKG_MANAGER -Sy; then
        echo "==> Error: failed to refresh package databases, check mirrors"
        return 1
      fi

      if $SU $PKG_MANAGER -S "$pkg_name"; then
        version=$(get_version_package "$pkg_name")
        action=$(write_package "$pkg_name" "$PKG_MANAGER" "$version" "" "")
        echo "==> Package $pkg_name has been successfully $action via $PKG_MANAGER"
      else
        echo "==> Error: package '$pkg_name' not found or installation failed"
        return 1
      fi
    fi
  fi
}

cmd_search(){
  local use_yay=false

  if [ "${1:-}" = "--aur" ] || [ "${1:-}" = "-a" ]; then
    use_yay=true
    shift
  fi

  if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    cmd_help_search
    shift
  fi

  local pkg_name="${1:-}"

  if [ $# -gt 1 ]; then
    echo "==> Error: Too many arguments."
    return 1
  fi

  if [ -z "$pkg_name" ]; then
    echo "==> Error: no package name provided"
    return 1
  fi

  echo "==> Searching package: $pkg_name"
   if [ "$use_yay" = "true" ]; then
      if ! command -v yay >/dev/null 2>&1; then
        echo "==> Error: yay is not installed. Cannot search AUR."
        return 1
      fi
      echo "==> Searching in AUR..."
      yay -Ss --aur "$pkg_name"
    else
      if command -v yay >/dev/null 2>&1; then
        echo "==> Searching everywhere (official + AUR)..."
        yay -Ss "$pkg_name"
      else
        echo "==> Searching in official repositories..."
        $SU $PKG_MANAGER -Ss "$pkg_name"
      fi
    fi
}

cmd_remove(){
  local name="${1:-}"

  if [ -z "$name" ]; then
    echo "==> Error: no package name provided"
    return 1
  fi

  echo "==> Removing package: $name"
  $SU $PKG_MANAGER -Rns "$name"
}

cmd_update(){
  echo "==> Full update system"
  $SU $PKG_MANAGER -Syu
}

cmd_clean_cache(){

  echo "==> Cleaning package cache: "
  $SU $PKG_MANAGER -Sc
}

cmd_fix(){
  local db_lock="/var/lib/pacman/db.lck"

  if [ ! -f "$db_lock" ]; then
    echo "==> Lock file not found"
    return 0
  fi

  if pgrep -x pacman >/dev/null 2>&1 ; then
    echo "==> Lock file found, pacman working now"
    return 1
  else
    $SU rm -f "$db_lock"
    echo "==> Lock file deleted"
  fi
}

cmd_help(){
  echo "Syntax: cup [OPTION] [-FLAG] <pkg|repo>"
        echo ""
        echo "Options:"
        echo "  install       установить пакет из официальных репозиториев"
        echo "  remove        удалить пакет"
        echo "  update        обновить систему"
        echo "  search        найти пакет везде"
        echo "  list          показать локальную БД установленных пакетов"
        echo "  fix           удалить зависший лок pacman (db.lck)"
        echo "  modules       список подключенных модулей"
        echo "  clean-cache   очистить кэш пакетов"
        echo "  gitbuild      собрать пакет из git-репозитория"
        echo ""
        echo "Flags:"
        echo "  --aur|-a      установка или поиск в AUR"
        exit 0
}

cmd_help_install(){
  echo "Syntax: cup install [-FLAG] <pkg>"
        echo ""
        echo "Flags:"
        echo "  --aur|-a      установка только через AUR "
        echo "  --refresh     обновление баз данных пакетов перед установкой"
        exit 0
}

cmd_help_search(){
  echo "Syntax: cup search [-FLAG] <pkg>"
        echo ""
        echo "Flags:"
        echo "  --aur|-a      поиск только через AUR "
        exit 0
}

cmd_help_gitbuild(){
  echo "Syntax: cup gitbuild [-FLAG] <repo>"
        echo ""
        echo "Flags:"
        echo "  --no-install    сборка, без установки "
        exit 0
}