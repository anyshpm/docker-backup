# Use specific version of base image for stability
FROM alpine:3.19

# Set working directory
WORKDIR /scripts

# Install required tools
RUN apk add --no-cache \
    tzdata==2024a-r0 \
    tar==1.35-r2 \
    rclone==1.65.0-r3 \
    gpg==2.4.4-r0 \
    gpg-agent==2.4.4-r0 \
    && rm -rf /var/cache/apk/*

# Copy scripts and set permissions
COPY backup.sh generate-ignore.sh ./
RUN chmod +x *.sh

# Configure health check
HEALTHCHECK --interval=5m --timeout=3s \
    CMD rclone version || exit 1

# Set container entrypoint
ENTRYPOINT ["/scripts/backup.sh"]
