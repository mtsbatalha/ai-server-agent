# Build stage - Install dependencies and build
FROM node:20-alpine AS builder

# Install OpenSSL and libc for Prisma
RUN apk add --no-cache openssl libc6-compat

# Install pnpm
RUN corepack enable && corepack prepare pnpm@latest --activate

WORKDIR /app

# Copy all files first
COPY . .

# Install all dependencies
RUN pnpm install --frozen-lockfile || pnpm install

# Generate Prisma Client using the binary directly (skip npx)
RUN ./apps/api/node_modules/.bin/prisma generate --schema=./prisma/schema.prisma

# Build NestJS
WORKDIR /app/apps/api
RUN pnpm build

# Runner stage - Production image
FROM node:20-alpine AS runner

# Install OpenSSL for Prisma runtime
RUN apk add --no-cache openssl libc6-compat

WORKDIR /app

# Create non-root user
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nestjs

# Copy built application and dependencies
COPY --from=builder /app/apps/api/dist ./dist
COPY --from=builder /app/apps/api/node_modules ./node_modules
COPY --from=builder /app/prisma ./prisma

# Set environment
ENV NODE_ENV=production
ENV API_PORT=3001

# Expose port range for fallback
EXPOSE 3001-3010

USER nestjs

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:${API_PORT}/api/health || exit 1

CMD ["node", "dist/main.js"]
