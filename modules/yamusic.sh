# cup - Yandex Music Modules
# Author: Centalia

DOWNLOADER=""

source ../lib/pkg.sh

check_debtap(){
  if command -v debtap >/dev/null 2>&1; then
    echo "==> Debtap installed"
  else
    echo "==> Debtap not installed. Do you want to install?"
    echo "Type yes - to agree"
    echo "Type no - to disagree"
    read answer
    case "$answer" in
      [Yy]|[Yy][Ee][Ss])
        echo "==> Install Debtap"
        cmd_install --aur debtap
        ;;
      *)
        echo "==> Cancelled"
        return 1
      ;;
    esac
  fi
}

download_file(){
  local url="$1"
  local file="$2"

  echo "==> Checking curl or wget"
  if command -v curl >/dev/null 2>&1; then
    echo "==> curl found"
    DOWNLOADER="curl"

    elif command -v wget >/dev/null 2>&1; then
      echo "==> wget found"
      DOWNLOADER="wget"
  else
    echo "Error: curl or wget not found"
    return 1
  fi

if [ "$DOWNLOADER" = "curl" ]; then
    curl -L -o "$file" "$url"
else
    wget -O "$file" "$url"
fi
}

cmd_install_yamusic(){
  local temp_dir

  echo "==> Checking debtap"
  check_debtap || return 1

  echo "==> Create temporary directory"
  temp_dir=$(mktemp -d) &&
  echo "==> Downloading Yandex.Music"
  download_file "https://desktop.app.music.yandex.net/stable/Yandex_Music_amd64_5.125.3.deb" "$temp_dir/YandexMusic.deb" || return 1

  echo "==> Update Database debtap"
  sudo debtap -u

  echo "==> Installing Yandex.Music"
  (
    cd $temp_dir || return 1
    if debtap YandexMusic.deb; then
      sudo pacman -U *.pkg.tar.zst
    else
      echo "==> Debtap failed. Package was not created."
      exit 1
    fi
  )
  echo "==> Cleaning temporary directory"
  rm -rf "$temp_dir"
  write_package "Yandex Music" "yamusic" "$(get_version_package "yandexmusic")" "" ""
  return 0
}