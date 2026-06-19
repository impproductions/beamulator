ARG ELIXIR_VERSION=1.17.3
ARG OTP_VERSION=27.1.2
ARG DEBIAN_VERSION=bookworm-20241016-slim

FROM hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION} AS build

ENV MIX_ENV=prod LANG=C.UTF-8

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential ca-certificates git \
  && rm -rf /var/lib/apt/lists/*

RUN mix local.hex --force && mix local.rebar --force

COPY mix.exs ./
COPY config config
RUN mix deps.get --only prod && mix deps.compile

COPY lib lib
RUN mix release

FROM debian:${DEBIAN_VERSION} AS runtime

RUN apt-get update && apt-get install -y --no-install-recommends \
    libstdc++6 libgcc-s1 ca-certificates locales openssl \
  && rm -rf /var/lib/apt/lists/* \
  && sed -i '/^# *en_US.UTF-8/s/^# *//' /etc/locale.gen \
  && locale-gen

ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

WORKDIR /app

COPY --from=build /app/_build/prod/rel/ingest_backend ./

ENV PORT=4100 \
    QUESTDB_HOST=questdb \
    QUESTDB_ILP_PORT=9009 \
    INGEST_TABLE=sensor_reading

EXPOSE 4100

CMD ["bin/ingest_backend", "start"]
