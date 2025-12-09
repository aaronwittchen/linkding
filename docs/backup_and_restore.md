## **Backup Linkding Database**

Make the backup script executable and run it:

```bash
chmod +x backup_linkding.sh
./backup_linkding.sh
```

**Example Output:**

```
Starting Linkding full backup...
Namespace: linkding
Database pod: postgres-0
Backup directory: /home/name/backup
Backup file: /home/name/backup/linkding_backup_20251204_160352.sql.gz
Defaulted container "postgres" out of: postgres, postgres-exporter
Backup successful!
Backup saved to: /home/name/backup/linkding_backup_20251204_160352.sql.gz
```

**List the last 5 backups:**

```bash
ls -lh /home/name/backup | tail -5
```

Example:

```
-rw-r--r-- 1 name name 46K Dec 4 16:03 linkding_backup_20251204_160352.sql.gz
-rw-r--r-- 1 name name 46K Dec 2 23:59 linkding_backup_20251202_235959.sql.gz
...
```

---

## **Restore Linkding Database**

Make the restore script executable and run it with a backup file:

```bash
chmod +x linkding_full_restore.sh
./linkding_full_restore.sh ~/backup/linkding_full_backup_20251202_235959.tar.gz
```

**Warning:** This restore script **completely overwrites** your Linkding database.
