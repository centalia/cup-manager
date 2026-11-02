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
  local action
  local version
  local use_yay=false

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

  if  [ "$use_yay" = "true" ]; then
    if ! command -v yay >/dev/null 2>&1; then
      echo "==> Error: yay is not installed. Run 'cup yay' to install it first."
      return 1
    fi
    echo "==> Installing package: $pkg_name via yay"
    if yay -S --noconfirm "$pkg_name"; then
      version=$(get_version_package "$pkg_name")
      action=$(write_package "$pkg_name" "yay" "$version" "" "")
      echo "==> Package $pkg_name has been successfully $action via yay"
    else
      echo "==> Failed to install $pkg_name"
      return 1
    fi
  else
    echo "==> Installing package: $pkg_name via $PKG_MANAGER"
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
  local use_yay=false

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