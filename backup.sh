#!/bin/sh

# 设置默认值
BACKUP_DRIVE_NAME=${BACKUP_DRIVE_NAME:-cloud}
BACKUP_DIR=${BACKUP_DIR:-/data}
BACKUP_USERNAME=${BACKUP_USERNAME:-user}
BACKUP_DRIVE_PATH=${BACKUP_DRIVE_PATH:-/rclone/backups/$HOSTNAME/$BACKUP_USERNAME/daily}
OLD_DAYS_TO_DELETE=${OLD_DAYS_TO_DELETE}

# 检查备份目录是否存在
if [ ! -d "$BACKUP_DIR" ]; then
    echo "Backup directory does not exist" >&2
    exit 1
fi

# 进入备份目录
cd "$BACKUP_DIR"

# 创建备份目录（如果不存在）
#mkdir -pv "$BACKUP_DIR/.backup"

# 备份当前用户的 crontab 到指定目录
#crontab -l > "$BACKUP_DIR/.backup/crontab" || { echo "Failed to backup crontab" >&2; exit 1; }
#echo "Crontab backed up successfully"

# 生成 .kopiaignore 文件
/scripts/generate-ignore.sh > "$BACKUP_DIR/.kopiaignore" || { echo "Failed to generate .kopiaignore file" >&2; exit 1; }
echo ".kopiaignore file generated successfully"

# 获取主机名和日期，确保路径安全
HOSTNAME=$(hostname -- | tr -dc '[:alnum:]-_')
DATE=$(date +%Y%m%d%H%M)

# 使用 tar 压缩用户目录并通过管道传递给 rclone
tar --exclude-from="$BACKUP_DIR/.kopiaignore" -czf - "$BACKUP_DIR" | rclone rcat "$BACKUP_DRIVE_NAME:$BACKUP_DRIVE_PATH/backup-$DATE.tar.gz" || { echo "Failed to create tar archive" >&2; exit 1; }
echo "Tar archive created and uploaded successfully"

# 删除远程存储中创建时间超期的文件
if [ -n "$OLD_DAYS_TO_DELETE" ]
then
    rclone delete "$BACKUP_DRIVE_NAME:$BACKUP_DRIVE_PATH" --min-age ${OLD_DAYS_TO_DELETE}d || { echo "Failed to delete old backups" >&2; exit 1; }
    echo "Old backups deleted successfully"
fi

# 备份完成
echo "Backup completed successfully"
