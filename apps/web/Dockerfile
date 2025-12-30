# Build stage - Install dependencies and build
FROM node:20-alpine AS builder

# Install OpenSSL and libc
RUN apk add --no-cache openssl libc6-compat

WORKDIR /app

# Copy all project files
COPY . .

# Remove pnpm files to use npm cleanly
RUN rm -rf node_modules apps/*/node_modules pnpm-lock.yaml pnpm-workspace.yaml .pnpm 2>/dev/null || true

# Install dependencies using npm
WORKDIR /app/apps/web
RUN npm install --legacy-peer-deps

# Set Next.js build environment
ENV NEXT_TELEMETRY_DISABLED=1
ENV NODE_ENV=production

# Build
RUN npm run build

# Runner stage - Production image
FROM node:20-alpine AS runner

WORKDIR /app

# Create non-root user
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs

# Copy built files - standalone output
COPY --from=builder /app/apps/web/.next/standalone ./
COPY --from=builder /app/apps/web/.next/static ./.next/static

# Copy public folder if it exists
RUN mkdir -p ./public
COPY --from=builder /app/apps/web/public* ./public/ 2>/dev/null || true

# Set environment
ENV NODE_ENV=production
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

# Expose port range for fallback
EXPOSE 3000-3009

USER nextjs

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:${PORT}/ || exit 1

CMD ["node", "server.js"]
