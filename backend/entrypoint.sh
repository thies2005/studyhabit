#!/bin/sh
set -e

# Run database migrations before starting the application
echo "Running database migrations..."
if ! npx prisma migrate deploy; then
  echo "Prisma migrate deploy failed. Checking if 20260708000000_init needs to be marked as rolled back..."
  npx prisma migrate resolve --rolled-back 20260708000000_init || true
  echo "Retrying prisma migrate deploy..."
  npx prisma migrate deploy
fi
echo "Database migrations completed successfully."

exec "$@"
