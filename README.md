# DimensionForge

Images resize and optimization for cloud

## Overview

DimensionForge is a Phoenix application that provides image processing and optimization services with cloud storage integration. It supports Google Cloud Storage and includes comprehensive image transformation capabilities.

## Configuration

### Environment Variables

The following environment variables are required for production deployment:

#### Database Configuration
```bash
DATABASE_URL=ecto://USER:PASS@HOST/DATABASE
POOL_SIZE=10                    # Database connection pool size (default: 10)
ECTO_IPV6=false                # Enable IPv6 for database connections (default: false)
```

#### Application Configuration
```bash
SECRET_KEY_BASE=your_secret_key_base  # Generate with: mix phx.gen.secret
PHX_HOST=your-domain.com              # Your application domain
PORT=4000                             # Application port (default: 4000)
PHX_SERVER=true                       # Enable server in release mode
```

#### Cloud Storage Configuration
```bash
GOTH_JSON=path/to/service-account.json  # Google Cloud service account JSON file
GCS_BUCKET=your-bucket-name             # Google Cloud Storage bucket name
```

#### Optional Configuration
```bash
DNS_CLUSTER_QUERY=your-cluster-query    # For clustering support
```

### Local Development Setup

1. **Install dependencies:**
   ```bash
   mix setup
   ```

2. **Configure environment:**
   Create `.env` file in project root:
   ```bash
   DATABASE_URL=ecto://postgres:postgres@localhost/dimension_forge_dev
   SECRET_KEY_BASE=$(mix phx.gen.secret)
   GOTH_JSON=path/to/your/service-account.json
   GCS_BUCKET=your-dev-bucket
   ```

3. **Start the application:**
   ```bash
   mix phx.server
   ```

### Production Configuration

Production configuration is handled via `config/runtime.exs` which reads environment variables at runtime. Key configuration areas:

- **Database**: PostgreSQL with SSL support
- **Web Server**: Bandit web server with IPv6 support
- **Clustering**: DNS-based node discovery
- **Logging**: Info level logging
- **Email**: Swoosh with Finch HTTP client

## Cloud Deployment

### Docker Deployment

The application includes a production-ready Dockerfile with multi-stage builds:

1. **Build the Docker image:**
   ```bash
   docker build -t dimension-forge .
   ```

2. **Run with environment variables:**
   ```bash
   docker run -p 4000:4000 \
     -e DATABASE_URL=your_database_url \
     -e SECRET_KEY_BASE=your_secret_key \
     -e PHX_HOST=your-domain.com \
     -e GOTH_JSON=/app/service-account.json \
     -e GCS_BUCKET=your-bucket \
     -v /path/to/service-account.json:/app/service-account.json \
     dimension-forge
   ```

### Google Cloud Platform (GCP)

#### Cloud Run Deployment

1. **Build and push to Container Registry:**
   ```bash
   gcloud builds submit --tag gcr.io/PROJECT_ID/dimension-forge
   ```

2. **Deploy to Cloud Run:**
   ```bash
   gcloud run deploy dimension-forge \
     --image gcr.io/PROJECT_ID/dimension-forge \
     --platform managed \
     --region us-central1 \
     --allow-unauthenticated \
     --set-env-vars DATABASE_URL=your_database_url \
     --set-env-vars SECRET_KEY_BASE=your_secret_key \
     --set-env-vars PHX_HOST=your-cloud-run-url \
     --set-env-vars GCS_BUCKET=your-bucket
   ```

3. **Setup Cloud SQL (PostgreSQL):**
   ```bash
   gcloud sql instances create dimension-forge-db \
     --database-version=POSTGRES_15 \
     --tier=db-f1-micro \
     --region=us-central1
   
   gcloud sql databases create dimension_forge_prod \
     --instance=dimension-forge-db
   ```

#### Google Kubernetes Engine (GKE)

1. **Create cluster:**
   ```bash
   gcloud container clusters create dimension-forge-cluster \
     --zone us-central1-a \
     --num-nodes 3
   ```

2. **Deploy with Kubernetes manifests:**
   ```yaml
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: dimension-forge
   spec:
     replicas: 3
     selector:
       matchLabels:
         app: dimension-forge
     template:
       metadata:
         labels:
           app: dimension-forge
       spec:
         containers:
         - name: dimension-forge
           image: gcr.io/PROJECT_ID/dimension-forge
           ports:
           - containerPort: 4000
           env:
           - name: DATABASE_URL
             valueFrom:
               secretKeyRef:
                 name: app-secrets
                 key: database-url
           - name: SECRET_KEY_BASE
             valueFrom:
               secretKeyRef:
                 name: app-secrets
                 key: secret-key-base
   ```

### Amazon Web Services (AWS)

#### Elastic Container Service (ECS) with Fargate

1. **Push to ECR:**
   ```bash
   aws ecr create-repository --repository-name dimension-forge
   docker tag dimension-forge:latest AWS_ACCOUNT.dkr.ecr.REGION.amazonaws.com/dimension-forge:latest
   docker push AWS_ACCOUNT.dkr.ecr.REGION.amazonaws.com/dimension-forge:latest
   ```

2. **Create ECS task definition:**
   ```json
   {
     "family": "dimension-forge",
     "networkMode": "awsvpc",
     "requiresCompatibilities": ["FARGATE"],
     "cpu": "256",
     "memory": "512",
     "executionRoleArn": "arn:aws:iam::ACCOUNT:role/ecsTaskExecutionRole",
     "containerDefinitions": [
       {
         "name": "dimension-forge",
         "image": "AWS_ACCOUNT.dkr.ecr.REGION.amazonaws.com/dimension-forge:latest",
         "portMappings": [
           {
             "containerPort": 4000,
             "protocol": "tcp"
           }
         ],
         "environment": [
           {"name": "DATABASE_URL", "value": "your_rds_url"},
           {"name": "SECRET_KEY_BASE", "value": "your_secret"},
           {"name": "PHX_HOST", "value": "your-alb-domain.com"}
         ]
       }
     ]
   }
   ```

#### Elastic Beanstalk

1. **Create application:**
   ```bash
   eb init dimension-forge --platform docker --region us-west-2
   eb create production
   ```

2. **Configure environment variables in `.ebextensions/environment.config`:**
   ```yaml
   option_settings:
     aws:elasticbeanstalk:application:environment:
       DATABASE_URL: your_rds_url
       SECRET_KEY_BASE: your_secret_key
       PHX_HOST: your-eb-environment.us-west-2.elasticbeanstalk.com
   ```

### Microsoft Azure

#### Container Instances

1. **Create resource group:**
   ```bash
   az group create --name dimension-forge-rg --location eastus
   ```

2. **Deploy container:**
   ```bash
   az container create \
     --resource-group dimension-forge-rg \
     --name dimension-forge \
     --image your-registry/dimension-forge:latest \
     --cpu 1 \
     --memory 1 \
     --ports 4000 \
     --environment-variables \
       DATABASE_URL=your_postgres_url \
       SECRET_KEY_BASE=your_secret \
       PHX_HOST=your-domain.com
   ```

#### Azure Container Apps

```bash
az containerapp create \
  --name dimension-forge \
  --resource-group dimension-forge-rg \
  --environment dimension-forge-env \
  --image your-registry/dimension-forge:latest \
  --target-port 4000 \
  --ingress external \
  --env-vars DATABASE_URL=your_postgres_url SECRET_KEY_BASE=your_secret
```

### Heroku

1. **Create application:**
   ```bash
   heroku create dimension-forge-app
   ```

2. **Add PostgreSQL addon:**
   ```bash
   heroku addons:create heroku-postgresql:mini
   ```

3. **Set environment variables:**
   ```bash
   heroku config:set SECRET_KEY_BASE=$(mix phx.gen.secret)
   heroku config:set PHX_HOST=dimension-forge-app.herokuapp.com
   heroku config:set GCS_BUCKET=your-bucket
   ```

4. **Deploy:**
   ```bash
   git push heroku main
   ```

## Database Migrations

Run migrations in production:

```bash
# For releases
./bin/dimension_forge eval "DimensionForge.Release.migrate"

# For Docker
docker exec -it container_name /app/bin/dimension_forge eval "DimensionForge.Release.migrate"

# For Kubernetes
kubectl exec -it pod_name -- /app/bin/dimension_forge eval "DimensionForge.Release.migrate"
```

## Health Checks

The application exposes health check endpoints:

- `GET /health` - Basic health check
- `GET /metrics` - Prometheus metrics (if enabled)

## SSL/TLS Configuration

For production deployments, configure SSL in `config/runtime.exs`:

```elixir
config :dimension_forge, DimensionForgeWeb.Endpoint,
  https: [
    port: 443,
    cipher_suite: :strong,
    keyfile: System.get_env("SSL_KEY_PATH"),
    certfile: System.get_env("SSL_CERT_PATH")
  ],
  force_ssl: [hsts: true]
```

## Monitoring and Observability

The application includes:

- **Telemetry**: Built-in metrics collection
- **Live Dashboard**: Phoenix LiveDashboard for monitoring
- **Logging**: Structured logging with configurable levels
- **Health Checks**: Application and dependency health monitoring

## Security Considerations

- Always use HTTPS in production
- Rotate `SECRET_KEY_BASE` regularly
- Use database SSL connections
- Implement proper IAM roles for cloud services
- Store secrets in secure secret management services
- Enable HSTS headers
- Implement rate limiting if needed

## Troubleshooting

### Common Issues

1. **Database connection errors**: Verify `DATABASE_URL` and network connectivity
2. **Secret key errors**: Ensure `SECRET_KEY_BASE` is set and valid
3. **Cloud storage errors**: Check GCS credentials and bucket permissions
4. **Port binding issues**: Verify `PORT` environment variable matches container port

### Logs

View application logs:

```bash
# Docker
docker logs container_name

# Kubernetes
kubectl logs pod_name

# Cloud Run
gcloud logs read --service=dimension-forge

# Heroku
heroku logs --tail
```
