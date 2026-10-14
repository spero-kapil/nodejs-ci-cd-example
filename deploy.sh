#!/usr/bin/env bash
set -e

APP_ROOT="/var/www/Projects/Learning/node-ci-cd"
RELEASE="$APP_ROOT/releases/$GITHUB_SHA"
CURRENT="$APP_ROOT/current"
SERVICE="my-node-app"
HEALTH_URL="http://127.0.0.1:3000/"

# Create release
mkdir -p "$RELEASE"

# Copy application files
rsync -a --delete \
  --exclude='.git' \
  --exclude='.github' \
  --exclude='.env' \
  --exclude='node_modules' \
  ./ "$RELEASE/"

# Install dependencies
cd "$RELEASE"
npm ci --omit=dev

# Save previous release
PREVIOUS=$(readlink -f "$CURRENT" 2>/dev/null || true)

# Activate new release
ln -sfn "$RELEASE" "$APP_ROOT/current.new"
mv -Tf "$APP_ROOT/current.new" "$CURRENT"

# Restart application
if ! sudo -n /usr/bin/systemctl restart "$SERVICE"; then
  echo "Restart failed"

  if [ -n "$PREVIOUS" ]; then
    ln -sfn "$PREVIOUS" "$APP_ROOT/current.rollback"
    mv -Tf "$APP_ROOT/current.rollback" "$CURRENT"
    sudo -n /usr/bin/systemctl restart "$SERVICE" || true
  fi

  exit 1
fi

# Check application health
for i in $(seq 1 15); do
  if curl -fsS "$HEALTH_URL" >/dev/null; then
    echo "Deployment successful: $GITHUB_SHA"
    exit 0
  fi
  sleep 2
done

echo "Health check failed"

# Rollback
if [ -n "$PREVIOUS" ]; then
  ln -sfn "$PREVIOUS" "$APP_ROOT/current.rollback"
  mv -Tf "$APP_ROOT/current.rollback" "$CURRENT"
  sudo -n /usr/bin/systemctl restart "$SERVICE" || true
fi

exit 1
