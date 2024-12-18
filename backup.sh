#!/bin/sh

# Set default values
BACKUP_DRIVE_NAME=${BACKUP_DRIVE_NAME:-cloud}
BACKUP_DIR=${BACKUP_DIR:-/data}
BACKUP_USERNAME=${BACKUP_USERNAME:-user}
BACKUP_DRIVE_PATH=${BACKUP_DRIVE_PATH:-/rclone/backups/$HOSTNAME/$BACKUP_USERNAME/daily}
OLD_DAYS_TO_DELETE=${OLD_DAYS_TO_DELETE}

# Check if backup directory exists
if [ ! -d "$BACKUP_DIR" ]; then
    echo "Backup directory does not exist" >&2
    exit 1
fi

# Change to backup directory
cd "$BACKUP_DIR"

# Create backup directory (if it doesn't exist)
#mkdir -pv "$BACKUP_DIR/.backup"

# Backup current user's crontab to specified directory
#crontab -l > "$BACKUP_DIR/.backup/crontab" || { echo "Failed to backup crontab" >&2; exit 1; }
#echo "Crontab backed up successfully"

# Generate .kopiaignore file
/scripts/generate-ignore.sh > "$BACKUP_DIR/.kopiaignore" || { echo "Failed to generate .kopiaignore file" >&2; exit 1; }
echo ".kopiaignore file generated successfully"

# Get hostname and date, ensure path safety
HOSTNAME=$(hostname -- | tr -dc '[:alnum:]-_')
DATE=$(date +%Y%m%d%H%M)

# Use tar to compress user directory and pipe to rclone
# If encryption key (BACKUP_ENCRYPTION_KEY) is set, encrypt the backup using GPG
# Use bzip2 for best compression, exclude files specified in .kopiaignore
# Finally upload to remote storage using rclone
if [ -n "$BACKUP_ENCRYPTION_KEY" ]; then
    # Create encrypted archive:
    # 1. tar package and exclude unwanted files
    # 2. gpg symmetric encryption
    # 3. rclone upload to remote storage with encryption identifier (.gpg)
    BZIP=--best tar --exclude-from="$BACKUP_DIR/.kopiaignore" -cjf - "$BACKUP_DIR" | gpg --symmetric --batch --passphrase "$BACKUP_ENCRYPTION_KEY" | rclone rcat "$BACKUP_DRIVE_NAME:$BACKUP_DRIVE_PATH/backup-$DATE.tar.bzip2.gpg" || { echo "Failed to create encrypted tar archive" >&2; exit 1; }
else
    # Create unencrypted archive:
    # 1. tar package and exclude unwanted files
    # 2. rclone direct upload to remote storage
    BZIP=--best tar --exclude-from="$BACKUP_DIR/.kopiaignore" -cjf - "$BACKUP_DIR" | rclone rcat "$BACKUP_DRIVE_NAME:$BACKUP_DRIVE_PATH/backup-$DATE.tar.bzip2" || { echo "Failed to create tar archive" >&2; exit 1; }
fi
echo "Tar archive created and uploaded successfully"

# Delete expired files from remote storage
if [ -n "$OLD_DAYS_TO_DELETE" ]
then
    rclone delete "$BACKUP_DRIVE_NAME:$BACKUP_DRIVE_PATH" --min-age ${OLD_DAYS_TO_DELETE}d || { echo "Failed to delete old backups" >&2; exit 1; }
    echo "Old backups deleted successfully"
fi

# Backup completed
echo "Backup completed successfully"
