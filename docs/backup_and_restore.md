chmod +x backup_linkding.sh
./backup_linkding.sh

Starting Linkding full backup...
Namespace: linkding
Database pod: postgres-0
Backup directory: /home/onion/backup
Backup file: /home/onion/backup/linkding_backup_20251204_160352.sql.gz
Defaulted container "postgres" out of: postgres, postgres-exporter
Backup successful!
Backup saved to: /home/onion/backup/linkding_backup_20251204_160352.sql.gz

Last 5 backups:
-rw-r--r-- 1 onion onion 46K Dec 4 16:03 linkding_backup_20251204_160352.sql.gz

~/backup/linkding_full_backup_20251202_235959.tar.gz
chmod +x linkding_full_restore.sh
./linkding_full_restore.sh ~/backup/linkding_full_backup_20251202_235959.tar.gz
This restore script completely overwrites your Linkding DB.
