#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESOURCES_DIR="$ROOT_DIR/mods/deathmatch/resources"
GAMEPLAY_DIR="$ROOT_DIR/mods/deathmatch/[gameplay]"
CACHE_DIR="$ROOT_DIR/mods/deathmatch/resource-cache/unzipped"
DB_DIR="$ROOT_DIR/var/mariadb/data"
RUN_DIR="$ROOT_DIR/var/mariadb/run"
LOG_DIR="$ROOT_DIR/var/mariadb/log"
SOCKET="$RUN_DIR/mysql.sock"
DB_PID_FILE="$RUN_DIR/mariadb.pid"
DB_LOG="$LOG_DIR/mariadb.log"
MTA_LOG="$ROOT_DIR/mods/deathmatch/logs/server.log"
MTA_LAUNCH_LOG="$LOG_DIR/mta-launcher.log"
ADMIN_NOTE="$ROOT_DIR/mods/deathmatch/logs/exo_admin_credentials.txt"
DB_PORT="3307"

DB_USER="vrp_local"
DB_PASS="5ce2cbd32c072aeffddc3ffa5f8e5f55"
DB_MAIN="vrp"
DB_LOGS="vrp_logs"
DB_PREMIUM="vrp_premium"

ADMIN_USER="serveradmin"
ADMIN_PASS="9724f384936e98608e4c16e661d6bcae"
ADMIN_EMAIL="serveradmin@local"

mkdir -p "$DB_DIR" "$RUN_DIR" "$LOG_DIR" "$ROOT_DIR/mods/deathmatch/logs"

# eXo expects a few stock MTA resources to still exist after deployment.
ln -sfn "../[gameplay]/reload" "$RESOURCES_DIR/reload"
ln -sfn "../[gameplay]/parachute" "$RESOURCES_DIR/parachute"
ln -sfn "[vrp]/[deps]/realdriveby_exo" "$RESOURCES_DIR/realdriveby"
if [[ ! -d "$RESOURCES_DIR/emerlights" && -d "$CACHE_DIR/emerlights" ]]; then
    cp -a "$CACHE_DIR/emerlights" "$RESOURCES_DIR/emerlights"
fi

if [[ ! -d "$DB_DIR/mysql" ]]; then
    mariadb-install-db \
        --no-defaults \
        --datadir="$DB_DIR" \
        --auth-root-authentication-method=normal \
        --skip-test-db \
        --skip-name-resolve \
        --force \
        --tmpdir=/tmp
fi

if ! mysqladmin --protocol=socket --socket="$SOCKET" -uroot ping >/dev/null 2>&1; then
    mariadbd \
        --no-defaults \
        --datadir="$DB_DIR" \
        --socket="$SOCKET" \
        --pid-file="$DB_PID_FILE" \
        --log-error="$DB_LOG" \
        --port="$DB_PORT" \
        --bind-address=127.0.0.1 \
        --skip-name-resolve \
        --tmpdir=/tmp \
        --character-set-server=utf8mb4 \
        --collation-server=utf8mb4_unicode_ci \
        --innodb-temp-data-file-path=ibtmp1:12M:autoextend \
        >/dev/null 2>&1 &

    for _ in $(seq 1 30); do
        if mysqladmin --protocol=socket --socket="$SOCKET" -uroot ping >/dev/null 2>&1; then
            break
        fi
        sleep 1
    done
fi

mysql --protocol=socket --socket="$SOCKET" -uroot <<SQL
CREATE DATABASE IF NOT EXISTS \`${DB_MAIN}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS \`${DB_LOGS}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS \`${DB_PREMIUM}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
CREATE USER IF NOT EXISTS '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}';

GRANT ALL PRIVILEGES ON \`${DB_MAIN}\`.* TO '${DB_USER}'@'localhost';
GRANT ALL PRIVILEGES ON \`${DB_LOGS}\`.* TO '${DB_USER}'@'localhost';
GRANT ALL PRIVILEGES ON \`${DB_PREMIUM}\`.* TO '${DB_USER}'@'localhost';
GRANT ALL PRIVILEGES ON \`${DB_MAIN}\`.* TO '${DB_USER}'@'127.0.0.1';
GRANT ALL PRIVILEGES ON \`${DB_LOGS}\`.* TO '${DB_USER}'@'127.0.0.1';
GRANT ALL PRIVILEGES ON \`${DB_PREMIUM}\`.* TO '${DB_USER}'@'127.0.0.1';
FLUSH PRIVILEGES;
SQL

if ! pgrep -fa 'box64 .*mta-server64|mta-server64' >/dev/null 2>&1; then
    (
        cd "$ROOT_DIR"
        export BOX64_EMULATED_LIBS='libncursesw.so.6:libtinfo.so.6'
        export BOX64_LD_LIBRARY_PATH="$HOME/x86libs/lib/x86_64-linux-gnu:$HOME/x86libs/usr/lib/x86_64-linux-gnu"
        nohup box64 ./mta-server64 -d >>"$MTA_LAUNCH_LOG" 2>&1 &
    )
fi

for _ in $(seq 1 30); do
    if ss -lun | grep -q ':22003'; then
        break
    fi
    sleep 1
done

if ! ss -lun | grep -q ':22003'; then
    printf 'MTA failed to bind UDP 22003. Check %s and %s\n' "$MTA_LAUNCH_LOG" "$MTA_LOG" >&2
    exit 1
fi

for _ in $(seq 1 120); do
    if mysql --protocol=tcp -h127.0.0.1 -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" -Nse "SHOW TABLES LIKE 'vrp_account';" "$DB_MAIN" 2>/dev/null | grep -qx 'vrp_account'; then
        break
    fi
    sleep 1
done

if ! mysql --protocol=tcp -h127.0.0.1 -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" -Nse "SHOW TABLES LIKE 'vrp_account';" "$DB_MAIN" 2>/dev/null | grep -qx 'vrp_account'; then
    printf 'eXo did not initialize its database. Check %s and %s\n' "$MTA_LAUNCH_LOG" "$MTA_LOG" >&2
    exit 1
fi

salt="$(printf '%s' "${ADMIN_USER}:${ADMIN_PASS}" | md5sum | awk '{print $1}')"
hash="$(printf '%s' "${salt}${ADMIN_PASS}" | sha256sum | awk '{print $1}')"

mysql --protocol=tcp -h127.0.0.1 -P"$DB_PORT" -u"$DB_USER" -p"$DB_PASS" "$DB_MAIN" <<SQL
INSERT INTO vrp_account (ForumID, Name, EMail, Rank, Salt, Password, LastSerial, LastIP, LastLogin, RegisterDate, migrated, InvitationId, TicketDisplay)
SELECT 0, '${ADMIN_USER}', '${ADMIN_EMAIL}', 9, '${salt}', '${hash}', '', '127.0.0.1', NOW(), NOW(), 0, 0, 0
WHERE NOT EXISTS (
    SELECT 1 FROM vrp_account WHERE Name = '${ADMIN_USER}'
);
SQL

cat > "$ADMIN_NOTE" <<EOF
eXo admin account
Username: ${ADMIN_USER}
Password: ${ADMIN_PASS}

MariaDB
Username: ${DB_USER}
Password: ${DB_PASS}
Socket: ${SOCKET}
EOF

printf 'MariaDB ready on 127.0.0.1:%s\n' "$DB_PORT"
printf 'MTA ready on UDP 22003 / HTTP 22006\n'
printf 'Credentials saved to %s\n' "$ADMIN_NOTE"
printf 'Server log: %s\n' "$MTA_LOG"
