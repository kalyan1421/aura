# Aura admin console v0 (Next.js 16, server-rendered, port 3320). Talks only to the NestJS /admin routes; holds no
# database credentials or service keys.
#
#   docker build -t aura-admin apps/admin
#   docker run --env-file apps/admin/.env.local -p 3320:3320 aura-admin
#
# Configuration is runtime environment only (apps/admin/.env.example; the build needs none of it). Runs as the
# unprivileged `node` user with NODE_ENV=production (secure cookies).
#
# next.config.ts does not set `output: 'standalone'` today, so the image runs `next start` on production
# dependencies. Adding that one line to next.config.ts makes this same Dockerfile ship Next's traced standalone
# server instead (much smaller image) — see docs/setup/ci-and-deploy.md. No other change is needed.
#
# Plain Dockerfile syntax (no BuildKit-only features): DigitalOcean App Platform builds Dockerfiles with Kaniko.

# Node 22 LTS on Alpine, pinned by digest (multi-arch index). Dependabot (.github/dependabot.yml) bumps it.
ARG NODE_IMAGE=node:22-alpine@sha256:b6f26b36c8ff49624cfdac716b8ea1138d606df02586a77d364bb5536a634f85

# ---- build --------------------------------------------------------------------------------------------------------
FROM ${NODE_IMAGE} AS build
ENV COREPACK_ENABLE_DOWNLOAD_PROMPT=0 \
    CI=true \
    NEXT_TELEMETRY_DISABLED=1
RUN corepack enable
WORKDIR /app
COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile
# What .dockerignore lets through: next.config.ts, tsconfig.json, src/ (and public/ if it ever exists).
COPY . .
RUN pnpm build
# Assemble /out: Next's standalone server when next.config.ts enables it, else .next + a clean install of the
# production dependencies (a fresh directory, so no dev-only packages linger in node_modules/.pnpm).
RUN mkdir /out \
 && if [ -f .next/standalone/server.js ]; then \
      cp -a .next/standalone/. /out/ \
      && mkdir -p /out/.next && cp -a .next/static /out/.next/static; \
    else \
      cp package.json pnpm-lock.yaml next.config.ts /out/ \
      && (cd /out && pnpm install --frozen-lockfile --prod --ignore-scripts) \
      && cp -a .next /out/.next \
      && rm -rf /out/.next/cache; \
    fi \
 && if [ -d public ]; then cp -a public /out/public; fi

# ---- runtime ------------------------------------------------------------------------------------------------------
FROM ${NODE_IMAGE} AS runtime
ENV NODE_ENV=production \
    NEXT_TELEMETRY_DISABLED=1 \
    PORT=3320 \
    HOSTNAME=0.0.0.0
WORKDIR /app
COPY --from=build /out ./
# Everything stays root-owned (read-only for the app) except Next's runtime cache directory.
RUN mkdir -p .next/cache && chown node:node .next/cache
USER node
EXPOSE 3320
HEALTHCHECK --interval=15s --timeout=5s --start-period=30s --retries=3 \
  CMD wget -q -T 4 -O /dev/null "http://127.0.0.1:${PORT}/login" || exit 1
# exec: node becomes PID 1 and receives SIGTERM directly.
CMD ["/bin/sh", "-c", "if [ -f server.js ]; then exec node server.js; else exec node node_modules/next/dist/bin/next start -H \"$HOSTNAME\" -p \"$PORT\"; fi"]
