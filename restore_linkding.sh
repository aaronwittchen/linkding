#!/usr/bin/env bash
set -euo pipefail

###############################################
# Full Linkding Restore Script (DB + Files)
###############################################

# -------- CONFIGURATION --------

# Kubernetes namespace
NAMESPACE="linkding"

# Pod label for Postgres
POSTGRES_LABEL="app=postgres"

# Database credentials
DB_USER="linkding"
DB_NAME="linkding"

# Backup archive to restore (required argument)
BACKUP_FILE="$1"

# Restore targets (match your setup)
LINKDING_CONFIG="/opt/linkding/config"
LINKDING_DATA="/opt/linkding/data"

# -------- CHECKS --------

if [ -z "$BACKUP_FILE" ]; then
    echo "Usage: $0 <backup_file.tar.gz>"
    exit 1
fi

if [ ! -f "$BACKUP_FILE" ]; then
    echo "ERROR: Backup file not found: $BACKUP_FILE"
    exit 1
fi

###############################################

echo "============================================="
echo "   LINKDING FULL RESTORE STARTED"
echo "   Backup file: $BACKUP_FILE"
echo "============================================="

WORK_DIR=$(mktemp -d)
echo "➤ Extracting backup..."
tar -xzf "$BACKUP_FILE" -C "$WORK_DIR"
echo "   ✓ Extracted to: $WORK_DIR"

###############################################
# STEP 1 — Restore PostgreSQL
###############################################

echo "➤ Locating PostgreSQL pod..."

DB_POD=$(kubectl get pod -n "$NAMESPACE" -l "$POSTGRES_LABEL" -o jsonpath='{.items[0].metadata.name}')

if [ -z "$DB_POD" ]; then
    echo "ERROR: Could not find Postgres pod in namespace $NAMESPACE"
    exit 1
fi

echo "   → Using pod: $DB_POD"

DB_FILE="$WORK_DIR/linkding_db.sql.gz"

if [ ! -f "$DB_FILE" ]; then
    echo "ERROR: Database file not found in backup."
    exit 1
fi

echo "➤ Restoring PostgreSQL database..."

# Drop and recreate DB cleanly
kubectl exec -n "$NAMESPACE" "$DB_POD" -- bash -c "
  dropdb -U $DB_USER $DB_NAME; \
  createdb -U $DB_USER $DB_NAME;
"

# Restore DB
gunzip -c "$DB_FILE" | kubectl exec -i -n "$NAMESPACE" "$DB_POD" -- psql -U "$DB_USER" "$DB_NAME"

echo "   ✓ Database restored."

###############################################
# STEP 2 — Restore config and data folders
###############################################

echo "➤ Restoring Linkding application files..."

if [ -d "$WORK_DIR/config" ]; then
    echo "   → Restoring config folder..."
    sudo rm -rf "$LINKDING_CONFIG"
    sudo cp -r "$WORK_DIR/config" "$LINKDING_CONFIG"
    echo "     ✓ Config restored."
fi

if [ -d "$WORK_DIR/data" ]; then
    echo "   → Restoring data folder..."
    sudo rm -rf "$LINKDING_DATA"
    sudo cp -r "$WORK_DIR/data" "$LINKDING_DATA"
    echo "     ✓ Data restored."
fi

###############################################
# STEP 3 — Restart Linkding
###############################################

echo "➤ Restarting Linkding deployment..."

kubectl rollout restart deployment/linkding -n "$NAMESPACE"

echo "   ✓ Linkding restarted."

###############################################

rm -rf "$WORK_DIR"

echo "============================================="
echo "   LINKDING RESTORE COMPLETED SUCCESSFULLY"
echo "============================================="
