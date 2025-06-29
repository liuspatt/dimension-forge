# AWS Deployment Guide

Deploy DimensionForge on Amazon Web Services using ECS Fargate, Elastic Beanstalk, or EKS.

## Prerequisites

- AWS account with appropriate permissions
- AWS CLI installed and configured
- Docker installed
- Required AWS services enabled:
  - ECS
  - RDS
  - S3
  - IAM
  - CloudFormation

## ECS Fargate Deployment (Recommended)

Serverless containers with automatic scaling and no server management.

### 1. Quick Deploy with CDK

```bash
# Install AWS CDK
npm install -g aws-cdk

# Clone and deploy
git clone https://github.com/your-username/dimension-forge.git
cd dimension-forge/aws-cdk
npm install
cdk deploy
```

### 2. Step-by-Step Deployment

#### Create RDS Database

```bash
# Create DB subnet group
aws rds create-db-subnet-group \
  --db-subnet-group-name dimension-forge-subnet-group \
  --db-subnet-group-description "Subnet group for DimensionForge" \
  --subnet-ids subnet-12345678 subnet-87654321

# Create RDS PostgreSQL instance
aws rds create-db-instance \
  --db-instance-identifier dimension-forge-db \
  --db-instance-class db.t3.micro \
  --engine postgres \
  --engine-version 15.3 \
  --allocated-storage 20 \
  --storage-type gp2 \
  --storage-encrypted \
  --db-name dimension_forge_prod \
  --master-username admin \
  --master-user-password YourSecurePassword123! \
  --db-subnet-group-name dimension-forge-subnet-group \
  --vpc-security-group-ids sg-your-security-group \
  --backup-retention-period 7 \
  --multi-az \
  --deletion-protection

# Wait for database to be available
aws rds wait db-instance-available --db-instance-identifier dimension-forge-db
```

#### Create S3 Bucket

```bash
# Create S3 bucket
aws s3 mb s3://dimension-forge-images-bucket --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket dimension-forge-images-bucket \
  --versioning-configuration Status=Enabled

# Set CORS policy
cat > cors-policy.json << EOF
{
  "CORSRules": [
    {
      "AllowedOrigins": ["*"],
      "AllowedMethods": ["GET", "HEAD"],
      "AllowedHeaders": ["*"],
      "MaxAgeSeconds": 3600
    }
  ]
}
EOF

aws s3api put-bucket-cors \
  --bucket dimension-forge-images-bucket \
  --cors-configuration file://cors-policy.json

# Set public read policy
cat > bucket-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::dimension-forge-images-bucket/*"
    }
  ]
}
EOF

aws s3api put-bucket-policy \
  --bucket dimension-forge-images-bucket \
  --policy file://bucket-policy.json
```

#### Create ECR Repository

```bash
# Create ECR repository
aws ecr create-repository \
  --repository-name dimension-forge \
  --region us-east-1

# Get login token
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  123456789012.dkr.ecr.us-east-1.amazonaws.com

# Build and push image
docker build -t dimension-forge .
docker tag dimension-forge:latest \
  123456789012.dkr.ecr.us-east-1.amazonaws.com/dimension-forge:latest
docker push 123456789012.dkr.ecr.us-east-1.amazonaws.com/dimension-forge:latest
```

#### Create ECS Cluster

```bash
# Create ECS cluster
aws ecs create-cluster \
  --cluster-name dimension-forge-cluster \
  --capacity-providers FARGATE \
  --default-capacity-provider-strategy capacityProvider=FARGATE,weight=1
```

#### Create Task Definition

```json
{
  "family": "dimension-forge",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "512",
  "memory": "1024",
  "executionRoleArn": "arn:aws:iam::123456789012:role/ecsTaskExecutionRole",
  "taskRoleArn": "arn:aws:iam::123456789012:role/dimensionForgeTaskRole",
  "containerDefinitions": [
    {
      "name": "dimension-forge",
      "image": "123456789012.dkr.ecr.us-east-1.amazonaws.com/dimension-forge:latest",
      "portMappings": [
        {
          "containerPort": 4000,
          "protocol": "tcp"
        }
      ],
      "essential": true,
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/dimension-forge",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "ecs"
        }
      },
      "environment": [
        {
          "name": "PHX_SERVER",
          "value": "true"
        },
        {
          "name": "MIX_ENV",
          "value": "prod"
        },
        {
          "name": "PORT",
          "value": "4000"
        },
        {
          "name": "POOL_SIZE",
          "value": "10"
        }
      ],
      "secrets": [
        {
          "name": "DATABASE_URL",
          "valueFrom": "arn:aws:secretsmanager:us-east-1:123456789012:secret:dimension-forge/database-url"
        },
        {
          "name": "SECRET_KEY_BASE",
          "valueFrom": "arn:aws:secretsmanager:us-east-1:123456789012:secret:dimension-forge/secret-key-base"
        },
        {
          "name": "AWS_ACCESS_KEY_ID",
          "valueFrom": "arn:aws:secretsmanager:us-east-1:123456789012:secret:dimension-forge/aws-access-key-id"
        },
        {
          "name": "AWS_SECRET_ACCESS_KEY",
          "valueFrom": "arn:aws:secretsmanager:us-east-1:123456789012:secret:dimension-forge/aws-secret-access-key"
        }
      ]
    }
  ]
}
```

Register the task definition:

```bash
aws ecs register-task-definition --cli-input-json file://task-definition.json
```

#### Create Application Load Balancer

```bash
# Create ALB
aws elbv2 create-load-balancer \
  --name dimension-forge-alb \
  --subnets subnet-12345678 subnet-87654321 \
  --security-groups sg-your-alb-security-group \
  --scheme internet-facing \
  --type application \
  --ip-address-type ipv4

# Create target group
aws elbv2 create-target-group \
  --name dimension-forge-targets \
  --protocol HTTP \
  --port 4000 \
  --vpc-id vpc-your-vpc-id \
  --target-type ip \
  --health-check-path / \
  --health-check-interval-seconds 30 \
  --health-check-timeout-seconds 5 \
  --healthy-threshold-count 2 \
  --unhealthy-threshold-count 3

# Create listener
aws elbv2 create-listener \
  --load-balancer-arn arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/dimension-forge-alb/50dc6c495c0c9188 \
  --protocol HTTP \
  --port 80 \
  --default-actions Type=forward,TargetGroupArn=arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/dimension-forge-targets/50dc6c495c0c9188
```

#### Create ECS Service

```bash
# Create ECS service
aws ecs create-service \
  --cluster dimension-forge-cluster \
  --service-name dimension-forge-service \
  --task-definition dimension-forge:1 \
  --desired-count 2 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-12345678,subnet-87654321],securityGroups=[sg-your-ecs-security-group],assignPublicIp=ENABLED}" \
  --load-balancers targetGroupArn=arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/dimension-forge-targets/50dc6c495c0c9188,containerName=dimension-forge,containerPort=4000
```

#### Run Database Migration

```bash
# Create one-time task for migration
aws ecs run-task \
  --cluster dimension-forge-cluster \
  --task-definition dimension-forge:1 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-12345678],securityGroups=[sg-your-ecs-security-group],assignPublicIp=ENABLED}" \
  --overrides '{
    "containerOverrides": [
      {
        "name": "dimension-forge",
        "command": ["/app/bin/dimension_forge", "eval", "DimensionForge.Release.migrate"]
      }
    ]
  }'
```

## Elastic Beanstalk Deployment

Platform-as-a-Service with automatic scaling and load balancing.

### 1. Initialize Elastic Beanstalk

```bash
# Install EB CLI
pip install awsebcli

# Initialize EB application
eb init dimension-forge \
  --platform docker \
  --region us-east-1

# Create environment
eb create production \
  --instance-type t3.small \
  --min-instances 1 \
  --max-instances 5 \
  --database \
  --database.engine postgres \
  --database.username admin
```

### 2. Configuration Files

Create `.ebextensions/` directory with configuration:

```yaml
# .ebextensions/01-environment.config
option_settings:
  aws:elasticbeanstalk:application:environment:
    PHX_SERVER: "true"
    MIX_ENV: "prod"
    PORT: "80"
    POOL_SIZE: "10"
    AWS_REGION: "us-east-1"
  aws:elasticbeanstalk:environment:proxy:staticfiles:
    /static: static
  aws:autoscaling:launchconfiguration:
    IamInstanceProfile: aws-elasticbeanstalk-ec2-role
    InstanceType: t3.small
  aws:autoscaling:asg:
    MinSize: 1
    MaxSize: 5
  aws:elasticbeanstalk:healthreporting:system:
    SystemType: enhanced
```

```yaml
# .ebextensions/02-secrets.config
option_settings:
  aws:elasticbeanstalk:application:environment:
    DATABASE_URL: '`{"Ref": "AWSEBRDSDbURL"}`'
    SECRET_KEY_BASE: '`{"Ref": "SecretKeyBase"}`'
    S3_BUCKET: '`{"Ref": "S3Bucket"}`'

Resources:
  SecretKeyBase:
    Type: AWS::SSM::Parameter::Value<String>
    Default: /dimension-forge/secret-key-base
  
  S3Bucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: !Sub "${AWS::StackName}-images"
      PublicReadPolicy: true
```

### 3. Deploy Application

```bash
# Deploy to Elastic Beanstalk
eb deploy

# Open application
eb open

# Check logs
eb logs

# SSH into instance (if needed)
eb ssh
```

## EKS Deployment

Managed Kubernetes service for container orchestration.

### 1. Create EKS Cluster

```bash
# Install eksctl
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin

# Create EKS cluster
eksctl create cluster \
  --name dimension-forge-cluster \
  --region us-east-1 \
  --nodegroup-name dimension-forge-nodes \
  --node-type t3.medium \
  --nodes 3 \
  --nodes-min 1 \
  --nodes-max 5 \
  --managed \
  --version 1.27

# Update kubeconfig
aws eks update-kubeconfig \
  --region us-east-1 \
  --name dimension-forge-cluster
```

### 2. Set up AWS Load Balancer Controller

```bash
# Install AWS Load Balancer Controller
kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.5.4/cert-manager.yaml

curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.4.1/docs/install/iam_policy.json

aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam_policy.json

eksctl create iamserviceaccount \
  --cluster=dimension-forge-cluster \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --role-name "AmazonEKSLoadBalancerControllerRole" \
  --attach-policy-arn=arn:aws:iam::123456789012:policy/AWSLoadBalancerControllerIAMPolicy \
  --approve

kubectl apply -f https://github.com/kubernetes-sigs/aws-load-balancer-controller/releases/download/v2.4.1/v2_4_1_full.yaml
```

### 3. Deploy Application

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
  DATABASE_URL: "postgres://admin:password@dimension-forge-db.cluster-xyz.us-east-1.rds.amazonaws.com:5432/dimension_forge_prod"
  SECRET_KEY_BASE: "your_secret_key_base_64_chars"
  AWS_ACCESS_KEY_ID: "your_access_key"
  AWS_SECRET_ACCESS_KEY: "your_secret_key"
  S3_BUCKET: "dimension-forge-images-bucket"
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
        image: 123456789012.dkr.ecr.us-east-1.amazonaws.com/dimension-forge:latest
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
        - name: AWS_REGION
          value: "us-east-1"
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
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:us-east-1:123456789012:certificate/your-cert-arn
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS":443}]'
    alb.ingress.kubernetes.io/actions.ssl-redirect: '{"Type": "redirect", "RedirectConfig": { "Protocol": "HTTPS", "Port": "443", "StatusCode": "HTTP_301"}}'
spec:
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

Deploy to EKS:

```bash
# Apply manifests
kubectl apply -f k8s/

# Check deployment
kubectl get pods -n dimension-forge
kubectl get services -n dimension-forge
kubectl get ingress -n dimension-forge

# Run migrations
kubectl exec -n dimension-forge deployment/dimension-forge \
  -- /app/bin/dimension_forge eval "DimensionForge.Release.migrate"
```

## Monitoring and Logging

### CloudWatch Integration

```bash
# Install CloudWatch agent
kubectl apply -f https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/cloudwatch-namespace.yaml

kubectl apply -f https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/cwagent/cwagent-serviceaccount.yaml

kubectl apply -f https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/cwagent/cwagent-configmap.yaml

kubectl apply -f https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/cwagent/cwagent-daemonset.yaml
```

### Application Insights

```bash
# Create CloudWatch dashboard
aws cloudwatch put-dashboard \
  --dashboard-name "DimensionForge" \
  --dashboard-body file://cloudwatch-dashboard.json
```

## Security Best Practices

1. **Use IAM roles instead of access keys**
2. **Enable VPC endpoints for S3 and other services**
3. **Use AWS Secrets Manager for sensitive data**
4. **Enable WAF for web application protection**
5. **Use SSL/TLS certificates from ACM**

## Cost Optimization

### Fargate Optimization

```bash
# Use Fargate Spot for non-critical workloads
aws ecs put-cluster-capacity-providers \
  --cluster dimension-forge-cluster \
  --capacity-providers FARGATE FARGATE_SPOT \
  --default-capacity-provider-strategy \
    capacityProvider=FARGATE_SPOT,weight=2 \
    capacityProvider=FARGATE,weight=1
```

### Auto Scaling

```bash
# Create auto scaling target
aws application-autoscaling register-scalable-target \
  --service-namespace ecs \
  --scalable-dimension ecs:service:DesiredCount \
  --resource-id service/dimension-forge-cluster/dimension-forge-service \
  --min-capacity 1 \
  --max-capacity 10

# Create scaling policy
aws application-autoscaling put-scaling-policy \
  --policy-name cpu-tracking \
  --service-namespace ecs \
  --scalable-dimension ecs:service:DesiredCount \
  --resource-id service/dimension-forge-cluster/dimension-forge-service \
  --policy-type TargetTrackingScaling \
  --target-tracking-scaling-policy-configuration \
    TargetValue=50.0,PredefinedMetricSpecification='{PredefinedMetricType=ECSServiceAverageCPUUtilization}'
```

## Troubleshooting

### Common Issues

1. **Task fails to start**
   - Check task definition resource limits
   - Verify IAM permissions
   - Check CloudWatch logs

2. **Database connection errors**
   - Verify security group rules
   - Check database credentials
   - Ensure VPC connectivity

3. **Image upload failures**
   - Check S3 bucket permissions
   - Verify IAM role policies
   - Monitor CloudWatch logs

### Debug Commands

```bash
# Check ECS service status
aws ecs describe-services \
  --cluster dimension-forge-cluster \
  --services dimension-forge-service

# View task logs
aws logs tail /ecs/dimension-forge --follow

# Debug networking
aws ec2 describe-security-groups \
  --filters Name=group-name,Values=dimension-forge-*
```

## Next Steps

1. **[Set up CI/CD with CodePipeline](https://docs.aws.amazon.com/codepipeline/)**
2. **[Configure SSL certificates](https://docs.aws.amazon.com/acm/)**
3. **[Set up monitoring](https://docs.aws.amazon.com/cloudwatch/)**
4. **[Implement backup strategy](https://docs.aws.amazon.com/rds/latest/userguide/CHAP_CommonTasks.BackupRestore.html)**