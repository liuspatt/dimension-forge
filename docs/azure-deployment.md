# Azure Deployment Guide

Deploy DimensionForge on Microsoft Azure using Container Instances, Container Apps, or Azure Kubernetes Service (AKS).

## Prerequisites

- Azure account with active subscription
- Azure CLI installed and configured
- Docker installed
- Required Azure services enabled:
  - Container Instances
  - Container Registry
  - Database for PostgreSQL
  - Storage Account

## Container Instances Deployment (Recommended)

Serverless containers with per-second billing and automatic scaling.

### 1. Quick Deploy

```bash
# Create resource group
az group create --name dimension-forge-rg --location eastus

# Deploy using container instance
az container create \
  --resource-group dimension-forge-rg \
  --name dimension-forge \
  --image your-registry.azurecr.io/dimension-forge:latest \
  --cpu 1 \
  --memory 2 \
  --ports 4000 \
  --dns-name-label dimension-forge-unique \
  --environment-variables \
    PHX_SERVER=true \
    MIX_ENV=prod \
    PORT=4000 \
    POOL_SIZE=5 \
  --secure-environment-variables \
    DATABASE_URL="your_database_url" \
    SECRET_KEY_BASE="your_secret_key" \
    AZURE_STORAGE_ACCOUNT="your_storage_account" \
    AZURE_STORAGE_KEY="your_storage_key"
```

### 2. Step-by-Step Deployment

#### Create Azure Container Registry

```bash
# Create container registry
az acr create \
  --resource-group dimension-forge-rg \
  --name dimensionforgeregistry \
  --sku Basic \
  --admin-enabled true

# Get login server
az acr show \
  --name dimensionforgeregistry \
  --query loginServer \
  --output tsv

# Login to registry
az acr login --name dimensionforgeregistry

# Build and push image
docker build -t dimension-forge .
docker tag dimension-forge:latest \
  dimensionforgeregistry.azurecr.io/dimension-forge:latest
docker push dimensionforgeregistry.azurecr.io/dimension-forge:latest
```

#### Create PostgreSQL Database

```bash
# Create PostgreSQL server
az postgres server create \
  --resource-group dimension-forge-rg \
  --name dimension-forge-db \
  --location eastus \
  --admin-user dbadmin \
  --admin-password SecurePassword123! \
  --sku-name B_Gen5_1 \
  --version 13 \
  --storage-size 51200 \
  --backup-retention 7 \
  --geo-redundant-backup Disabled

# Create database
az postgres db create \
  --resource-group dimension-forge-rg \
  --server-name dimension-forge-db \
  --name dimension_forge_prod

# Configure firewall to allow Azure services
az postgres server firewall-rule create \
  --resource-group dimension-forge-rg \
  --server dimension-forge-db \
  --name AllowAzureServices \
  --start-ip-address 0.0.0.0 \
  --end-ip-address 0.0.0.0
```

#### Create Storage Account

```bash
# Create storage account
az storage account create \
  --name dimensionforgestorage \
  --resource-group dimension-forge-rg \
  --location eastus \
  --sku Standard_LRS \
  --kind StorageV2 \
  --access-tier Hot

# Create blob container
az storage container create \
  --name images \
  --account-name dimensionforgestorage \
  --public-access blob

# Get storage account key
az storage account keys list \
  --resource-group dimension-forge-rg \
  --account-name dimensionforgestorage \
  --query "[0].value" \
  --output tsv
```

#### Deploy Container Instance

```bash
# Get registry credentials
ACR_LOGIN_SERVER=$(az acr show --name dimensionforgeregistry --query loginServer --output tsv)
ACR_USERNAME=$(az acr credential show --name dimensionforgeregistry --query username --output tsv)
ACR_PASSWORD=$(az acr credential show --name dimensionforgeregistry --query passwords[0].value --output tsv)

# Deploy container instance
az container create \
  --resource-group dimension-forge-rg \
  --name dimension-forge \
  --image dimensionforgeregistry.azurecr.io/dimension-forge:latest \
  --cpu 1 \
  --memory 2 \
  --ports 4000 \
  --dns-name-label dimension-forge-$(uuidgen | cut -c1-8) \
  --registry-login-server $ACR_LOGIN_SERVER \
  --registry-username $ACR_USERNAME \
  --registry-password $ACR_PASSWORD \
  --environment-variables \
    PHX_SERVER=true \
    MIX_ENV=prod \
    PORT=4000 \
    POOL_SIZE=5 \
  --secure-environment-variables \
    DATABASE_URL="ecto://dbadmin:SecurePassword123!@dimension-forge-db.postgres.database.azure.com:5432/dimension_forge_prod?ssl=true" \
    SECRET_KEY_BASE="$(openssl rand -base64 48)" \
    AZURE_STORAGE_ACCOUNT="dimensionforgestorage" \
    AZURE_STORAGE_KEY="your_storage_key" \
    AZURE_CONTAINER="images"

# Get container IP
az container show \
  --resource-group dimension-forge-rg \
  --name dimension-forge \
  --query ipAddress.fqdn \
  --output tsv
```

## Container Apps Deployment

Modern serverless container platform with advanced scaling and traffic management.

### 1. Create Container Apps Environment

```bash
# Install Container Apps extension
az extension add --name containerapp

# Register providers
az provider register --namespace Microsoft.App
az provider register --namespace Microsoft.OperationalInsights

# Create Log Analytics workspace
az monitor log-analytics workspace create \
  --resource-group dimension-forge-rg \
  --workspace-name dimension-forge-logs \
  --location eastus

# Get workspace ID and key
LOG_ANALYTICS_WORKSPACE_ID=$(az monitor log-analytics workspace show \
  --resource-group dimension-forge-rg \
  --workspace-name dimension-forge-logs \
  --query customerId \
  --output tsv)

LOG_ANALYTICS_KEY=$(az monitor log-analytics workspace get-shared-keys \
  --resource-group dimension-forge-rg \
  --workspace-name dimension-forge-logs \
  --query primarySharedKey \
  --output tsv)

# Create Container Apps environment
az containerapp env create \
  --name dimension-forge-env \
  --resource-group dimension-forge-rg \
  --location eastus \
  --logs-workspace-id $LOG_ANALYTICS_WORKSPACE_ID \
  --logs-workspace-key $LOG_ANALYTICS_KEY
```

### 2. Deploy Container App

```yaml
# containerapp.yaml
properties:
  configuration:
    ingress:
      external: true
      targetPort: 4000
      allowInsecure: false
    secrets:
      - name: database-url
        value: "ecto://dbadmin:SecurePassword123!@dimension-forge-db.postgres.database.azure.com:5432/dimension_forge_prod?ssl=true"
      - name: secret-key-base
        value: "your_secret_key_base_64_chars"
      - name: azure-storage-key
        value: "your_storage_key"
    registries:
      - server: dimensionforgeregistry.azurecr.io
        username: dimensionforgeregistry
        passwordSecretRef: registry-password
  template:
    containers:
      - image: dimensionforgeregistry.azurecr.io/dimension-forge:latest
        name: dimension-forge
        env:
          - name: PHX_SERVER
            value: "true"
          - name: MIX_ENV
            value: "prod"
          - name: PORT
            value: "4000"
          - name: POOL_SIZE
            value: "10"
          - name: DATABASE_URL
            secretRef: database-url
          - name: SECRET_KEY_BASE
            secretRef: secret-key-base
          - name: AZURE_STORAGE_ACCOUNT
            value: "dimensionforgestorage"
          - name: AZURE_STORAGE_KEY
            secretRef: azure-storage-key
          - name: AZURE_CONTAINER
            value: "images"
        resources:
          cpu: 1.0
          memory: 2.0Gi
    scale:
      minReplicas: 1
      maxReplicas: 10
      rules:
        - name: http-rule
          http:
            metadata:
              concurrentRequests: "30"
```

Deploy the container app:

```bash
az containerapp create \
  --name dimension-forge \
  --resource-group dimension-forge-rg \
  --environment dimension-forge-env \
  --yaml containerapp.yaml
```

## Azure Kubernetes Service (AKS)

Managed Kubernetes service for complex deployments and advanced orchestration.

### 1. Create AKS Cluster

```bash
# Create AKS cluster
az aks create \
  --resource-group dimension-forge-rg \
  --name dimension-forge-cluster \
  --node-count 3 \
  --node-vm-size Standard_B2s \
  --enable-addons monitoring \
  --generate-ssh-keys \
  --attach-acr dimensionforgeregistry

# Get cluster credentials
az aks get-credentials \
  --resource-group dimension-forge-rg \
  --name dimension-forge-cluster
```

### 2. Deploy to AKS

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
  DATABASE_URL: "ecto://dbadmin:SecurePassword123!@dimension-forge-db.postgres.database.azure.com:5432/dimension_forge_prod?ssl=true"
  SECRET_KEY_BASE: "your_secret_key_base_64_chars"
  AZURE_STORAGE_ACCOUNT: "dimensionforgestorage"
  AZURE_STORAGE_KEY: "your_storage_key"
  AZURE_CONTAINER: "images"
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
      containers:
      - name: dimension-forge
        image: dimensionforgeregistry.azurecr.io/dimension-forge:latest
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
    kubernetes.io/ingress.class: azure/application-gateway
    appgw.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  tls:
  - hosts:
    - your-domain.com
    secretName: dimension-forge-tls
  rules:
  - host: your-domain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: dimension-forge-service
            port:
              number: 80
```

Deploy to AKS:

```bash
# Apply manifests
kubectl apply -f k8s/

# Check deployment status
kubectl get pods -n dimension-forge
kubectl get services -n dimension-forge
kubectl get ingress -n dimension-forge

# Run migrations
kubectl exec -n dimension-forge deployment/dimension-forge \
  -- /app/bin/dimension_forge eval "DimensionForge.Release.migrate"
```

## Azure Functions (Serverless)

For event-driven image processing workloads.

### 1. Create Function App

```bash
# Create storage account for functions
az storage account create \
  --name dimensionforgefunctions \
  --resource-group dimension-forge-rg \
  --location eastus \
  --sku Standard_LRS

# Create function app
az functionapp create \
  --resource-group dimension-forge-rg \
  --consumption-plan-location eastus \
  --runtime custom \
  --name dimension-forge-functions \
  --storage-account dimensionforgefunctions \
  --docker-image dimensionforgeregistry.azurecr.io/dimension-forge:latest
```

### 2. Configure Function App

```bash
# Set application settings
az functionapp config appsettings set \
  --name dimension-forge-functions \
  --resource-group dimension-forge-rg \
  --settings \
    PHX_SERVER=true \
    MIX_ENV=prod \
    DATABASE_URL="your_database_url" \
    SECRET_KEY_BASE="your_secret_key" \
    AZURE_STORAGE_ACCOUNT="dimensionforgestorage" \
    AZURE_STORAGE_KEY="your_storage_key"
```

## Monitoring and Logging

### 1. Application Insights

```bash
# Create Application Insights
az monitor app-insights component create \
  --app dimension-forge-insights \
  --location eastus \
  --resource-group dimension-forge-rg \
  --kind web

# Get instrumentation key
az monitor app-insights component show \
  --app dimension-forge-insights \
  --resource-group dimension-forge-rg \
  --query instrumentationKey \
  --output tsv
```

### 2. Log Analytics

```bash
# Create custom log queries
az monitor log-analytics query \
  --workspace $LOG_ANALYTICS_WORKSPACE_ID \
  --analytics-query '
    ContainerInstanceLog_CL
    | where ContainerGroup_s == "dimension-forge"
    | where LogSource_s == "stderr"
    | project TimeGenerated, LogEntry_s
    | order by TimeGenerated desc
  '
```

## Security Configuration

### 1. Managed Identity

```bash
# Enable managed identity for container instance
az container create \
  --resource-group dimension-forge-rg \
  --name dimension-forge \
  --assign-identity \
  --scope $(az group show --name dimension-forge-rg --query id --output tsv) \
  --role Contributor
```

### 2. Key Vault Integration

```bash
# Create Key Vault
az keyvault create \
  --name dimension-forge-vault \
  --resource-group dimension-forge-rg \
  --location eastus

# Store secrets
az keyvault secret set \
  --vault-name dimension-forge-vault \
  --name DATABASE-URL \
  --value "your_database_url"

az keyvault secret set \
  --vault-name dimension-forge-vault \
  --name SECRET-KEY-BASE \
  --value "your_secret_key"
```

## Cost Optimization

### 1. Spot Instances

```bash
# Use spot instances for AKS
az aks nodepool add \
  --resource-group dimension-forge-rg \
  --cluster-name dimension-forge-cluster \
  --name spotnodepool \
  --node-count 2 \
  --node-vm-size Standard_B2s \
  --priority Spot \
  --eviction-policy Delete \
  --spot-max-price -1 \
  --no-wait
```

### 2. Auto-scaling

```bash
# Enable cluster autoscaler
az aks update \
  --resource-group dimension-forge-rg \
  --name dimension-forge-cluster \
  --enable-cluster-autoscaler \
  --min-count 1 \
  --max-count 5
```

## Backup and Disaster Recovery

### 1. Database Backup

```bash
# Configure automated backups
az postgres server configuration set \
  --resource-group dimension-forge-rg \
  --server-name dimension-forge-db \
  --name backup_retention_days \
  --value 30

# Create point-in-time restore
az postgres server restore \
  --resource-group dimension-forge-rg \
  --name dimension-forge-db-restored \
  --restore-point-in-time "2023-12-01T10:00:00Z" \
  --source-server dimension-forge-db
```

### 2. Storage Backup

```bash
# Enable soft delete for blob storage
az storage account blob-service-properties update \
  --account-name dimensionforgestorage \
  --enable-delete-retention true \
  --delete-retention-days 30
```

## Troubleshooting

### Common Issues

1. **Container startup failures**
   - Check container logs: `az container logs --name dimension-forge --resource-group dimension-forge-rg`
   - Verify environment variables and secrets

2. **Database connection errors**
   - Check firewall rules
   - Verify connection string format
   - Ensure SSL is enabled

3. **Storage access issues**
   - Verify storage account keys
   - Check container permissions
   - Ensure storage account is accessible

### Debug Commands

```bash
# View container logs
az container logs \
  --resource-group dimension-forge-rg \
  --name dimension-forge \
  --follow

# Execute commands in container
az container exec \
  --resource-group dimension-forge-rg \
  --name dimension-forge \
  --exec-command "/bin/bash"

# Check container app logs
az containerapp logs show \
  --name dimension-forge \
  --resource-group dimension-forge-rg \
  --follow

# Debug AKS pods
kubectl logs -f deployment/dimension-forge -n dimension-forge
kubectl describe pod -n dimension-forge
```

## Next Steps

1. **[Configure custom domain and SSL](https://docs.microsoft.com/en-us/azure/container-instances/container-instances-application-gateway)**
2. **[Set up CI/CD with Azure DevOps](https://docs.microsoft.com/en-us/azure/devops/pipelines/)**
3. **[Monitor with Azure Monitor](https://docs.microsoft.com/en-us/azure/azure-monitor/)**
4. **[Implement backup strategy](https://docs.microsoft.com/en-us/azure/backup/)**