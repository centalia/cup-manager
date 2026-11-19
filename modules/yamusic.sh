# cup - Yandex Music Modules
# Author: Centalia

YM_JSON_URL="https://music-desktop-application.s3.yandex.net/stable/download.json"


source $SCRIPT_DIR/lib/pkg.sh
source $SCRIPT_DIR/lib/utils.sh

get_yamusic_url(){
  local json
      if command -v jq >/dev/null; then
          json=$(curl -fsSL "$YM_JSON_URL")
          YM_URL=$(echo "$json" | jq -r '.linux')
          YM_VERSION=$(echo "$YM_URL" | grep -oP 'Yandex_Music_amd64_\K[0-9.]+(?=\.deb)')
      else
          YM_URL=$(curl -fsSL "$YM_JSON_URL" | grep -o '"linux":"[^"]*"' | cut -d'"' -f4)
          YM_VERSION=$(echo "$YM_URL" | sed -n 's/.*Yandex_Music_amd64_\([0-9.]*\)\.deb/\1/p')
      fi

      if [ -z "$YM_URL" ] || [ -z "$YM_VERSION" ]; then
          echo "Error: failed to fetch the Yandex Music download link" >&2
          return 1
      fi
}

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

cmd_install_yamusic(){
  local temp_dir

  echo "==> Checking debtap"
  check_debtap || return 1

  echo "==> Create temporary directory"
  temp_dir=$(mktemp -d) || return 1

  echo "==> Fetching latest Yandex.Music link"
  get_yamusic_url || return 1

  echo "==> Downloading Yandex.Music $YM_VERSION"
  download_file "$YM_URL" "$temp_dir/YandexMusic.deb" || return 1

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