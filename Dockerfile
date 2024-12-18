# 使用基础镜像
FROM alpine:latest

# 安装必要的工具
RUN apk add --no-cache tzdata tar rclone gpg

# 创建备份脚本
RUN mkdir -p /scripts
COPY backup.sh generate-ignore.sh /scripts/
RUN chmod +x /scripts/*.sh

# 设置容器启动命令
CMD ["/scripts/backup.sh"]
