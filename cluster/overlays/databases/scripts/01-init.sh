#!/bin/sh
set -eu

required_vars="POSTGRES_USER POSTGRES_DB MINIFLUX_DB MINIFLUX_USER MINIFLUX_PASSWORD LINKDING_DB LINKDING_USER LINKDING_PASSWORD"
for var in $required_vars; do
	eval "value=\${$var:-}"
	if [ -z "$value" ]; then
		echo "[init] required env var is missing: $var" >&2
		exit 1
	fi
done

create_app_db() {
	app_db="$1"
	app_user="$2"
	app_password="$3"

	echo "[init] ensuring role and database for $app_db"

	psql -v ON_ERROR_STOP=1 \
		--username "$POSTGRES_USER" \
		--dbname "$POSTGRES_DB" \
		-v app_db="$app_db" \
		-v app_user="$app_user" \
		-v app_password="$app_password" <<'SQL'
SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'app_user', :'app_password')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'app_user')\gexec

SELECT format('ALTER ROLE %I WITH LOGIN PASSWORD %L', :'app_user', :'app_password')
WHERE EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'app_user')\gexec

SELECT format('CREATE DATABASE %I OWNER %I', :'app_db', :'app_user')
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = :'app_db')\gexec

SELECT format('GRANT ALL PRIVILEGES ON DATABASE %I TO %I', :'app_db', :'app_user')\gexec
SQL

	psql -v ON_ERROR_STOP=1 \
		--username "$POSTGRES_USER" \
		--dbname "$app_db" \
		-v app_user="$app_user" <<'SQL'
CREATE SCHEMA IF NOT EXISTS public AUTHORIZATION :"app_user";
ALTER SCHEMA public OWNER TO :"app_user";
GRANT ALL ON SCHEMA public TO :"app_user";
SQL
}

create_app_db "$MINIFLUX_DB" "$MINIFLUX_USER" "$MINIFLUX_PASSWORD"
create_app_db "$LINKDING_DB" "$LINKDING_USER" "$LINKDING_PASSWORD"

echo "[init] database bootstrap finished"
