set -euo pipefail

data_dir="$COGNEE_PG_STATE/cluster/data"
password_file="$COGNEE_PG_STATE/password"

if [[ ! -s "$data_dir/PG_VERSION" ]]; then
  if [[ -e "$data_dir" ]]; then
    printf '%s\n' 'Existing Cognee PostgreSQL data directory has no PG_VERSION.' >&2
    exit 1
  fi
  staging=$(mktemp -d "$COGNEE_PG_STATE/cluster/init.XXXXXX")
  cleanup() {
    if pg_ctl -D "$staging" status >/dev/null 2>&1; then
      pg_ctl -D "$staging" -m immediate -w stop >/dev/null || return
    fi
    rm -rf -- "$staging"
  }
  trap cleanup EXIT
  trap 'exit 1' HUP INT TERM

  COGNEE_DB_PASSWORD=$(<"$password_file")
  if [[ ! "$COGNEE_DB_PASSWORD" =~ ^[0-9a-f]{64}$ ]]; then
    printf '%s\n' 'Invalid Cognee database password file.' >&2
    exit 1
  fi
  export COGNEE_DB_PASSWORD

  initdb -D "$staging" --auth-local=peer --auth-host=scram-sha-256 --locale=C --encoding=UTF8
  # Initialize in a private socket directory before opening the loopback listener.
  pg_ctl -D "$staging" -o "-h '' -k $(printf '%q' "$staging")" -w start
  psql -X --set=ON_ERROR_STOP=1 --host="$staging" --dbname=postgres <<'SQL'
\getenv cognee_password COGNEE_DB_PASSWORD
CREATE ROLE cognee LOGIN PASSWORD :'cognee_password';
CREATE DATABASE cognee OWNER cognee;
SQL
  unset COGNEE_DB_PASSWORD
  psql -X --set=ON_ERROR_STOP=1 --host="$staging" --dbname=cognee \
    --command='CREATE EXTENSION vector;'
  pg_ctl -D "$staging" -m fast -w stop
  mv -- "$staging" "$data_dir"
  trap - EXIT HUP INT TERM
fi

postgres -D "$data_dir" -h 127.0.0.1 -p "$COGNEE_PG_PORT" -k "$COGNEE_PG_STATE/cluster" \
  -c shared_buffers=128MB -c max_connections=30 &
postgres_pid=$!

# A launchd stop must release open client sessions even if Cognee is still up.
stop_postgres() {
  kill -INT "$postgres_pid" 2>/dev/null || true
  wait "$postgres_pid"
  exit 0
}
trap stop_postgres HUP INT TERM
wait "$postgres_pid"
