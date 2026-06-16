FROM node:22-bookworm AS build

WORKDIR /app

RUN apt-get update \
  && apt-get install -y --no-install-recommends python3 make g++ \
  && rm -rf /var/lib/apt/lists/*

COPY package.json package-lock.json ./
RUN npm ci

COPY tsconfig.json ./
COPY src ./src
COPY static ./static
RUN npm run build
RUN npm prune --omit=dev

FROM node:22-bookworm-slim AS runtime

ENV HOME=/home/node \
  BEETS_FRONTEND_PORT=5173 \
  PATH=/app/bin:/home/node/.local/bin:$PATH

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    ffmpeg \
    pipx \
    python3 \
    unzip \
  && rm -rf /var/lib/apt/lists/*

ARG UID=1000
ARG GID=1000

RUN groupmod --gid "${GID}" node \
  && usermod --uid "${UID}" --gid "${GID}" node \
  && mkdir -p /config/beets /config/yt-dlp /data/beets /inbox /music \
  && chown -R node:node /home/node /config /data /inbox /music

USER node
RUN pipx install beets \
  && pipx install 'yt-dlp[default]'

WORKDIR /app

COPY --from=build --chown=node:node /app/node_modules ./node_modules
COPY --from=build --chown=node:node /app/package.json ./package.json
COPY --from=build --chown=node:node /app/dist ./dist
COPY --chown=node:node bin ./bin
COPY --chown=node:node scripts ./scripts

EXPOSE 5173

CMD ["node", "dist/server.js"]
