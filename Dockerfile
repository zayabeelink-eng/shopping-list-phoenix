FROM hexpm/elixir:1.18.1-erlang-27.2-alpine-3.21.2 AS builder
RUN apk add --no-cache build-base git nodejs npm ca-certificates && update-ca-certificates
WORKDIR /app
RUN mix local.hex --force && mix local.rebar --force
ENV MIX_ENV="prod"
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mix deps.compile
COPY config config
COPY lib lib
COPY priv priv
COPY assets assets
RUN cd assets && npm ci
RUN mix assets.build
RUN mix compile
RUN mix release --overwrite

FROM alpine:3.21.2
RUN apk add --no-cache libstdc++ openssl ncurses-libs tzdata sqlite-dev
WORKDIR /app
RUN chown nobody:nobody /app
USER nobody:nobody
COPY --from=builder --chown=nobody:nobody /app/_build/prod/rel/shopping_list ./
ENV HOME=/app
ENV MIX_ENV="prod"
ENV PORT=4000
EXPOSE 4000
CMD ["/app/bin/shopping_list", "start"]
