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