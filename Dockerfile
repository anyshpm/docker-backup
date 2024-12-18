FROM alpine:3.18

# Update software package repository and install necessary tools
RUN apk add --no-cache tzdata tar rclone gpg xz 

# Copy the backup script and ignore generator into the container
COPY backup.sh generate-ignore.sh /

# Make the scripts executable
RUN chmod +x /backup.sh /generate-ignore.sh

# Set the default command to run the backup script when the container starts
CMD ["/backup.sh"]
