#!/bin/sh
# Creates the local databases and users. Runs on first MariaDB start through
# /docker-entrypoint-initdb.d and again from setup.sh / reset-db.sh to reconcile grants.
# Passwords come from the container environment (see .env.example); nothing is hard-coded.
set -eu

: "${MARIADB_ROOT_PASSWORD:?MARIADB_ROOT_PASSWORD is required}"
: "${EXAMPLE_APP_DB_PASSWORD:?EXAMPLE_APP_DB_PASSWORD is required}"
: "${EXAMPLE_APP_TEST_DB_PASSWORD:?EXAMPLE_APP_TEST_DB_PASSWORD is required}"

# Passwords are interpolated into SQL string literals, so reject quote and backslash characters.
for password in "$EXAMPLE_APP_DB_PASSWORD" "$EXAMPLE_APP_TEST_DB_PASSWORD"; do
	case "$password" in
		*\'*|*\"*|*\\*) echo "Database passwords must not contain quotes or backslashes" >&2; exit 1 ;;
	esac
done

mariadb --protocol=socket -uroot -p"$MARIADB_ROOT_PASSWORD" <<SQL
DROP USER IF EXISTS 'root'@'%';

-- Main application database
CREATE DATABASE IF NOT EXISTS example_app CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE OR REPLACE USER 'example_app'@'%' IDENTIFIED BY '${EXAMPLE_APP_DB_PASSWORD}';
GRANT ALL PRIVILEGES ON example_app.* TO 'example_app'@'%';

-- Isolated test database
CREATE DATABASE IF NOT EXISTS example_app_test CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE OR REPLACE USER 'example_app_test'@'%' IDENTIFIED BY '${EXAMPLE_APP_TEST_DB_PASSWORD}';
GRANT ALL PRIVILEGES ON example_app_test.* TO 'example_app_test'@'%';

FLUSH PRIVILEGES;
SQL
