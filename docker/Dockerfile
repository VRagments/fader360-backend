FROM elixir:1.14.3-slim as darth_base

ARG MIX_ENV

# essentials
ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get full-upgrade -y && apt-get install -y -qq --no-install-recommends \
    apt-transport-https \
    apt-utils \
    build-essential \
    ca-certificates \
    curl \
    gnupg \
    inotify-tools \
    libncurses5-dev \
    libssl-dev \
    openssl \
    unzip \
    wget \
    ffmpeg \
    imagemagick \
    file \
    make \
    && apt-get -qq clean \
    && rm -rf /var/lib/apt/lists/*

# nodejs
RUN curl -sL https://deb.nodesource.com/setup_16.x | bash -
RUN apt-get update && apt-get install -y -qq --no-install-recommends \
    nodejs \
    && apt-get -qq clean \
    && rm -rf /var/lib/apt/lists/*

# yarn
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list
RUN apt-get update && apt-get install -y -qq --no-install-recommends \
    yarn \
    && apt-get -qq clean \
    && rm -rf /var/lib/apt/lists/*

# hex & rebar
RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix hex.info

ADD work /work

WORKDIR /work
RUN make init
RUN mix assets.deploy
RUN mix release --path darth_release
RUN mix phx.digest.clean --all

ENTRYPOINT ["/bin/sh", "-c"]

FROM elixir:1.14.3-slim as darth_release

WORKDIR /root/
COPY --from=darth_base /work/darth_release darth_release

ADD startup.sh /root/
RUN chmod +x /root/startup.sh

ENTRYPOINT ["/root/startup.sh"]
