FROM hexpm/elixir:1.18.1-erlang-27.2-alpine-3.21.2 AS builder
RUN apk add --no-cache build-base git nodejs npm ca-certificates ca-certificates-bundle curl
RUN update-ca-certificates --fresh
WORKDIR /app
RUN mix archive.install github hexpm/hex --force
RUN curl -fsSL -o /usr/local/bin/rebar3 "https://github.com/erlang/rebar3/releases/download/3.24.0/rebar3" && \
    chmod +x /usr/local/bin/rebar3
ENV MIX_REBAR3=/usr/local/bin/rebar3
ENV MIX_ENV="prod"
COPY mix.exs mix.lock ./
COPY vendor vendor
RUN mix deps.get
RUN mix deps.compile
COPY config config
COPY lib lib
COPY priv priv
COPY assets assets
# Compile first to generate colocated hook files needed by asset build
RUN mix compile
# Download tailwindcss CLI via curl and build CSS
RUN curl -fsSL -o /usr/local/bin/tailwindcss \
      "https://github.com/tailwindlabs/tailwindcss/releases/download/v4.3.0/tailwindcss-linux-x64-musl" && \
    chmod +x /usr/local/bin/tailwindcss
RUN tailwindcss --input=assets/css/app.css --output=priv/static/assets/css/app.css
# Download esbuild CLI via curl and build JS
RUN curl -fsSL -o /tmp/esbuild.tgz \
      "https://registry.npmjs.org/@esbuild/linux-x64/-/linux-x64-0.25.4.tgz" && \
    tar -xzf /tmp/esbuild.tgz -C /tmp && \
    cp /tmp/package/bin/esbuild /usr/local/bin/esbuild && \
    chmod +x /usr/local/bin/esbuild && \
    rm -rf /tmp/esbuild.tgz /tmp/package
ENV NODE_PATH=/app/deps:/app/_build/prod
RUN esbuild assets/js/app.js --bundle --target=es2022 --outdir=priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=assets
# Digest static assets
RUN mix phx.digest
RUN mix release --overwrite

FROM alpine:3.21.2
RUN apk add --no-cache libstdc++ openssl ncurses-libs tzdata sqlite-dev
WORKDIR /app
RUN mkdir -p /app/data && chown nobody:nobody /app /app/data
USER nobody:nobody
COPY --from=builder --chown=nobody:nobody /app/_build/prod/rel/shopping_list ./
ENV HOME=/app
ENV MIX_ENV="prod"
ENV PORT=4000
EXPOSE 4000
CMD ["/app/bin/shopping_list", "start"]
