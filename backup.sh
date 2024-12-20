#!/bin/sh

# Set strict mode
set -xeuo pipefail

# Set default values
BACKUP_DRIVE_NAME=${BACKUP_DRIVE_NAME:-cloud}
BACKUP_DIR=${BACKUP_DIR:-/data}
BACKUP_USERNAME=${BACKUP_USERNAME:-user}
BACKUP_DRIVE_PATH=${BACKUP_DRIVE_PATH:-/rclone/backups/$HOSTNAME/$BACKUP_USERNAME/daily}
#OLD_DAYS_TO_DELETE=${OLD_DAYS_TO_DELETE:-7}  # Default to 7 days retention
COMPRESSION_LEVEL=${COMPRESSION_LEVEL:-9}     # Maximum compression by default

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Error handling function
error_exit() {
    log "ERROR: $1"
    exit 1
}

# Cleanup function
cleanup() {
    if [ $? -ne 0 ]; then
        log "Backup failed - cleaning up..."
        # 如果有临时文件，可以在这里清理
    fi
    exit $?
}

# Set trap for cleanup
trap cleanup EXIT

# Check if backup directory exists
if [ ! -d "$BACKUP_DIR" ]; then
    error_exit "Backup directory '$BACKUP_DIR' does not exist"
fi

# Change to backup directory
cd "$BACKUP_DIR" || error_exit "Failed to change to backup directory '$BACKUP_DIR'"

# Generate .kopiaignore file
/scripts/generate-ignore.sh > "$BACKUP_DIR/.kopiaignore" || error_exit "Failed to generate .kopiaignore file"
log "Ignore patterns generated successfully"

# Get hostname and date, ensure path safety
HOSTNAME=$(hostname | tr -dc 'a-zA-Z0-9-_')
DATE=$(date +%Y%m%d%H%M)
BACKUP_FILE="backup-$DATE.tar.bz2"
[ -n "${BACKUP_ENCRYPTION_KEY:-}" ] && BACKUP_FILE="$BACKUP_FILE.gpg"

# Clean up old backups if OLD_DAYS_TO_DELETE is set
if [ -n "${OLD_DAYS_TO_DELETE:-}" ]; then
    log "Cleaning up backups older than $OLD_DAYS_TO_DELETE days..."
    rclone delete --min-age "${OLD_DAYS_TO_DELETE}d" "$BACKUP_DRIVE_NAME:$BACKUP_DRIVE_PATH" || log "Warning: Failed to clean up old backups"
fi

# Record start time
START_TIME=$(date '+%Y-%m-%d %H:%M:%S')
log "Starting backup process at $START_TIME"
log "Backup target: $BACKUP_DRIVE_NAME:$BACKUP_DRIVE_PATH/$BACKUP_FILE"

# Create and upload backup with progress indication
if [ -n "${BACKUP_ENCRYPTION_KEY:-}" ]; then
    log "Creating encrypted backup..."
    tar --exclude-from="$BACKUP_DIR/.kopiaignore" -c "$BACKUP_DIR" | \
    bzip2 "-$COMPRESSION_LEVEL" | \
    gpg --quiet --symmetric --batch --passphrase "$BACKUP_ENCRYPTION_KEY" | \
    rclone rcat --progress "$BACKUP_DRIVE_NAME:$BACKUP_DRIVE_PATH/$BACKUP_FILE" || \
    error_exit "Failed to create encrypted backup"
else
    log "Creating unencrypted backup..."
    tar --exclude-from="$BACKUP_DIR/.kopiaignore" -c "$BACKUP_DIR" | \
    bzip2 "-$COMPRESSION_LEVEL" | \
    rclone rcat --progress "$BACKUP_DRIVE_NAME:$BACKUP_DRIVE_PATH/$BACKUP_FILE" || \
    error_exit "Failed to create backup"
fi

# Verify backup exists and get its size
if ! BACKUP_SIZE=$(rclone size "$BACKUP_DRIVE_NAME:$BACKUP_DRIVE_PATH/$BACKUP_FILE" 2>/dev/null); then
    error_exit "Backup file not found after upload - possible transfer error"
fi

# Record end time
END_TIME=$(date '+%Y-%m-%d %H:%M:%S')
log "Backup completed at $END_TIME"
log "Backup size: $BACKUP_SIZE"
log "Backup file: $BACKUP_DRIVE_NAME:$BACKUP_DRIVE_PATH/$BACKUP_FILE"
