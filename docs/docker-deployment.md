# Docker Deployment Guide

Deploy DimensionForge using Docker for development, testing, or self-hosted production environments.

## Prerequisites

- Docker 20.10+ installed
- Docker Compose v2.0+ installed
- At least 2GB RAM available
- PostgreSQL database (local or remote)
- Cloud storage account (Google Cloud Storage, AWS S3, or Azure Blob)

## Quick Start with Docker Compose

The fastest way to get DimensionForge running locally.

### 1. Clone and Configure

```bash
# Clone the repository
git clone https://github.com/liuspatt/dimension-forge.git
cd dimension-forge

# Copy environment template
cp .env.example .env

# Edit environment variables
nano .env
```

### 2. Environment Configuration

```bash
# .env file
# Database
DATABASE_URL=ecto://postgres:postgres@db:5432/dimension_forge_dev
POOL_SIZE=10

# Application
SECRET_KEY_BASE=your_64_character_secret_key_generate_with_mix_phx_gen_secret
PHX_HOST=localhost
PHX_SERVER=true
PORT=4000
MIX_ENV=prod

# Google Cloud Storage
GCS_BUCKET=your-bucket-name
GCP_PROJECT_ID=your-project-id
GOTH_JSON=/app/credentials.json

# Or AWS S3
# AWS_ACCESS_KEY_ID=your_access_key
# AWS_SECRET_ACCESS_KEY=your_secret_key
# AWS_REGION=us-west-2
# S3_BUCKET=your-bucket-name

# Or Azure Blob Storage
# AZURE_STORAGE_ACCOUNT=your_account
# AZURE_STORAGE_KEY=your_key
# AZURE_CONTAINER=your_container

# Optional
MAX_IMAGE_SIZE_MB=10
LOG_LEVEL=info
```

### 3. Start Services

```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f app

# Check status
docker-compose ps

# Run database migrations
docker-compose exec app mix ecto.migrate

# Your API is now running at http://localhost:4000
```

## Docker Compose Configuration

### Complete docker-compose.yml

```yaml
version: '3.8'

services:
  # PostgreSQL Database
  db:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: dimension_forge_dev
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 30s
      timeout: 10s
      retries: 3

  # Redis Cache (optional)
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    command: redis-server --appendonly yes

  # DimensionForge Application
  app:
    build: .
    depends_on:
      db:
        condition: service_healthy
    environment:
      - DATABASE_URL=ecto://postgres:postgres@db:5432/dimension_forge_dev
      - SECRET_KEY_BASE=${SECRET_KEY_BASE}
      - PHX_HOST=${PHX_HOST:-localhost}
      - PHX_SERVER=true
      - PORT=4000
      - MIX_ENV=${MIX_ENV:-prod}
      - POOL_SIZE=${POOL_SIZE:-10}
      - GCS_BUCKET=${GCS_BUCKET}
      - GCP_PROJECT_ID=${GCP_PROJECT_ID}
      - GOTH_JSON=/app/credentials.json
      - MAX_IMAGE_SIZE_MB=${MAX_IMAGE_SIZE_MB:-10}
      - LOG_LEVEL=${LOG_LEVEL:-info}
    ports:
      - "4000:4000"
    volumes:
      - ./credentials.json:/app/credentials.json:ro
      - uploaded_images:/app/uploads
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:4000/"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  # Nginx Reverse Proxy (optional)
  nginx:
    image: nginx:alpine
    depends_on:
      - app
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./ssl:/etc/ssl/certs:ro
    restart: unless-stopped

volumes:
  postgres_data:
  redis_data:
  uploaded_images:
```

### Production docker-compose.prod.yml

```yaml
version: '3.8'

services:
  app:
    image: dimension-forge:latest
    environment:
      - MIX_ENV=prod
      - DATABASE_URL=${DATABASE_URL}
      - SECRET_KEY_BASE=${SECRET_KEY_BASE}
      - PHX_HOST=${PHX_HOST}
    deploy:
      replicas: 3
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3
      resources:
        limits:
          memory: 1G
          cpus: '0.5'
        reservations:
          memory: 512M
          cpus: '0.25'

  nginx:
    deploy:
      replicas: 2
      restart_policy:
        condition: on-failure
```

## Standalone Docker Deployment

### 1. Build Custom Image

```dockerfile
# Dockerfile.prod
FROM elixir:1.15-alpine AS builder

# Install build dependencies
RUN apk add --no-cache \
    git \
    build-base \
    imagemagick \
    imagemagick-dev

# Set build ENV
ENV MIX_ENV=prod

# Create app directory
WORKDIR /app

# Copy mix files
COPY mix.exs mix.lock ./
RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix deps.get --only prod

# Copy source code
COPY . .

# Build release
RUN mix compile && \
    mix phx.digest && \
    mix release

# Production image
FROM alpine:3.18

# Install runtime dependencies
RUN apk add --no-cache \
    ncurses-libs \
    openssl \
    imagemagick \
    ca-certificates \
    curl

# Create app user
RUN addgroup -g 1000 app && \
    adduser -D -s /bin/sh -u 1000 -G app app

# Set app directory
WORKDIR /app

# Copy release from builder
COPY --from=builder --chown=app:app /app/_build/prod/rel/dimension_forge ./

# Create uploads directory
RUN mkdir -p /app/uploads && chown app:app /app/uploads

# Switch to app user
USER app

# Expose port
EXPOSE 4000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:4000/ || exit 1

# Start application
CMD ["./bin/dimension_forge", "start"]
```

```bash
# Build production image
docker build -f Dockerfile.prod -t dimension-forge:prod .

# Run container
docker run -d \
  --name dimension-forge \
  -p 4000:4000 \
  -e DATABASE_URL="your_database_url" \
  -e SECRET_KEY_BASE="your_secret_key" \
  -e PHX_HOST="your-domain.com" \
  -e GCS_BUCKET="your-bucket" \
  -e GCP_PROJECT_ID="your-project" \
  -v /path/to/credentials.json:/app/credentials.json:ro \
  dimension-forge:prod
```

## Development Setup

### Docker Compose for Development

```yaml
# docker-compose.dev.yml
version: '3.8'

services:
  db:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: dimension_forge_dev
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
    ports:
      - "5432:5432"
    volumes:
      - postgres_dev_data:/var/lib/postgresql/data

  app:
    build:
      context: .
      dockerfile: Dockerfile.dev
    depends_on:
      - db
    environment:
      - DATABASE_URL=ecto://postgres:postgres@db:5432/dimension_forge_dev
      - MIX_ENV=dev
      - PHX_SERVER=true
    ports:
      - "4000:4000"
      - "4001:4001"  # LiveReload
    volumes:
      - .:/app
      - mix_deps:/app/deps
      - mix_build:/app/_build
      - node_modules:/app/assets/node_modules
    command: mix phx.server

volumes:
  postgres_dev_data:
  mix_deps:
  mix_build:
  node_modules:
```

```dockerfile
# Dockerfile.dev
FROM elixir:1.15-alpine

# Install development dependencies
RUN apk add --no-cache \
    git \
    build-base \
    imagemagick \
    imagemagick-dev \
    inotify-tools \
    nodejs \
    npm

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Set work directory
WORKDIR /app

# Install dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get

# Copy source
COPY . .

# Expose ports
EXPOSE 4000 4001

# Start command
CMD ["mix", "phx.server"]
```

## Multi-Stage Production Build

```dockerfile
# Dockerfile
ARG ELIXIR_VERSION=1.15
ARG OTP_VERSION=26
ARG ALPINE_VERSION=3.18

FROM hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-alpine-${ALPINE_VERSION} AS builder

# Install build dependencies
RUN apk add --no-cache \
    git \
    build-base \
    imagemagick-dev

# Prepare build dir
WORKDIR /app

# Install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Set build ENV
ENV MIX_ENV=prod

# Install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# Copy compile-time config files
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

# Copy source code
COPY lib lib
COPY priv priv

# Compile and build release
RUN mix compile
RUN mix phx.digest
RUN mix release

# Start a new build stage for the runtime image
FROM alpine:${ALPINE_VERSION} AS runtime

RUN apk add --no-cache \
    openssl \
    ncurses-libs \
    imagemagick \
    ca-certificates

# Create app user
RUN addgroup -g 1000 app && \
    adduser -D -s /bin/sh -u 1000 -G app app

WORKDIR /app

# Copy built application
COPY --from=builder --chown=app:app /app/_build/prod/rel/dimension_forge ./

# Create required directories
RUN mkdir -p /app/uploads && chown -R app:app /app

USER app

EXPOSE 4000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD ./bin/dimension_forge rpc "1 + 1" || exit 1

CMD ["./bin/dimension_forge", "start"]
```

## Nginx Configuration

### nginx.conf

```nginx
events {
    worker_connections 1024;
}

http {
    upstream dimension_forge {
        server app:4000;
    }

    # Rate limiting
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
    limit_req_zone $binary_remote_addr zone=upload:10m rate=2r/s;

    server {
        listen 80;
        server_name localhost;

        # Redirect HTTP to HTTPS (uncomment for production)
        # return 301 https://$server_name$request_uri;

        # Client max body size for uploads
        client_max_body_size 20M;

        # API endpoints with rate limiting
        location /api/upload {
            limit_req zone=upload burst=5 nodelay;
            proxy_pass http://dimension_forge;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            # Upload timeout
            proxy_read_timeout 300s;
            proxy_send_timeout 300s;
        }

        location /api/ {
            limit_req zone=api burst=20 nodelay;
            proxy_pass http://dimension_forge;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        # Image serving (cacheable)
        location /image/ {
            proxy_pass http://dimension_forge;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            # Cache settings
            proxy_cache_valid 200 1d;
            proxy_cache_valid 404 1m;
            add_header X-Cache-Status $upstream_cache_status;
        }

        # Health check
        location / {
            proxy_pass http://dimension_forge;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }

    # HTTPS server (uncomment and configure for production)
    # server {
    #     listen 443 ssl http2;
    #     server_name your-domain.com;
    #
    #     ssl_certificate /etc/ssl/certs/fullchain.pem;
    #     ssl_certificate_key /etc/ssl/certs/privkey.pem;
    #
    #     # SSL configuration
    #     ssl_protocols TLSv1.2 TLSv1.3;
    #     ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512;
    #     ssl_prefer_server_ciphers off;
    #
    #     # Include the same location blocks as HTTP server
    # }
}
```

## Container Management

### Useful Docker Commands

```bash
# Build and start services
docker-compose up --build -d

# View logs
docker-compose logs -f app
docker-compose logs --tail=50 app

# Execute commands in container
docker-compose exec app mix ecto.migrate
docker-compose exec app iex -S mix

# Scale services
docker-compose up --scale app=3 -d

# Update and restart
docker-compose pull
docker-compose up -d

# Stop and remove
docker-compose down
docker-compose down -v  # Remove volumes too

# Monitor resources
docker stats
docker-compose top
```

### Database Operations

```bash
# Run migrations
docker-compose exec app mix ecto.migrate

# Create API key
docker-compose exec app mix run -e "
  {:ok, api_key} = DimensionForge.ApiKeys.create_api_key(%{
    \"name\" => \"Docker API\",
    \"project_name\" => \"docker-project\"
  })
  IO.puts(\"API Key: #{api_key.key}\")
"

# Database backup
docker-compose exec db pg_dump -U postgres dimension_forge_dev > backup.sql

# Database restore
cat backup.sql | docker-compose exec -T db psql -U postgres dimension_forge_dev
```

## Production Considerations

### 1. Security

```bash
# Use secrets for sensitive data
echo "your_secret_key" | docker secret create secret_key_base -
echo "your_database_url" | docker secret create database_url -

# Run with secrets
docker service create \
  --name dimension-forge \
  --secret secret_key_base \
  --secret database_url \
  --env SECRET_KEY_BASE_FILE=/run/secrets/secret_key_base \
  --env DATABASE_URL_FILE=/run/secrets/database_url \
  dimension-forge:prod
```

### 2. Monitoring

```yaml
# Add monitoring to docker-compose.yml
services:
  prometheus:
    image: prom/prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml

  grafana:
    image: grafana/grafana
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:
      - grafana_data:/var/lib/grafana

volumes:
  grafana_data:
```

### 3. Backup Strategy

```bash
# Automated backup script
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)

# Database backup
docker-compose exec -T db pg_dump -U postgres dimension_forge_prod > "backup_db_${DATE}.sql"

# Upload backup to cloud storage
gsutil cp "backup_db_${DATE}.sql" gs://your-backup-bucket/

# Cleanup old backups (keep last 7 days)
find . -name "backup_db_*.sql" -mtime +7 -delete
```

## Troubleshooting

### Common Issues

1. **Container won't start**
   ```bash
   # Check logs
   docker-compose logs app
   
   # Check container status
   docker-compose ps
   
   # Inspect container
   docker inspect dimension-forge_app_1
   ```

2. **Database connection errors**
   ```bash
   # Check database is running
   docker-compose ps db
   
   # Test connection
   docker-compose exec app mix ecto.create
   
   # Reset database
   docker-compose exec app mix ecto.reset
   ```

3. **Image processing failures**
   ```bash
   # Check ImageMagick
   docker-compose exec app convert -version
   
   # Check disk space
   docker system df
   
   # Clear unused images
   docker system prune -a
   ```

## Performance Optimization

### 1. Resource Limits

```yaml
# docker-compose.yml
services:
  app:
    deploy:
      resources:
        limits:
          memory: 1G
          cpus: '0.5'
        reservations:
          memory: 512M
          cpus: '0.25'
```

### 2. Caching

```bash
# Enable BuildKit for faster builds
export DOCKER_BUILDKIT=1

# Use multi-stage build cache
docker build --target builder -t dimension-forge:builder .
docker build --cache-from dimension-forge:builder -t dimension-forge:latest .
```

## Next Steps

1. **[Set up CI/CD pipeline](https://docs.docker.com/ci-cd/)**
2. **[Configure SSL certificates](https://letsencrypt.org/getting-started/)**
3. **[Set up monitoring](https://prometheus.io/docs/guides/dockerswarm/)**
4. **[Implement backup automation](https://docs.docker.com/storage/volumes/#backup-restore-or-migrate-data-volumes)**