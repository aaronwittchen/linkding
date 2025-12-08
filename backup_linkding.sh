#!/usr/bin/env bash
set -euo pipefail

###############################################
# Full Linkding Backup Script (DB + Files)
###############################################

# -------- CONFIGURATION --------

# Kubernetes namespace
NAMESPACE="linkding"

# Postgres pod selector
POSTGRES_LABEL="app=postgres"

# Postgres credentials
DB_USER="linkding"
DB_NAME="linkding"

# Local backup folder
BACKUP_DIR="$HOME/backup"

# Optional: folders to archive (adjust for your installation)
LINKDING_CONFIG="/opt/linkding/config"
LINKDING_DATA="/opt/linkding/data"

# How many old backups to keep
RETENTION_COUNT=7

# -------- INTERNAL --------
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
WORK_DIR="$BACKUP_DIR/tmp_$TIMESTAMP"
FINAL_ARCHIVE="$BACKUP_DIR/linkding_full_backup_$TIMESTAMP.tar.gz"

mkdir -p "$BACKUP_DIR"
mkdir -p "$WORK_DIR"

echo "============================================="
echo " LINKDING FULL BACKUP STARTED"
echo " Timestamp: $TIMESTAMP"
echo " Work directory: $WORK_DIR"
echo "============================================="


###############################################
# Step 1 — PostgreSQL Backup via Kubernetes
###############################################

echo "➤ Finding PostgreSQL pod..."
DB_POD=$(kubectl get pod -n $NAMESPACE -l $POSTGRES_LABEL -o jsonpath='{.items[0].metadata.name}')

echo "   → Found: $DB_POD"
echo "➤ Dumping PostgreSQL database..."

kubectl exec -n $NAMESPACE "$DB_POD" -- \
    pg_dump -U "$DB_USER" "$DB_NAME" \
    | gzip > "$WORK_DIR/linkding_db.sql.gz"

echo "   ✓ Database backup completed."


###############################################
# Step 2 — Backup Linkding config/data folders
###############################################

echo "➤ Backing up Linkding config and data files..."

if [ -d "$LINKDING_CONFIG" ]; then
    cp -r "$LINKDING_CONFIG" "$WORK_DIR/config"
    echo "   ✓ Config folder archived."
else
    echo "   ⚠ Config folder not found: $LINKDING_CONFIG"
fi

if [ -d "$LINKDING_DATA" ]; then
    cp -r "$LINKDING_DATA" "$WORK_DIR/data"
    echo "   ✓ Data folder archived."
else
    echo "   ⚠ Data folder not found: $LINKDING_DATA"
fi


###############################################
# Step 3 — Build the final tar.gz archive
###############################################

echo "➤ Creating final archive..."

tar -czf "$FINAL_ARCHIVE" -C "$WORK_DIR" .

echo "   ✓ Archive created: $FINAL_ARCHIVE"


###############################################
# Step 4 — Cleanup work directory
###############################################

rm -rf "$WORK_DIR"
echo "➤ Temp files cleaned."


###############################################
# Step 5 — Rotate old backups
###############################################

echo "➤ Applying retention policy (keep last $RETENTION_COUNT backups)..."

ls -1t "$BACKUP_DIR"/linkding_full_backup_*.tar.gz | tail -n +$((RETENTION_COUNT+1)) | xargs -r rm --

echo "   ✓ Old backups cleaned."


###############################################
# DONE
###############################################

echo "============================================="
echo " LINKDING FULL BACKUP COMPLETED SUCCESSFULLY "
echo " Saved to: $FINAL_ARCHIVE"
echo "============================================="
