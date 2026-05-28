# syntax=docker/dockerfile:1.7

ARG BUN_IMAGE=docker.io/oven/bun:1-debian
ARG NODE_IMAGE=docker.io/library/node:24-bookworm-slim

FROM ${BUN_IMAGE} AS bun

FROM ${NODE_IMAGE} AS builder

ARG T3CODE_REPO=https://github.com/pingdotgg/t3code.git
ARG T3CODE_REF=main

COPY --from=bun /usr/local/bin/bun /usr/local/bin/bun

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    ca-certificates \
    git \
    python3 \
    make \
    g++ \
    pkg-config \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /build

RUN git clone --depth 1 --branch "${T3CODE_REF}" "${T3CODE_REPO}" source \
  || (git clone "${T3CODE_REPO}" source && git -C source checkout "${T3CODE_REF}")

RUN mkdir -p /app/t3code/apps /app/t3code/packages /app/t3code/patches \
  && cp /build/source/package.json /build/source/bun.lock /build/source/tsconfig.base.json /app/t3code/ \
  && cp -R /build/source/patches/. /app/t3code/patches/ \
  && cp -R /build/source/apps/server /app/t3code/apps/server \
  && for package in contracts shared tailscale effect-acp effect-codex-app-server; do \
    cp -R "/build/source/packages/${package}" "/app/t3code/packages/${package}"; \
  done \
  && node -e "const fs=require('node:fs'); const root='/app/t3code/package.json'; const pkg=JSON.parse(fs.readFileSync(root,'utf8')); pkg.workspaces.packages=['apps/server','packages/*']; pkg.scripts={start:'bun run --cwd apps/server src/bin.ts'}; pkg.devDependencies={}; pkg.trustedDependencies=['node-pty']; fs.writeFileSync(root, JSON.stringify(pkg,null,2)+'\n'); const server='/app/t3code/apps/server/package.json'; const spkg=JSON.parse(fs.readFileSync(server,'utf8')); delete spkg.devDependencies['@t3tools/web']; fs.writeFileSync(server, JSON.stringify(spkg,null,2)+'\n');"

WORKDIR /app/t3code

RUN bun install

FROM ${NODE_IMAGE} AS runtime

ARG CLAUDE_CODE_VERSION=latest
ARG CODEX_CLI_VERSION=latest
ARG OPENCODE_VERSION=latest

COPY --from=bun /usr/local/bin/bun /usr/local/bin/bun

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    git \
    gosu \
    openssh-client \
    procps \
    ripgrep \
    tini \
  && rm -rf /var/lib/apt/lists/*

RUN npm install -g \
    "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}" \
    "@openai/codex@${CODEX_CLI_VERSION}" \
    "opencode-ai@${OPENCODE_VERSION}" \
  && npm cache clean --force

RUN mkdir -p /data/t3code /workspace \
  && chown -R node:node /data/t3code /workspace /home/node

COPY --from=builder --chown=node:node /app/t3code /opt/t3code
COPY docker-entrypoint.sh /usr/local/bin/t3code-entrypoint

RUN chmod +x /usr/local/bin/t3code-entrypoint

ENV HOME=/home/node \
  T3CODE_HOME=/data/t3code \
  T3CODE_WORKSPACE=/workspace \
  T3CODE_HOST=0.0.0.0 \
  T3CODE_PORT=3773 \
  T3CODE_MODE=web \
  T3CODE_NO_BROWSER=true \
  NODE_ENV=production

WORKDIR /workspace

EXPOSE 3773

ENTRYPOINT ["tini", "--", "t3code-entrypoint"]
