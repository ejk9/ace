# Single-stage build optimized for Railway - using regular slim for faster builds
FROM hexpm/elixir:1.15.7-erlang-26.1.2-debian-bookworm-20231009-slim

# Install system dependencies in a single layer
RUN apt-get update -y && apt-get install -y \
  build-essential \
  git \
  nodejs \
  npm \
  curl \
  locales \
  ca-certificates \
  --no-install-recommends \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# Set locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# Set working directory
WORKDIR /app

# Install hex and rebar
RUN mix local.hex --force && mix local.rebar --force

# Set production environment
ENV MIX_ENV=prod
ENV NODE_ENV=production
ENV PHX_SERVER=true

# Copy dependency files first for better Docker layer caching
COPY mix.exs mix.lock package*.json ./

# Get production dependencies only
RUN mix deps.get --only prod

# Install Node.js dependencies
RUN npm ci --only=production

# Copy source code
COPY . .

# Compile everything and build release in minimal steps
RUN mix deps.compile \
  && mix compile \
  && mix assets.setup \
  && mix assets.deploy \
  && mix release \
  && rm -rf _build/prod/lib/*/priv/static \
  && rm -rf node_modules

# Expose port
EXPOSE 4000

# Start the application directly (no multi-stage complexity)
CMD ["_build/prod/rel/ace_app/bin/ace_app", "start"]