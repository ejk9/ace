# Use the official Elixir image
FROM hexpm/elixir:1.15.7-erlang-26.1.2-debian-bookworm-20231009-slim

# Install system dependencies
RUN apt-get update -y && apt-get install -y \
  build-essential \
  git \
  nodejs \
  npm \
  inotify-tools \
  && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Create app directory
WORKDIR /app

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Copy mix files
COPY mix.exs mix.lock ./
RUN mix deps.get --only prod

# Copy package.json files for Node.js dependencies (root level only)
COPY package*.json ./

# Install Node.js dependencies (for E2E tests and development tools)
RUN npm install

# Copy source code
COPY . .

# Compile dependencies
RUN mix deps.compile

# Setup and compile assets (Phoenix uses esbuild/tailwind directly)
RUN mix assets.setup
RUN mix assets.deploy

# Compile the release
RUN MIX_ENV=prod mix compile

# Build the release
RUN MIX_ENV=prod mix release

# Runtime stage
FROM debian:bookworm-slim

# Install runtime dependencies
RUN apt-get update -y && apt-get install -y \
  libstdc++6 \
  openssl \
  libncurses5 \
  locales \
  ca-certificates \
  && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# Create app user
RUN useradd --create-home app
WORKDIR /app
USER app

# Copy the release
COPY --from=0 --chown=app:app /app/_build/prod/rel/ace_app ./

# Expose port
EXPOSE 4000

# Set environment
ENV MIX_ENV=prod
ENV PHX_SERVER=true

# Start the application
CMD ["bin/ace_app", "start"]