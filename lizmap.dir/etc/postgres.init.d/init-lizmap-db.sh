#!/bin/bash
set -e

# --- 1. Minimalna konfiguracja pod Barmana w plikach tekstowych ---
# Te zmiany są niezbędne, aby Postgres w ogóle dopuścił ruch replikacyjny
echo "wal_level = replica" >> "$PGDATA/postgresql.conf"
echo "max_wal_senders = 10" >> "$PGDATA/postgresql.conf"
echo "max_replication_slots = 10" >> "$PGDATA/postgresql.conf"

# Dodajemy dostęp dla Barmana w pg_hba.conf. 
# "all" odnosi się do sieci wewnętrznej Dockera, nie wystawia bazy na zewnątrz hosta.
echo "host replication barman all scram-sha-256" >> "$PGDATA/pg_hba.conf"
echo "host all barman all scram-sha-256" >> "$PGDATA/pg_hba.conf"

# --- 2. Oryginalna logika inicjalizacji + SQL dla Barmana ---
psql -v ON_ERROR_STOP=1 --username "postgres" --dbname "postgres" <<-EOSQL
    -- Logika oryginalna z repozytorium
    CREATE USER "$POSTGRES_LIZMAP_USER" WITH PASSWORD '$POSTGRES_LIZMAP_PASSWORD';
    CREATE DATABASE "$POSTGRES_LIZMAP_DB";
    GRANT ALL PRIVILEGES ON DATABASE "$POSTGRES_LIZMAP_DB" TO "$POSTGRES_LIZMAP_USER";

    -- Dodatek dla Barmana (używa zmiennej BARMAN_PASS przekazanej przez Docker)
    CREATE ROLE barman WITH REPLICATION LOGIN PASSWORD '$BARMAN_PASS';
    SELECT pg_create_physical_replication_slot('barman_lizmap_slot');
    
    -- Wymuszenie bezpiecznego szyfrowania
    ALTER SYSTEM SET password_encryption = 'scram-sha-256';
EOSQL

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_LIZMAP_DB" <<-EOSQL
        CREATE EXTENSION IF NOT EXISTS "postgis";
        CREATE EXTENSION IF NOT EXISTS "postgis_raster";
        CREATE SCHEMA "lizmap" AUTHORIZATION "$POSTGRES_LIZMAP_USER";
EOSQL