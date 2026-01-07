#!/bin/bash

#
# Check uid/gid of installation dir
#
set -e

if [ -z $INSTALL_DEST ]; then
# Define default install destination as current directory
INSTALL_DEST=$(pwd)/lizmap
mkdir -p $INSTALL_DEST
fi

scriptdir=$(realpath `dirname $0`)

LIZMAP_UID=${LIZMAP_UID:-$(id -u)}
LIZMAP_GID=${LIZMAP_GID:-$(id -g)}

INSTALL_SOURCE=${INSTALL_SOURCE:-$scriptdir}

#
# Commands
#
_generate_password() {
    openssl rand -base64 18 | tr -d '/+=' | cut -c1-16
}

_makedirs() {
    # Podstawowe katalogi Lizmap
    mkdir -p $INSTALL_DEST/plugins \
             $INSTALL_DEST/processing \
             $INSTALL_DEST/wps-data \
             $INSTALL_DEST/www \
             $INSTALL_DEST/cache \
             $INSTALL_DEST/redis \
             $INSTALL_DEST/var/log/nginx \
             $INSTALL_DEST/var/nginx-cache \
             $INSTALL_DEST/var/lizmap-theme-config \
             $INSTALL_DEST/var/lizmap-db \
             $INSTALL_DEST/var/lizmap-config \
             $INSTALL_DEST/var/lizmap-log \
             $INSTALL_DEST/var/lizmap-modules \
             $INSTALL_DEST/var/lizmap-my-packages

    # Katalogi dla baz danych
    mkdir -p $INSTALL_DEST/db/npm-mariadb \
             $INSTALL_DEST/db/postgis-lizmap \
             $INSTALL_DEST/db/postgis-gis \
             $INSTALL_DEST/etc/postgres.init.d \
             $INSTALL_DEST/etc/gis.init.d \
             $INSTALL_DEST/db/barman-backups

    # Opcjonalne: Ustawienie uprawnień, aby kontenery mogły pisać w tych folderach
    # 999 to domyślny UID dla PostgreSQL i MariaDB w większości obrazów Docker
    chown -R 999:999 $INSTALL_DEST/db
    chown -R 999:999 $INSTALL_DEST/redis
}

_makenv() {
    source $INSTALL_SOURCE/env.default
    if [ "$LIZMAP_CUSTOM_ENV" = "1" ]; then
        echo "Copying custom environment"
        cp $INSTALL_SOURCE/env.default $INSTALL_DEST/.env
    else
    LIZMAP_PROJECTS=${LIZMAP_PROJECTS:-"$LIZMAP_DIR/instances"}
    cat > $INSTALL_DEST/.env <<-EOF
		LIZMAP_PROJECTS=$LIZMAP_PROJECTS
		LIZMAP_DIR=$LIZMAP_DIR
		LIZMAP_UID=$LIZMAP_UID
		LIZMAP_GID=$LIZMAP_GID
		LIZMAP_VERSION_TAG=$LIZMAP_VERSION_TAG
		QGIS_VERSION_TAG=$QGIS_VERSION_TAG
		POSTGIS_VERSION=$POSTGIS_VERSION
		POSTGRES_PASSWORD=$POSTGRES_PASSWORD
		POSTGRES_LIZMAP_DB=$POSTGRES_LIZMAP_DB
		POSTGRES_LIZMAP_USER=$POSTGRES_LIZMAP_USER
		POSTGRES_LIZMAP_PASSWORD=$POSTGRES_LIZMAP_PASSWORD
		QGIS_MAP_WORKERS=$QGIS_MAP_WORKERS
		WPS_NUM_WORKERS=$WPS_NUM_WORKERS
		LIZMAP_PORT=$LIZMAP_PORT
		OWS_PORT=$OWS_PORT
		WPS_PORT=$WPS_PORT
		POSTGIS_PORT=$POSTGIS_PORT
		POSTGIS_ALIAS=$POSTGIS_ALIAS
		NPM_DB_ROOT_PASSWORD=$NPM_DB_ROOT_PASSWORD
		NPM_DB_USER=$NPM_DB_USER
		NPM_DB_PASSWORD=$NPM_DB_PASSWORD
		LIZMAP_HOST=$LIZMAP_HOST
        POSTGRES_GIS_PASSWORD=$POSTGRES_GIS_PASSWORD
        POSTGIS_GIS_PORT=$POSTGIS_GIS_PORT
        POSTGRES_GIS_DB=$POSTGRES_GIS_DB
        POSTGRES_GIS_USER=$POSTGRES_GIS_USER
        POSTGRES_GIS_USER_PASSWORD=$POSTGRES_GIS_USER_PASSWORD
        BARMAN_PASS=$BARMAN_PASS
		EOF
    fi
}
_make_barman_conf() {
    echo "Generowanie konfiguracji Barmana w etc/barman.d/..."
    # Załaduj zmienne z .env
    export $(grep -v '^#' "$ENV_FILE" | xargs)

    # Funkcja pomocnicza do wypełniania plików .conf zmiennymi
    # Tworzymy postgis.conf
    cat <<EOF > "$INSTALL_DEST/etc/barman.d/postgis.conf"
[postgis]
description = "Glowna baza danych Lizmap"
conninfo = host=postgis user=barman dbname=postgres password=$BARMAN_PASS
streaming_conninfo = host=postgis user=barman password=$BARMAN_PASS
streaming_archiver = on
slot_name = barman_lizmap_slot
backup_method = postgres
archiver = on
EOF

    # Tworzymy bazagis.conf
    cat <<EOF > "$INSTALL_DEST/etc/barman.d/bazagis.conf"
[bazagis]
description = "Zewnetrzna baza danych GIS"
conninfo = host=bazagis user=barman dbname=postgres password=$BARMAN_PASS
streaming_conninfo = host=bazagis user=barman password=$BARMAN_PASS
streaming_archiver = on
slot_name = barman_slot
backup_method = postgres
archiver = on
EOF

    # Nadanie uprawnień dla Barmana (UID 999)
    chown -R 999:999 "$INSTALL_DEST/etc/barman.d/"
}

_makepgservice() {
# Do NOT override existing pg_service.conf
if [ ! -e $INSTALL_DEST/etc/pg_service.conf ]; then
    cat > $INSTALL_DEST/etc/pg_service.conf <<-EOF
[lizmap_local]
host=$POSTGIS_ALIAS
port=5432
dbname=$POSTGRES_LIZMAP_DB
user=$POSTGRES_LIZMAP_USER
password=$POSTGRES_LIZMAP_PASSWORD
EOF
    chmod 0600 $INSTALL_DEST/etc/pg_service.conf
fi
}

_makelizmapprofiles() {
    cat > $INSTALL_DEST/etc/profiles.d/lizmap_local.ini.php <<-EOF
[jdb]
lizlog=jauth

[jdb:jauth]
driver=pgsql
host=$POSTGIS_ALIAS
port=5432
database=$POSTGRES_LIZMAP_DB
user=$POSTGRES_LIZMAP_USER
password="$POSTGRES_LIZMAP_PASSWORD"
search_path=lizmap,public
EOF
    chmod 0600 $INSTALL_DEST/etc/profiles.d/lizmap_local.ini.php
}


_install-plugin() {
    /src/install-lizmap-plugin.sh
}

_configure() {

    #
    # Create env file
    #
    echo "Creating env file"
    _makenv

    #
    # Copy configuration and create directories
    #
    echo "Copying files"
    cp -R $INSTALL_SOURCE/lizmap.dir/* $INSTALL_DEST/

    echo "Creating directories"
    _makedirs

    #
    # Create barman confs
    #
    echo "Creating barman.d confs"
    _make_barman_conf

    #
    # Create pg_service.conf
    #
    echo "Creating pg_service.conf"
    _makepgservice

    #
    # Create lizmap profiles
    #
    echo "Creating lizmap profiles"
    _makelizmapprofiles

    #
    # Lizmap plugin
    #
    echo "Installing lizmap plugin"
    _install-plugin
}


configure() {
    echo "=== Configuring lizmap in $INSTALL_DEST"

    source $INSTALL_SOURCE/env.default

    LIZMAP_PROJECTS=${LIZMAP_PROJECTS:-$INSTALL_DEST"/instances"}
    
    docker run -it \
        -u $LIZMAP_UID:$LIZMAP_GID \
        --rm \
        -e INSTALL_SOURCE=/install \
        -e INSTALL_DEST=/lizmap \
        -e LIZMAP_DIR=$INSTALL_DEST \
        -e QGSRV_SERVER_PLUGINPATH=/lizmap/plugins \
        -e LIZMAP_PROJECTS=$LIZMAP_PROJECTS \
        -e LIZMAP_VERSION_TAG=$LIZMAP_VERSION_TAG \
        -e QGIS_VERSION_TAG=$QGIS_VERSION_TAG \
        -e POSTGIS_VERSION=$POSTGIS_VERSION \
        -e QGIS_MAP_WORKERS=$QGIS_MAP_WORKERS \
        -e WPS_NUM_WORKERS=$WPS_NUM_WORKERS \
        -v $INSTALL_SOURCE:/install \
        -v $INSTALL_DEST:/lizmap \
        -v $scriptdir:/src \
        --entrypoint /src/configure.sh \
        3liz/qgis-map-server:${QGIS_VERSION_TAG} _configure

    #
    # Copy docker-compose file but preserve ownership
    # for admin user
    #
    if [ "$COPY_COMPOSE_FILE" = "1" ]; then
        echo "Copying docker compose file"
        cp $INSTALL_SOURCE/docker-compose.yml $INSTALL_DEST/
    else
        rm -f $INSTALL_SOURCE/.env
        ln -s $INSTALL_DEST/.env $INSTALL_SOURCE/.env
    fi
}

_clean() {
    echo "Cleaning lizmap configs in '$INSTALL_DEST'"
    rm -rf $INSTALL_DEST/www/*
    rm -rf $INSTALL_DEST/var/*
    rm -rf $INSTALL_DEST/wps-data/*
    _makedirs
}

clean() {
    if [ -z $INSTALL_DEST ]; then
        echo "Invalid install directory"
        exit 1
    fi
    source $INSTALL_DEST/.env
    if [ "$LIZMAP_UID" != "$(id -u)" ]; then
        docker run -it \
            -u $LIZMAP_UID:$LIZMAP_GID \
            --rm \
            -e INSTALL_DEST=/lizmap \
            -v $INSTALL_DEST:/lizmap \
            -v $scriptdir:/src \
            --entrypoint /src/configure.sh \
            3liz/qgis-map-server:${QGIS_VERSION_TAG} _clean
     else
         _clean
     fi
}


"$@"
