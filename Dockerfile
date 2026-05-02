FROM node:24-slim

# Build tools for better-sqlite3 native compilation + curl for healthcheck
RUN apt-get update && apt-get install -y python3 make g++ curl && rm -rf /var/lib/apt/lists/*

# Enable corepack for pnpm 10.33.2
RUN corepack enable && corepack prepare pnpm@10.33.2 --activate

WORKDIR /app

# Copy everything (use .dockerignore to exclude .git, node_modules, etc.)
COPY . .

# PATCH: bind to 0.0.0.0 instead of 127.0.0.1 (required for cloud deployment)
RUN sed -i "s/app\.listen(port, '127\.0\.0\.1'/app.listen(port, '0.0.0.0'/" apps/daemon/src/server.ts

# Install dependencies
RUN pnpm install --frozen-lockfile

# Build web (Next.js static export -> apps/web/out/)
RUN pnpm --filter @open-design/web build

# Build daemon (TypeScript -> apps/daemon/dist/)
RUN pnpm --filter @open-design/daemon build

# Create volume mount point for persistent data
RUN mkdir -p /data

EXPOSE 7456

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD curl -f http://localhost:${PORT:-7456}/api/health || exit 1

CMD ["sh", "-c", "export OD_PORT=${PORT:-7456} OD_DATA_DIR=/data && echo \"[deploy] starting on 0.0.0.0:${OD_PORT} data=/data\" && exec node apps/daemon/dist/cli.js --no-open --port ${OD_PORT}"]
