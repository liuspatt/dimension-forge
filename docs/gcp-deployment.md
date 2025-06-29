# Google Cloud Platform Deployment

Deploy DimensionForge on Google Cloud Platform using Cloud Run, Google Kubernetes Engine, or Compute Engine.

## Prerequisites

- Google Cloud account with billing enabled
- `gcloud` CLI installed and configured
- Docker installed (for container builds)
- Project with required APIs enabled:
  - Cloud Run API
  - Cloud Build API
  - Cloud SQL Admin API
  - Google Cloud Storage API

## Cloud Run Deployment (Recommended)

Cloud Run provides serverless, automatic scaling with pay-per-use pricing.

### 1. Quick Deploy

```bash
# One-command deployment from source
gcloud run deploy dimension-forge \
  --source . \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars \
    PHX_SERVER=true,\
    MIX_ENV=prod,\
    DATABASE_URL="your_database_url",\
    SECRET_KEY_BASE="$(openssl rand -base64 48)",\
    GCS_BUCKET="your-bucket-name",\
    GCP_PROJECT_ID="your-project-id"
```

### 2. Step-by-Step Deployment

#### Set up Cloud SQL

```bash
# Create PostgreSQL instance
gcloud sql instances create dimension-forge-db \
  --database-version=POSTGRES_15 \
  --tier=db-f1-micro \
  --region=us-central1 \
  --storage-type=SSD \
  --storage-size=10GB \
  --backup-start-time=03:00

# Create database
gcloud sql databases create dimension_forge_prod \
  --instance=dimension-forge-db

# Create user
gcloud sql users create dimension_forge \
  --instance=dimension-forge-db \
  --password=your_secure_password

# Get connection name
gcloud sql instances describe dimension-forge-db \
  --format="value(connectionName)"
```

#### Create Cloud Storage Bucket

```bash
# Create bucket
gsutil mb -l us-central1 gs://your-bucket-name

# Enable uniform bucket-level access
gsutil uniformbucketlevelaccess set on gs://your-bucket-name

# Set CORS policy
cat > cors.json << EOF
[
  {
    "origin": ["*"],
    "method": ["GET", "HEAD"],
    "responseHeader": ["Content-Type", "Content-Length", "Date", "Server"],
    "maxAgeSeconds": 3600
  }
]
EOF

gsutil cors set cors.json gs://your-bucket-name

# Set public read access for images
gsutil iam ch allUsers:objectViewer gs://your-bucket-name
```

#### Create Service Account

```bash
# Create service account for the application
gcloud iam service-accounts create dimension-forge \
  --display-name="DimensionForge Service Account" \
  --description="Service account for DimensionForge image processing"

# Grant Cloud SQL Client role
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:dimension-forge@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/cloudsql.client"

# Grant Storage Admin role
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:dimension-forge@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/storage.objectAdmin"

# Create and download service account key
gcloud iam service-accounts keys create credentials.json \
  --iam-account=dimension-forge@YOUR_PROJECT_ID.iam.gserviceaccount.com
```

#### Build and Deploy Container

```bash
# Build container using Cloud Build
gcloud builds submit --tag gcr.io/YOUR_PROJECT_ID/dimension-forge

# Deploy to Cloud Run
gcloud run deploy dimension-forge \
  --image gcr.io/YOUR_PROJECT_ID/dimension-forge \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --memory 1Gi \
  --cpu 1 \
  --concurrency 80 \
  --timeout 900 \
  --service-account dimension-forge@YOUR_PROJECT_ID.iam.gserviceaccount.com \
  --add-cloudsql-instances YOUR_PROJECT_ID:us-central1:dimension-forge-db \
  --set-env-vars \
    PHX_SERVER=true,\
    MIX_ENV=prod,\
    DATABASE_URL="ecto://dimension_forge:your_password@localhost/dimension_forge_prod?socket_dir=/cloudsql/YOUR_PROJECT_ID:us-central1:dimension-forge-db",\
    SECRET_KEY_BASE="your_generated_secret",\
    GCS_BUCKET="your-bucket-name",\
    GCP_PROJECT_ID="YOUR_PROJECT_ID",\
    GOTH_JSON="/tmp/credentials.json",\
    POOL_SIZE="5"
```

#### Run Database Migrations

```bash
# Get Cloud Run service URL
SERVICE_URL=$(gcloud run services describe dimension-forge \
  --region=us-central1 \
  --format="value(status.url)")

# Run migrations via Cloud Run Jobs
gcloud run jobs create dimension-forge-migrate \
  --image gcr.io/YOUR_PROJECT_ID/dimension-forge \
  --region us-central1 \
  --service-account dimension-forge@YOUR_PROJECT_ID.iam.gserviceaccount.com \
  --add-cloudsql-instances YOUR_PROJECT_ID:us-central1:dimension-forge-db \
  --set-env-vars \
    MIX_ENV=prod,\
    DATABASE_URL="ecto://dimension_forge:your_password@localhost/dimension_forge_prod?socket_dir=/cloudsql/YOUR_PROJECT_ID:us-central1:dimension-forge-db" \
  --command="/app/bin/dimension_forge" \
  --args="eval,DimensionForge.Release.migrate"

# Execute migration job
gcloud run jobs execute dimension-forge-migrate --region us-central1
```

### 3. Environment Configuration

Create a `.env.cloud-run` file for Cloud Run-specific variables:

```bash
# Cloud Run Environment Variables
PHX_SERVER=true
MIX_ENV=prod
PORT=8080
PHX_HOST=your-service-hash-uc.a.run.app

# Database (with Cloud SQL Proxy)
DATABASE_URL=ecto://dimension_forge:password@localhost/dimension_forge_prod?socket_dir=/cloudsql/project:region:instance
POOL_SIZE=5

# Storage
GCS_BUCKET=your-bucket-name
GCP_PROJECT_ID=your-project-id
GOTH_JSON=/tmp/credentials.json

# Security
SECRET_KEY_BASE=your_64_character_secret_key

# Optional
MAX_IMAGE_SIZE_MB=10
LOG_LEVEL=info
```

## Google Kubernetes Engine (GKE)

For high-availability and advanced networking requirements.

### 1. Create GKE Cluster

```bash
# Create GKE cluster with Workload Identity
gcloud container clusters create dimension-forge-cluster \
  --zone us-central1-a \
  --num-nodes 3 \
  --machine-type e2-medium \
  --disk-size 50GB \
  --enable-autoscaling \
  --min-nodes 1 \
  --max-nodes 10 \
  --enable-autorepair \
  --enable-autoupgrade \
  --workload-pool=YOUR_PROJECT_ID.svc.id.goog

# Get cluster credentials
gcloud container clusters get-credentials dimension-forge-cluster \
  --zone us-central1-a
```

### 2. Set up Workload Identity

```bash
# Create Kubernetes service account
kubectl create serviceaccount dimension-forge-ksa

# Bind to Google service account
gcloud iam service-accounts add-iam-policy-binding \
  dimension-forge@YOUR_PROJECT_ID.iam.gserviceaccount.com \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:YOUR_PROJECT_ID.svc.id.goog[default/dimension-forge-ksa]"

# Annotate Kubernetes service account
kubectl annotate serviceaccount dimension-forge-ksa \
  iam.gke.io/gcp-service-account=dimension-forge@YOUR_PROJECT_ID.iam.gserviceaccount.com
```

### 3. Deploy Application

Create Kubernetes manifests:

```yaml
# k8s/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: dimension-forge
---
# k8s/secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: dimension-forge-secrets
  namespace: dimension-forge
type: Opaque
stringData:
  DATABASE_URL: "ecto://dimension_forge:password@cloud-sql-proxy:5432/dimension_forge_prod"
  SECRET_KEY_BASE: "your_secret_key_base_64_chars_long"
  GCS_BUCKET: "your-bucket-name"
  GCP_PROJECT_ID: "your-project-id"
---
# k8s/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dimension-forge
  namespace: dimension-forge
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
      serviceAccountName: dimension-forge-ksa
      containers:
      - name: dimension-forge
        image: gcr.io/YOUR_PROJECT_ID/dimension-forge:latest
        ports:
        - containerPort: 4000
        envFrom:
        - secretRef:
            name: dimension-forge-secrets
        env:
        - name: PHX_SERVER
          value: "true"
        - name: MIX_ENV
          value: "prod"
        - name: PORT
          value: "4000"
        - name: POOL_SIZE
          value: "10"
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /
            port: 4000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 4000
          initialDelaySeconds: 5
          periodSeconds: 5
      # Cloud SQL Proxy sidecar
      - name: cloud-sql-proxy
        image: gcr.io/cloudsql-docker/gce-proxy:1.33.2
        command:
        - "/cloud_sql_proxy"
        - "-instances=YOUR_PROJECT_ID:us-central1:dimension-forge-db=tcp:5432"
        securityContext:
          runAsNonRoot: true
---
# k8s/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: dimension-forge-service
  namespace: dimension-forge
spec:
  selector:
    app: dimension-forge
  ports:
  - port: 80
    targetPort: 4000
  type: ClusterIP
---
# k8s/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: dimension-forge-ingress
  namespace: dimension-forge
  annotations:
    kubernetes.io/ingress.global-static-ip-name: "dimension-forge-ip"
    networking.gke.io/managed-certificates: "dimension-forge-ssl"
    kubernetes.io/ingress.class: "gce"
spec:
  rules:
  - host: your-domain.com
    http:
      paths:
      - path: /*
        pathType: ImplementationSpecific
        backend:
          service:
            name: dimension-forge-service
            port:
              number: 80
```

Deploy to cluster:

```bash
# Apply all manifests
kubectl apply -f k8s/

# Check deployment status
kubectl get pods -n dimension-forge
kubectl get services -n dimension-forge
kubectl get ingress -n dimension-forge

# Run migrations
kubectl exec -n dimension-forge deployment/dimension-forge \
  -- /app/bin/dimension_forge eval "DimensionForge.Release.migrate"
```

## Compute Engine

For maximum control and customization.

### 1. Create VM Instance

```bash
# Create VM with Container-Optimized OS
gcloud compute instances create dimension-forge-vm \
  --zone=us-central1-a \
  --machine-type=e2-medium \
  --image-family=cos-stable \
  --image-project=cos-cloud \
  --boot-disk-size=50GB \
  --scopes=https://www.googleapis.com/auth/cloud-platform \
  --service-account=dimension-forge@YOUR_PROJECT_ID.iam.gserviceaccount.com \
  --metadata-from-file startup-script=startup-script.sh
```

### 2. Startup Script

Create `startup-script.sh`:

```bash
#!/bin/bash
# startup-script.sh

# Install Docker
sudo apt-get update
sudo apt-get install -y docker.io
sudo systemctl start docker
sudo systemctl enable docker

# Pull and run container
sudo docker run -d \
  --name dimension-forge \
  --restart unless-stopped \
  -p 80:4000 \
  -e PHX_SERVER=true \
  -e MIX_ENV=prod \
  -e DATABASE_URL="your_database_url" \
  -e SECRET_KEY_BASE="your_secret_key" \
  -e GCS_BUCKET="your-bucket-name" \
  -e GCP_PROJECT_ID="your-project-id" \
  -e POOL_SIZE="10" \
  gcr.io/YOUR_PROJECT_ID/dimension-forge:latest

# Set up log rotation
sudo docker run -d \
  --name logrotate \
  --restart unless-stopped \
  -v /var/lib/docker/containers:/var/lib/docker/containers:ro \
  -v /var/log:/var/log \
  logrotate/logrotate
```

## Monitoring and Alerting

### 1. Cloud Monitoring

```bash
# Enable monitoring
gcloud services enable monitoring.googleapis.com

# Create notification channel
gcloud alpha monitoring channels create \
  --display-name="Email Alerts" \
  --type=email \
  --channel-labels=email_address=admin@yourdomain.com
```

### 2. Log-based Metrics

```bash
# Create log-based metric for errors
gcloud logging metrics create error_rate \
  --description="Rate of application errors" \
  --log-filter='resource.type="cloud_run_revision" AND severity>=ERROR'
```

### 3. Uptime Checks

```bash
# Create uptime check
gcloud monitoring uptime create \
  --display-name="DimensionForge Health Check" \
  --http-check-path="/" \
  --hostname="your-service-url.run.app"
```

## Cost Optimization

### Cloud Run Optimization

```bash
# Deploy with optimized settings
gcloud run deploy dimension-forge \
  --cpu=1 \
  --memory=512Mi \
  --concurrency=100 \
  --min-instances=0 \
  --max-instances=10 \
  --cpu-throttling \
  --execution-environment=gen2
```

### Database Optimization

```bash
# Use smaller instance for development
gcloud sql instances patch dimension-forge-db \
  --tier=db-f1-micro

# Enable automatic storage increase
gcloud sql instances patch dimension-forge-db \
  --storage-auto-increase
```

## Security Best Practices

1. **Use IAM roles with least privilege**
2. **Enable VPC-native networking for GKE**
3. **Use Google-managed SSL certificates**
4. **Enable Cloud Armor for DDoS protection**
5. **Use Secret Manager for sensitive data**

## Troubleshooting

### Common Issues

1. **Cold starts on Cloud Run**
   - Use min-instances to keep warm instances
   - Optimize container startup time

2. **Database connection limits**
   - Adjust POOL_SIZE based on instance limits
   - Use connection pooling

3. **Image processing timeouts**
   - Increase Cloud Run timeout to 900s
   - Monitor memory usage

### Debug Commands

```bash
# Check Cloud Run logs
gcloud logs tail --follow --service=dimension-forge

# Check GKE pod logs
kubectl logs -f deployment/dimension-forge -n dimension-forge

# Connect to Cloud SQL
gcloud sql connect dimension-forge-db --user=dimension_forge
```

## Next Steps

1. **[Set up custom domain](https://cloud.google.com/run/docs/mapping-custom-domains)**
2. **[Configure SSL certificates](https://cloud.google.com/run/docs/securing/using-https)**
3. **[Set up CI/CD with Cloud Build](https://cloud.google.com/run/docs/continuous-deployment-with-cloud-build)**
4. **[Monitor with Cloud Monitoring](https://cloud.google.com/run/docs/monitoring)**