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
RUN npm prune --omit=dev \
  && rm -rf \
    node_modules/@xterm \
    node_modules/node-pty/prebuilds/darwin-* \
    node_modules/node-pty/prebuilds/win32-*

FROM debian:bookworm-slim AS ffmpeg

ARG TARGETARCH

RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates curl xz-utils \
  && rm -rf /var/lib/apt/lists/* \
  && case "$TARGETARCH" in \
    amd64) \
      archive=ffmpeg-master-latest-linux64-gpl.tar.xz \
      ;; \
    arm64) \
      archive=ffmpeg-master-latest-linuxarm64-gpl.tar.xz \
      ;; \
    *) echo "unsupported architecture: $TARGETARCH" >&2; exit 1 ;; \
  esac \
  && release_url=https://github.com/yt-dlp/FFmpeg-Builds/releases/download/latest \
  && curl --fail --location --retry 3 \
    --output /tmp/checksums.sha256 "$release_url/checksums.sha256" \
  && curl --fail --location --retry 3 \
    --output "/tmp/$archive" "$release_url/$archive" \
  && cd /tmp \
  && grep "  $archive$" checksums.sha256 | sha256sum --check - \
  && mkdir /opt/ffmpeg \
  && tar --extract --xz --file "/tmp/$archive" --directory /opt/ffmpeg \
    --strip-components=2 \
    --wildcards '*/bin/ffmpeg' '*/bin/ffprobe'

FROM node:22-bookworm-slim AS runtime

ENV HOME=/home/node \
  EDITOR=vi \
  VISUAL=vi \
  PATH=/app/bin:/home/node/.local/bin:$PATH

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    pipx \
    python3 \
    unzip \
    vim-tiny \
  && rm -rf /var/lib/apt/lists/*

COPY --from=ffmpeg /opt/ffmpeg/ffmpeg /usr/local/bin/ffmpeg
COPY --from=ffmpeg /opt/ffmpeg/ffprobe /usr/local/bin/ffprobe

ARG UID=1000
ARG GID=1000

RUN groupmod --gid "${GID}" node \
  && usermod --uid "${UID}" --gid "${GID}" node \
  && mkdir -p /config/beets /config/gamdl /config/yt-dlp /data/beets /inbox /music \
  && chown -R node:node /home/node /config /data /inbox /music

USER node
RUN pipx install beets \
  && pipx install gamdl \
  && pipx install 'yt-dlp[default]' \
  && rm -rf /home/node/.cache/pip

WORKDIR /app

COPY --from=build --chown=node:node /app/node_modules ./node_modules
COPY --from=build --chown=node:node /app/package.json ./package.json
COPY --from=build --chown=node:node /app/dist ./dist
COPY --chown=node:node bin ./bin
COPY --chown=node:node scripts ./scripts

EXPOSE 5173

CMD ["node", "dist/server.js"]
