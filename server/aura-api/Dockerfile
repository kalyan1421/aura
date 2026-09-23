# Aura API + worker (NestJS 11, raw pg, BullMQ). One image, two entrypoints:
#
#   API     node dist/main.js     (default)  HTTP :3310, GET /health → {status, db, redis}
#   worker  node dist/worker.js              BullMQ processors, GET /health on :3311
#
#   docker build -t aura-api server/aura-api
#   docker run --env-file server/aura-api/.env -p 3310:3310 aura-api
#   docker run --env-file server/aura-api/.env -p 3311:3311 aura-api node dist/worker.js
#
# Configuration is environment only (.env.example lists it; .env is never copied in). Runs as the unprivileged
# `node` user; the app files stay root-owned, so the process cannot modify its own code.
#
# Plain Dockerfile syntax (no BuildKit-only features such as RUN --mount or heredocs): DigitalOcean App Platform
# builds Dockerfiles with Kaniko. docs/setup/ci-and-deploy.md.
#
# Base image: Node 22 LTS on Alpine, pinned by digest (multi-arch index) in both FROM lines below. Dependabot
# (.github/dependabot.yml) proposes digest bumps; keep the two lines identical.

# ---- toolchain: pnpm from package.json "packageManager" via corepack --------------------------------------------
FROM node:22-alpine@sha256:b6f26b36c8ff49624cfdac716b8ea1138d606df02586a77d364bb5536a634f85 AS base
ENV COREPACK_ENABLE_DOWNLOAD_PROMPT=0 \
    CI=true
RUN corepack enable
WORKDIR /app
COPY package.json pnpm-lock.yaml ./

# ---- compile ------------------------------------------------------------------------------------------------------
FROM base AS build
RUN pnpm install --frozen-lockfile
COPY tsconfig.json tsconfig.build.json ./
COPY src ./src
RUN pnpm build

# ---- production dependencies only --------------------------------------------------------------------------------
FROM base AS prod-deps
RUN pnpm install --frozen-lockfile --prod

# ---- runtime -----------------------------------------------------------------------------------------------------
FROM node:22-alpine@sha256:b6f26b36c8ff49624cfdac716b8ea1138d606df02586a77d364bb5536a634f85 AS runtime
ENV NODE_ENV=production \
    PORT=3310 \
    WORKER_HEALTH_PORT=3311
WORKDIR /app
COPY --from=prod-deps /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY package.json ./
USER node
EXPOSE 3310 3311
# Healthy when this container's /health answers 200: the API's port for the API, the worker's port for the worker
# (each container runs one of them, so the other port is simply closed). 503 = database or Redis unreachable.
HEALTHCHECK --interval=15s --timeout=5s --start-period=30s --retries=3 \
  CMD wget -q -T 4 -O /dev/null "http://127.0.0.1:${PORT}/health" \
   || wget -q -T 4 -O /dev/null "http://127.0.0.1:${WORKER_HEALTH_PORT}/health" \
   || exit 1
CMD ["node", "dist/main.js"]
