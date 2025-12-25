#!/usr/bin/env bash
set -euo pipefail
# Linkding Database Restore Script
# Supports both PostgreSQL custom format (.sql.gz) and plain SQL dumps

# Kubernetes namespace
NAMESPACE="linkding"

# Database credentials
DB_USER="linkding"
DB_NAME="linkding"

# Backup file to restore (required argument)
BACKUP_FILE="${1:-}"

# Usage
usage() {
    echo "Usage: $0 <backup_file.sql.gz>"
    echo ""
    echo "Restores a linkding PostgreSQL backup to the Kubernetes cluster."
    echo "Supports both PostgreSQL custom format and plain SQL dumps."
    echo ""
    echo "Examples:"
    echo "  $0 linkding_backup_20251204_160352.sql.gz"
    echo "  $0 /path/to/backup.sql.gz"
    exit 1
}

# Checks
if [ -z "$BACKUP_FILE" ]; then
    usage
fi

if [ ! -f "$BACKUP_FILE" ]; then
    echo "ERROR: Backup file not found: $BACKUP_FILE"
    exit 1
fi

echo "============================================="
echo "   LINKDING DATABASE RESTORE"
echo "   Backup file: $BACKUP_FILE"
echo "============================================="

# Find postgres pod
echo "Finding PostgreSQL pod..."
DB_POD=$(kubectl get pod -n "$NAMESPACE" -l app=postgres -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -z "$DB_POD" ]; then
    echo "ERROR: Could not find Postgres pod in namespace $NAMESPACE"
    exit 1
fi
echo "  Using pod: $DB_POD"

# Copy backup to pod
echo "Copying backup file to pod..."
kubectl cp "$BACKUP_FILE" "$NAMESPACE/$DB_POD:/tmp/backup.sql.gz"
echo "  Done."

# Drop and recreate database
echo "Recreating database..."
kubectl exec -n "$NAMESPACE" "$DB_POD" -- dropdb -U "$DB_USER" --if-exists "$DB_NAME"
kubectl exec -n "$NAMESPACE" "$DB_POD" -- createdb -U "$DB_USER" "$DB_NAME"
echo "  Done."

# Detect backup format and restore
echo "Restoring database..."

# Try pg_restore first (custom format), fall back to psql (plain SQL)
if kubectl exec -n "$NAMESPACE" "$DB_POD" -- sh -c "gunzip -c /tmp/backup.sql.gz | pg_restore -U $DB_USER -d $DB_NAME --no-owner --no-privileges 2>/dev/null"; then
    echo "  Restored using pg_restore (custom format)."
else
    echo "  Custom format failed, trying plain SQL..."
    kubectl exec -n "$NAMESPACE" "$DB_POD" -- sh -c "gunzip -c /tmp/backup.sql.gz | psql -U $DB_USER -d $DB_NAME"
    echo "  Restored using psql (plain SQL)."
fi

# Cleanup
echo "Cleaning up..."
kubectl exec -n "$NAMESPACE" "$DB_POD" -- rm -f /tmp/backup.sql.gz
echo "  Done."

# Restart linkding
echo "Restarting Linkding deployment..."
kubectl rollout restart deployment/linkding -n "$NAMESPACE"
kubectl rollout status deployment/linkding -n "$NAMESPACE" --timeout=120s
echo "  Done."

echo "============================================="
echo "   RESTORE COMPLETED SUCCESSFULLY"
echo "============================================="
