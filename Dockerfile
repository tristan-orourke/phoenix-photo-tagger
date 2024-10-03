FROM elixir:1.17.3

# Build Args
ARG PHOENIX_VERSION=1.7.14

# Dependencies
RUN apt update \
  && apt upgrade -y \
  && apt install -y bash curl git build-essential inotify-tools

# Phoenix
RUN mix local.hex --force
RUN mix archive.install --force hex phx_new ${PHOENIX_VERSION}
RUN mix local.rebar --force

# App Directory
ENV APP_HOME /app
RUN mkdir -p $APP_HOME
WORKDIR $APP_HOME

# App Port
# EXPOSE 4000

# Default Command
CMD ["mix", "phx.server"]