# Work project — run a CLI command inside the app container
dcli() {
  docker compose run --rm app bin/cli "$@"
}
