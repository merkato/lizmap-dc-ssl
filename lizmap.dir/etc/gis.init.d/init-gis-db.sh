#!/bin/bash
set -e

# 1. Konfiguracja plików hba i conf przed uruchomieniem reszty
echo "Konfiguracja zabezpieczeń w pg_hba.conf..."

# Ścieżka do pliku konfiguracyjnego wewnątrz kontenera
PG_HBA_FILE="$PGDATA/pg_hba.conf"
PG_CONF_FILE="$PGDATA/postgresql.conf"

# Ustawienie listen_addresses w postgresql.conf
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" "$PG_CONF_FILE"

# Nadpisanie pg_hba.conf dla restrykcyjnego dostępu:
# - local: dostęp dla psql wewnątrz kontenera
# - host postgres 127.0.0.1: dostęp superusera tylko z wewnątrz
# - host all all 0.0.0.0/0 scram-sha-256: dostęp dla reszty świata przez SCRAM
cat <<EOF > "$PG_HBA_FILE"
# TYPE  DATABASE        USER            ADDRESS                 METHOD
local   all             all                                     trust
host    all             postgres        127.0.0.1/32            scram-sha-256
host    all             postgres        ::1/128                 scram-sha-256
host    all             postgres        0.0.0.0/0               reject
host    all             all             0.0.0.0/0               scram-sha-256
host    all             all             ::/0                    scram-sha-256
EOF

# 2. Wykonanie operacji SQL
psql -v ON_ERROR_STOP=1 --username "postgres" --dbname "postgres" <<-EOSQL
    -- Tworzenie roli i bazy
    CREATE ROLE "$POSTGRES_GIS_USER" WITH NOSUPERUSER NOCREATEDB NOCREATEROLE INHERIT LOGIN PASSWORD '$POSTGRES_GIS_USER_PASSWORD';
    CREATE DATABASE "$POSTGRES_GIS_DB";
    GRANT ALL PRIVILEGES ON DATABASE "$POSTGRES_GIS_DB" TO "$POSTGRES_GIS_USER";
    
    -- Wymuszenie szyfrowania haseł przez SCRAM (jeśli nie jest domyślne)
    ALTER SYSTEM SET password_encryption = 'scram-sha-256';
EOSQL

# 3. Konfiguracja wewnątrz bazy docelowej
psql -v ON_ERROR_STOP=1 --username "postgres" --dbname "$POSTGRES_GIS_DB" <<-EOSQL
    CREATE EXTENSION IF NOT EXISTS "postgis";
    
    -- Tworzenie schematów i nadanie WŁASNOŚCI (to pozwala na CREATE/DROP/EDIT)
    CREATE SCHEMA "wylaczenia";
    CREATE SCHEMA "lmn";
    
    ALTER SCHEMA "wylaczenia" OWNER TO "$POSTGRES_GIS_USER";
    ALTER SCHEMA "lmn" OWNER TO "$POSTGRES_GIS_USER";
    
    -- Nadanie uprawnień do tworzenia obiektów w bazie dla użytkownika
    GRANT ALL ON SCHEMA public TO "$POSTGRES_GIS_USER";
EOSQL

# Przeładowanie konfiguracji, aby zmiany w pg_hba.conf weszły w życie
pg_ctl reload