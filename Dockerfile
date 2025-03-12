FROM elixir:1.18-alpine AS builder

RUN apk add --no-cache build-base git

WORKDIR /app

ENV MIX_ENV=prod

COPY mix.exs mix.lock ./
RUN mix local.hex --force && mix local.rebar --force
RUN mix deps.get --only prod
RUN mix deps.compile

COPY . .
RUN mix compile
RUN mix release

FROM alpine:3.19

RUN apk add --no-cache libstdc++ ncurses-libs openssl

WORKDIR /app
COPY --from=builder /app/_build/prod/rel/beamulator ./

EXPOSE 8080

ENTRYPOINT ["bin/beamulator", "start"]