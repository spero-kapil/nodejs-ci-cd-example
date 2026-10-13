#!/usr/bin/env bash
set -Eeuo pipefail

APP_ROOT="/var/www/Projects/Learning/node-ci-cd"
RELEASES="$APP_ROOT/releases"
CURRENT="$APP_ROOT/current"
SERVICE="my-node-app"
HEALTH_URL="http://127.0.0.1:3000/"

# Use a unique release directory for each commit.
RELEASE="$RELEASES/${GITHUB_SHA:?GITHUB_SHA is required}"

if [[ ! -d "$RELEASE" ]]; then
  mkdir -p "$RELEASE"

  rsync -a --delete \
    --exclude='.git/' \
    --exclude='.github/' \
    --exclude='.env' \
    --exclude='node_modules/' \
    --exclude='coverage/' \
    ./ "$RELEASE/"

  # Install production dependencies in the release.
  cd "$RELEASE"
  npm ci --omit=dev

  # Permit the runtime user to read application files.
  chgrp -R appdeploy "$RELEASE"
  chmod -R u+rwX,g+rX,o-rwx "$RELEASE"
fi

PREVIOUS="$(readlink -f "$CURRENT" 2>/dev/null || true)"

# Create the new link and atomically switch the active release.
ln -s "$RELEASE" "$APP_ROOT/current.new"
mv -Tf "$APP_ROOT/current.new" "$CURRENT"

rollback() {
  echo "Deployment failed; restoring the previous release."

  if [[ -n "$PREVIOUS" && -d "$PREVIOUS" ]]; then
    ln -s "$PREVIOUS" "$APP_ROOT/current.rollback"
    mv -Tf "$APP_ROOT/current.rollback" "$CURRENT"
    sudo -n /usr/bin/systemctl restart "$SERVICE" || true
  fi
}

# Restore the old release if service startup or health checks fail.
if ! sudo -n /usr/bin/systemctl restart "$SERVICE"; then
  rollback
  exit 1
fi

for attempt in $(seq 1 15); do
  if curl --fail --silent "$HEALTH_URL" >/dev/null; then
    echo "Deployment successful: $GITHUB_SHA"
    exit 0
  fi
  sleep 2
done

rollback
exit 1