#!/bin/bash

# Konfiguracja ścieżek
PROJECT_DIR="/opt/lizmap"
BARMAN_DATA="$PROJECT_DIR/db/barman-backups"
REMOTE_SERVER="backup-server-ip"
REMOTE_DEST="/opt/backups/lizmap-server/"

echo "--- 1. Wymuszenie backupu Barmana (opcjonalnie) ---"
# Barman zazwyczaj robi backupy z automatu, ale możemy wymusić pełny co noc
docker exec lizmap-barman barman backup bazagis
docker exec lizmap-barman barman backup postgis

echo "--- 2. Synchronizacja archiwum Barmana na serwer zewnętrzny ---"
# Synchronizujemy cały katalog Barmana. 
# Barman ma własną strukturę (base/ i wals/), którą rsync idealnie obsłuży przyrostowo.
rsync -avz --delete -e ssh \
    $BARMAN_DATA \
    backupuser@$REMOTE_SERVER:$REMOTE_DEST/barman_backups/

echo "--- 3. Synchronizacja plików projektów QGIS i Lizmap ---"
rsync -avz --delete -e ssh \
    --exclude 'db/' \
    --exclude 'cache/' \
    $PROJECT_DIR/ \
    backupuser@$REMOTE_SERVER:$REMOTE_DEST/project_files/

echo "Backup zakończony sukcesem: $(date)"