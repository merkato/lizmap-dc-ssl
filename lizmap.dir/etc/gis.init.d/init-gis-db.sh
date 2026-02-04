#!/bin/bash
set -e

# 1. Konfiguracja plików hba i conf przed uruchomieniem reszty
echo "Konfiguracja zabezpieczeń w pg_hba.conf..."

PG_HBA_FILE="$PGDATA/pg_hba.conf"
PG_CONF_FILE="$PGDATA/postgresql.conf"

# 1a. Konfiguracja sieciowa i WAL dla Barmana
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" "$PG_CONF_FILE"

# Ustawienia niezbędne dla Barmana (Streaming Replication)
cat <<EOF >> "$PG_CONF_FILE"
wal_level = replica
archive_mode = on
archive_command = 'test ! -f /var/lib/postgresql/data/archive/%f && cp %p /var/lib/postgresql/data/archive/%f'
max_wal_senders = 10
max_replication_slots = 10
EOF

# Utworzenie katalogu na archiwum WAL (wymagane przez archive_command powyżej)
mkdir -p "$PGDATA/archive"
chown postgres:postgres "$PGDATA/archive"

# 2. Konfiguracja pg_hba.conf z uwzględnieniem replikacji dla Barmana
cat <<EOF > "$PG_HBA_FILE"
# TYPE  DATABASE        USER            ADDRESS                 METHOD
local   all             all                                     trust
host    all             postgres        0.0.0.0/0               reject

# Replikacja dla Barmana (używamy scram-sha-256)
host    replication     barman          0.0.0.0/0               scram-sha-256
host    all             barman          0.0.0.0/0               scram-sha-256

# Standardowy dostęp dla użytkowników
host    all             all             0.0.0.0/0               scram-sha-256
EOF

# 3. Wykonanie operacji SQL (użytkownicy i bazy)
psql -v ON_ERROR_STOP=1 --username "postgres" --dbname "postgres" <<-EOSQL
    ALTER SYSTEM SET password_encryption = 'scram-sha-256';
    -- Użytkownik GIS
    CREATE ROLE "$POSTGRES_GIS_USER" WITH SUPERUSER INHERIT LOGIN PASSWORD '$POSTGRES_GIS_USER_PASSWORD';
    CREATE DATABASE "$POSTGRES_GIS_DB";
    GRANT ALL PRIVILEGES ON DATABASE "$POSTGRES_GIS_DB" TO "$POSTGRES_GIS_USER";

    -- Użytkownik BARMAN (z uprawnieniami REPLICATION)
    CREATE ROLE barman WITH REPLICATION LOGIN PASSWORD '$BARMAN_PASS';
    
    -- Tworzenie fizycznego slotu replikacyjnego dla Barmana
    SELECT pg_create_physical_replication_slot('barman_slot');
    

EOSQL

# 4. Inicjalizacja schematów w bazie GIS
psql -v ON_ERROR_STOP=1 --username "postgres" --dbname "$POSTGRES_GIS_DB" <<-EOSQL
    CREATE EXTENSION IF NOT EXISTS "postgis";
    CREATE SCHEMA "wylaczenia" AUTHORIZATION "$POSTGRES_GIS_USER";
    CREATE SCHEMA "lmn" AUTHORIZATION "$POSTGRES_GIS_USER";
    GRANT ALL ON SCHEMA public TO "$POSTGRES_GIS_USER";
EOSQL

# Przeładowanie konfiguracji, aby zmiany w pg_hba.conf weszły w życie
pg_ctl reload