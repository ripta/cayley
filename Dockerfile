FROM golang:1.24 AS builder

ARG VERSION=v0.8.x-dev

# Create filesystem for minimal image
WORKDIR /fs

RUN mkdir -p etc/ssl/certs lib/$(uname -m)-linux-gnu tmp bin data; \
    # Copy CA Certificates
    cp /etc/ssl/certs/ca-certificates.crt etc/ssl/certs/ca-certificates.crt; \
    # Copy C standard library
    cp /lib/$(uname -m)-linux-gnu/libc.* lib/$(uname -m)-linux-gnu/

# Set up workdir for compiling
WORKDIR /src

# Copy dependencies and install first
COPY go.mod go.sum ./
RUN go mod download

# Add all the other files
COPY . .

# Pass a Git short SHA as build information to be used for displaying version
RUN GIT_SHA=$(git rev-parse --short=12 HEAD); \
    go build \
    -ldflags="-linkmode external -extldflags -static -X github.com/cayleygraph/cayley/version.Version=$VERSION -X github.com/cayleygraph/cayley/version.GitHash=$GIT_SHA" \
    -a \
    -installsuffix cgo \
    -o /fs/bin/cayley \
    -v \
    ./cmd/cayley

# Move persisted configuration into filesystem
RUN mv configurations/persisted.json /fs/etc/cayley.json

WORKDIR /fs

# Initialize bolt indexes file
RUN ./bin/cayley init --config etc/cayley.json

FROM scratch

# Copy filesystem as root
COPY --from=builder /fs /

# Define volume for configuration and data persistence. If you're using a
# backend like bolt, make sure the file is saved to this directory.
VOLUME [ "/data" ]

EXPOSE 64210

HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 CMD [ "cayley", "health" ]

# Adding everything to entrypoint allows us to init, load and serve only with
# arguments passed to docker run. For example:
# `docker run cayleygraph/cayley --init -i /data/my_data.nq`
ENTRYPOINT ["cayley", "http", "--host=:64210"]
