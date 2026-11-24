read_version() {
  git describe --tags --abbrev=0 --match 'v[0-9]*' 2>/dev/null | sed 's/^v//' || echo 0.0.0
}

write_version() {
  :
}
