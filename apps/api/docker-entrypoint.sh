#!/bin/sh
set -e

echo "🔄 Syncing database schema with Prisma..."
npx prisma db push --schema=/app/prisma/schema.prisma --accept-data-loss

echo "✅ Database sync complete. Starting API..."
exec node dist/main.js
