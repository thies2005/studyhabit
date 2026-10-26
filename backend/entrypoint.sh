#!/bin/sh
set -e

# Strip accidental surrounding quotes from DATABASE_URL (e.g. from Coolify/Docker env UI)
DATABASE_URL=$(printf '%s' "${DATABASE_URL:-}" | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")

# Ensure DATABASE_URL has a valid postgresql:// or postgres:// protocol;
# otherwise construct it from DB_* environment variables.
case "$DATABASE_URL" in
  postgresql://*|postgres://*)
    export DATABASE_URL
    ;;
  *)
    if [ -n "${DB_PASSWORD:-}" ]; then
      export DATABASE_URL="postgresql://${DB_USER:-studyhabit}:${DB_PASSWORD}@${DB_HOST:-db}:${DB_PORT:-5432}/${DB_NAME:-studyhabit}"
    fi
    ;;
esac

# Run database migrations before starting the application
echo "Running database migrations..."
if ! npx prisma migrate deploy; then
  echo "Prisma migrate deploy failed. Checking if 20260708000000_init needs to be marked as rolled back..."
  npx prisma migrate resolve --rolled-back 20260708000000_init || true
  echo "Retrying prisma migrate deploy..."
  if ! npx prisma migrate deploy; then
    echo "Schema already exists from prior db push. Baselining 20260708000000_init as applied..."
    npx prisma migrate resolve --applied 20260708000000_init || true
    npx prisma migrate deploy
  fi
fi
echo "Database migrations completed successfully."

exec "$@"
