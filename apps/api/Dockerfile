# Build stage
FROM node:20-alpine AS deps

# Install pnpm
RUN corepack enable && corepack prepare pnpm@latest --activate

WORKDIR /app

# Copy workspace config
COPY pnpm-workspace.yaml ./
COPY package.json ./
COPY apps/api/package.json ./apps/api/
COPY prisma ./prisma/

# Install dependencies
RUN pnpm install --frozen-lockfile --ignore-scripts || pnpm install --ignore-scripts

# Builder stage
FROM node:20-alpine AS builder

RUN corepack enable && corepack prepare pnpm@latest --activate

WORKDIR /app

# Copy deps
COPY --from=deps /app/node_modules ./node_modules
COPY --from=deps /app/apps/api/node_modules ./apps/api/node_modules

# Copy source
COPY . .

# Generate Prisma Client
RUN cd apps/api && pnpm prisma:generate

# Build
RUN cd apps/api && pnpm build

# Runner stage
FROM node:20-alpine AS runner

WORKDIR /app

# Create non-root user
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nestjs

# Copy built files
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
