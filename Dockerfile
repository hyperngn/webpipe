FROM elixir:1.10.3

# Move to working directory /build
WORKDIR /build

ENV MIX_ENV prod

# install prereqs
RUN ["/bin/bash", "-c", "mix local.hex --force && mix local.rebar --force"]

# Copy the code into the container
COPY . .

# Build the application
RUN ["/bin/bash", "-c", "mix deps.get && mix release"]

# Export necessary port
EXPOSE 8000

# Command to run when starting the container
CMD ["_build/prod/rel/webpipe/bin/webpipe", "start"]
