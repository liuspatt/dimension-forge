# Installation Guide

This guide covers the complete installation process for DimensionForge across different cloud platforms and deployment methods.

## Prerequisites

- **Elixir**: 1.14 or higher
- **Erlang/OTP**: 25 or higher
- **PostgreSQL**: 13 or higher
- **ImageMagick**: 7.0 or higher (for image processing)
- **Docker**: 20.10 or higher (for containerized deployments)

## Environment Variables

All deployments require these environment variables:

### Required Variables

```bash
# Database Configuration
DATABASE_URL=ecto://username:password@host:port/database_name

# Application Security
SECRET_KEY_BASE=your_64_character_secret_key

# Application Configuration
PHX_HOST=your-domain.com
PORT=4000
PHX_SERVER=true

# Cloud Storage (choose one)
# Google Cloud Storage
GOTH_JSON=path/to/service-account.json
GCS_BUCKET=your-bucket-name
GCP_PROJECT_ID=your-project-id

# AWS S3 (alternative)
AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key
AWS_REGION=us-west-2
S3_BUCKET=your-bucket-name

# Azure Blob Storage (alternative)
AZURE_STORAGE_ACCOUNT=your-account
AZURE_STORAGE_KEY=your-key
AZURE_CONTAINER=your-container
```

### Optional Variables

```bash
# Database Pool Size
POOL_SIZE=10

# IPv6 Support
ECTO_IPV6=false

# Image Processing Limits
MAX_IMAGE_SIZE_MB=10

# Clustering
DNS_CLUSTER_QUERY=dimension-forge.default.svc.cluster.local
```

## Quick Start Methods

### 1. One-Click Deploy

Deploy instantly to major cloud platforms:

[![Deploy to Heroku](https://www.herokucdn.com/deploy/button.svg)](https://heroku.com/deploy?template=https://github.com/your-username/dimension-forge)

[![Deploy to Google Cloud](https://deploy.cloud.run/button.svg)](https://deploy.cloud.run?git_repo=https://github.com/your-username/dimension-forge)

### 2. Docker Compose (Recommended for Development)

```bash
# Clone the repository
git clone https://github.com/your-username/dimension-forge.git
cd dimension-forge

# Copy environment template
cp .env.example .env

# Edit .env with your configuration
nano .env

# Start services
docker-compose up -d

# Run migrations
docker-compose exec app mix ecto.migrate

# Your API is now running at http://localhost:4000
```

### 3. Local Development Setup

```bash
# Install Elixir dependencies
mix deps.get

# Setup database
mix ecto.setup

# Start Phoenix server
mix phx.server

# Visit http://localhost:4000
```

## Cloud Platform Guides

### Google Cloud Platform

- **[Cloud Run](gcp-deployment.md#cloud-run)** - Serverless containers (recommended)
- **[Google Kubernetes Engine](gcp-deployment.md#gke)** - Managed Kubernetes
- **[Compute Engine](gcp-deployment.md#compute-engine)** - Virtual machines

### Amazon Web Services

- **[ECS Fargate](aws-deployment.md#ecs-fargate)** - Serverless containers
- **[Elastic Beanstalk](aws-deployment.md#elastic-beanstalk)** - Platform as a Service
- **[EKS](aws-deployment.md#eks)** - Managed Kubernetes

### Microsoft Azure

- **[Container Instances](azure-deployment.md#container-instances)** - Serverless containers
- **[Container Apps](azure-deployment.md#container-apps)** - Managed containers
- **[AKS](azure-deployment.md#aks)** - Managed Kubernetes

### Other Platforms

- **[Heroku](heroku-deployment.md)** - Platform as a Service
- **[DigitalOcean App Platform](digitalocean-deployment.md)** - Managed containers
- **[Railway](railway-deployment.md)** - Modern deployment platform

## Database Setup

### PostgreSQL Configuration

#### Local PostgreSQL

```bash
# Install PostgreSQL
# macOS
brew install postgresql
brew services start postgresql

# Ubuntu/Debian
sudo apt-get install postgresql postgresql-contrib
sudo systemctl start postgresql

# Create database and user
sudo -u postgres psql
CREATE DATABASE dimension_forge_prod;
CREATE USER dimension_forge WITH PASSWORD 'your_password';
GRANT ALL PRIVILEGES ON DATABASE dimension_forge_prod TO dimension_forge;
\q
```

#### Cloud Database Options

**Google Cloud SQL**
```bash
gcloud sql instances create dimension-forge-db \
  --database-version=POSTGRES_15 \
  --tier=db-f1-micro \
  --region=us-central1

gcloud sql databases create dimension_forge_prod \
  --instance=dimension-forge-db
```

**AWS RDS**
```bash
aws rds create-db-instance \
  --db-instance-identifier dimension-forge-db \
  --db-instance-class db.t3.micro \
  --engine postgres \
  --engine-version 15.3 \
  --allocated-storage 20 \
  --db-name dimension_forge_prod \
  --master-username admin \
  --master-user-password yourpassword
```

**Azure Database**
```bash
az postgres server create \
  --resource-group dimension-forge-rg \
  --name dimension-forge-db \
  --location eastus \
  --admin-user myadmin \
  --admin-password yourpassword \
  --sku-name B_Gen5_1

az postgres db create \
  --resource-group dimension-forge-rg \
  --server-name dimension-forge-db \
  --name dimension_forge_prod
```

## Cloud Storage Setup

### Google Cloud Storage

```bash
# Create bucket
gsutil mb gs://your-bucket-name

# Set CORS policy
gsutil cors set cors.json gs://your-bucket-name

# Create service account
gcloud iam service-accounts create dimension-forge-sa \
  --display-name "DimensionForge Service Account"

# Grant storage permissions
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:dimension-forge-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/storage.objectAdmin"

# Create and download key
gcloud iam service-accounts keys create credentials.json \
  --iam-account=dimension-forge-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com
```

### AWS S3

```bash
# Create bucket
aws s3 mb s3://your-bucket-name

# Set CORS policy
aws s3api put-bucket-cors \
  --bucket your-bucket-name \
  --cors-configuration file://cors.json

# Create IAM user
aws iam create-user --user-name dimension-forge-user

# Attach S3 policy
aws iam attach-user-policy \
  --user-name dimension-forge-user \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess

# Create access keys
aws iam create-access-key --user-name dimension-forge-user
```

### Azure Blob Storage

```bash
# Create storage account
az storage account create \
  --name dimensionforgestorage \
  --resource-group dimension-forge-rg \
  --location eastus \
  --sku Standard_LRS

# Create container
az storage container create \
  --name images \
  --account-name dimensionforgestorage

# Get connection string
az storage account show-connection-string \
  --name dimensionforgestorage \
  --resource-group dimension-forge-rg
```

## Security Configuration

### SSL/TLS Setup

For production, always use HTTPS. Here's how to configure SSL:

```elixir
# config/runtime.exs
config :dimension_forge, DimensionForgeWeb.Endpoint,
  https: [
    port: 443,
    cipher_suite: :strong,
    keyfile: System.get_env("SSL_KEY_PATH"),
    certfile: System.get_env("SSL_CERT_PATH")
  ],
  force_ssl: [hsts: true]
```

### API Key Management

```bash
# Generate a new API key via the console
docker-compose exec app mix run -e "
  {:ok, api_key} = DimensionForge.ApiKeys.create_api_key(%{
    \"name\" => \"Production API\",
    \"project_name\" => \"my-project\"
  })
  IO.puts(\"API Key: #{api_key.key}\")
"
```

## Health Checks

Set up health checks for your deployment:

```bash
# Application health
curl https://your-domain.com/

# Database health
curl https://your-domain.com/health/db

# Storage health
curl https://your-domain.com/health/storage
```

## Monitoring Setup

### Prometheus Metrics

```bash
# Enable metrics in production
export ENABLE_METRICS=true

# Metrics endpoint
curl https://your-domain.com/metrics
```

### Logging Configuration

```elixir
# config/runtime.exs
config :logger, level: :info

# JSON logging for cloud platforms
config :logger, :console,
  format: {LoggerJSON.Formatters.BasicLogger, :format},
  metadata: [:request_id]
```

## Performance Tuning

### Database Connections

```bash
# Adjust pool size based on your needs
export POOL_SIZE=20
```

### Image Processing

```bash
# Limit image size to prevent memory issues
export MAX_IMAGE_SIZE_MB=50

# Configure ImageMagick limits
export MAGICK_MEMORY_LIMIT=256MB
export MAGICK_DISK_LIMIT=1GB
```

## Troubleshooting

### Common Issues

1. **Database connection errors**
   ```bash
   # Check database connectivity
   mix ecto.create
   mix ecto.migrate
   ```

2. **Image processing failures**
   ```bash
   # Verify ImageMagick installation
   convert -version
   
   # Check memory limits
   identify -list resource
   ```

3. **Cloud storage errors**
   ```bash
   # Test GCS credentials
   gsutil ls gs://your-bucket-name
   
   # Test AWS credentials
   aws s3 ls s3://your-bucket-name
   ```

### Debug Mode

```bash
# Enable debug logging
export LOG_LEVEL=debug

# Start with verbose output
mix phx.server --verbose
```

## Next Steps

1. **[Configure your first project](project-management.md)**
2. **[Set up API keys](authentication.md)**
3. **[Test image uploads](api-reference.md#upload-endpoint)**
4. **[Configure monitoring](monitoring.md)**

## Support

- **Documentation**: [https://dimension-forge.github.io](https://dimension-forge.github.io)
- **GitHub Issues**: [Report bugs](https://github.com/your-username/dimension-forge/issues)
- **Discussions**: [Community support](https://github.com/your-username/dimension-forge/discussions)