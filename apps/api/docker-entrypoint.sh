#!/bin/sh
set -e

echo "🔄 Running Prisma migrations..."
npx prisma migrate deploy --schema=/app/prisma/schema.prisma

echo "✅ Migrations complete. Starting API..."
exec node dist/main.js
