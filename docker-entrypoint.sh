#!/bin/bash
set -e

# Fix permissions for Hermes home directory
# This script runs as root before switching to the hermes user
# to ensure the mounted volume has correct ownership

echo "Setting up Hermes directory permissions..."

# Get UID and GID from environment or use defaults
HERMES_UID=${HERMES_UID:-10000}
HERMES_GID=${HERMES_GID:-10000}
HERMES_HOME=${HERMES_HOME:-/home/hermes}

# Create hermes user if it doesn't exist
if ! id -u hermes > /dev/null 2>&1; then
    echo "Creating hermes user with UID $HERMES_UID and GID $HERMES_GID"
    groupadd -g $HERMES_GID hermes || true
    useradd -u $HERMES_UID -g $HERMES_GID -d $HERMES_HOME -s /bin/bash hermes || true
fi

# Fix ownership of HERMES_HOME directory
if [ -d "$HERMES_HOME" ]; then
    echo "Fixing ownership of $HERMES_HOME to $HERMES_UID:$HERMES_GID"
    chown -R $HERMES_UID:$HERMES_GID $HERMES_HOME
else
    echo "Creating $HERMES_HOME directory"
    mkdir -p $HERMES_HOME
    chown -R $HERMES_UID:$HERMES_GID $HERMES_HOME
fi

# Create necessary subdirectories with correct permissions
echo "Creating Hermes subdirectories..."
for dir in cron sessions logs hooks memories skills skins plans workspace; do
    mkdir -p "$HERMES_HOME/$dir"
    chown $HERMES_UID:$HERMES_GID "$HERMES_HOME/$dir"
done

# Also fix /opt/data permissions
if [ -d "/opt/data" ]; then
    echo "Fixing ownership of /opt/data to $HERMES_UID:$HERMES_GID"
    chown -R $HERMES_UID:$HERMES_GID /opt/data
fi

echo "Permissions setup complete. Starting Hermes..."

# Execute the command (Docker will handle user switching via user directive)
exec "$@"
