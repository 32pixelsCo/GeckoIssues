#!/bin/bash
# Reset app state: delete local database and Keychain credentials.
# Run this to simulate a fresh first launch.

set -e

DB="$HOME/.gecko/data.db"
SERVICE="com.32pixels.GeckoIssues"

echo "Resetting Gecko Issues..."

# Delete database
if [ -f "$DB" ]; then
  rm "$DB"
  echo "  Deleted $DB"
else
  echo "  Database not found (already clean)"
fi

# Delete Keychain credentials
for KEY in github_access_token github_username; do
  if security delete-generic-password -s "$SERVICE" -a "$KEY" &>/dev/null; then
    echo "  Deleted Keychain: $KEY"
  else
    echo "  Keychain not found: $KEY (already clean)"
  fi
done

echo "Done. Next launch will show the onboarding wizard."
