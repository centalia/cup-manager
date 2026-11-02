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