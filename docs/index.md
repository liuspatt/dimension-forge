# DimensionForge 🖼️

**High-performance image processing and optimization API for cloud applications**

DimensionForge is a powerful, scalable image processing service built with Phoenix and Elixir. It provides on-demand image resizing, format conversion, and optimization with intelligent caching and cloud storage integration.

## ✨ Features

- **🚀 On-demand Image Processing**: Resize, crop, and convert images in real-time
- **☁️ Multi-Cloud Support**: Google Cloud Storage, AWS S3, Azure Blob Storage
- **🔐 API Key Authentication**: Secure project-based access control
- **🎯 Smart Caching**: Intelligent variant caching to minimize processing overhead
- **⚡ High Performance**: Built with Elixir/Phoenix for maximum concurrency
- **📊 Multiple Formats**: Support for JPEG, PNG, WebP, GIF, BMP, TIFF, SVG
- **🔧 Flexible Resizing**: Crop, fit, fill, and stretch modes
- **📈 Production Ready**: Docker support, health checks, metrics

## 🚀 Quick Start

### 1. Upload an Image

```bash
curl -X POST "https://your-domain.com/api/upload" \
  -H "Content-Type: multipart/form-data" \
  -F "image=@your-image.jpg" \
  -F "key=your-api-key" \
  -F "project_name=my-project"
```

### 2. Get Resized Images

```html
<!-- Original image -->
<img src="https://your-domain.com/image/my-project/image-id/800/600/image.webp" />

<!-- Different sizes -->
<img src="https://your-domain.com/image/my-project/image-id/400/300/image.webp" />
<img src="https://your-domain.com/image/my-project/image-id/200/150/image.jpg" />
```

## 📚 Documentation

### Installation & Deployment
- [🏗️ Installation Guide](installation.md) - Complete setup instructions
- [☁️ Google Cloud Platform](gcp-deployment.md) - Deploy on GCP Cloud Run & GKE
- [🟠 AWS Deployment](aws-deployment.md) - Deploy on ECS, Fargate & Elastic Beanstalk  
- [🔵 Azure Deployment](azure-deployment.md) - Deploy on Container Instances & Container Apps
- [🟣 Heroku Deployment](heroku-deployment.md) - One-click Heroku deployment
- [🐳 Docker Deployment](docker-deployment.md) - Self-hosted Docker setup

### API Reference
- [📋 API Documentation](api-reference.md) - Complete API reference
- [🔑 Authentication](authentication.md) - API key management
- [🖼️ Image Processing](image-processing.md) - Resize modes and formats
- [📁 Project Management](project-management.md) - Organize images by project

### Advanced Topics
- [⚙️ Configuration](configuration.md) - Environment variables and settings
- [📊 Monitoring](monitoring.md) - Health checks and metrics
- [🛡️ Security](security.md) - Security best practices
- [🔧 Troubleshooting](troubleshooting.md) - Common issues and solutions

## 🌐 Live Demo

Try DimensionForge with our interactive demo:

**Base URL**: `https://dimension-forge-demo.com`

**Sample API Key**: `demo-key-12345` (read-only)

### Example Requests

```javascript
// Upload an image
const formData = new FormData();
formData.append('image', file);
formData.append('key', 'your-api-key');
formData.append('project_name', 'my-app');

const response = await fetch('https://your-domain.com/api/upload', {
  method: 'POST',
  body: formData
});

const result = await response.json();
// Returns: { success: true, data: { image_id: "...", project_name: "...", ... } }
```

```javascript
// Get resized image URL
const imageUrl = `https://your-domain.com/image/my-app/${imageId}/800/600/photo.webp`;
```

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Client App    │───▶│  DimensionForge │───▶│  Cloud Storage  │
│                 │    │      API        │    │   (GCS/S3)      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                              │
                              ▼
                       ┌─────────────────┐
                       │   PostgreSQL    │
                       │    Database     │
                       └─────────────────┘
```

## 🛠️ Technology Stack

- **Backend**: Elixir + Phoenix Framework
- **Database**: PostgreSQL with Ecto ORM
- **Image Processing**: ImageMagick via Mogrify
- **Cloud Storage**: Google Cloud Storage, AWS S3, Azure Blob
- **Authentication**: JWT-based API keys
- **Deployment**: Docker, Kubernetes, Cloud Run, ECS

## 📦 Installation

Choose your deployment method:

<div class="installation-grid">
  <a href="gcp-deployment.html" class="install-card">
    <h3>🌐 Google Cloud</h3>
    <p>Deploy on Cloud Run or GKE with one command</p>
  </a>
  
  <a href="aws-deployment.html" class="install-card">
    <h3>🟠 AWS</h3>
    <p>ECS Fargate and Elastic Beanstalk ready</p>
  </a>
  
  <a href="azure-deployment.html" class="install-card">
    <h3>🔵 Azure</h3>
    <p>Container Instances and Container Apps</p>
  </a>
  
  <a href="docker-deployment.html" class="install-card">
    <h3>🐳 Docker</h3>
    <p>Self-hosted with Docker Compose</p>
  </a>
</div>

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](contributing.md) for details.

## 📄 License

DimensionForge is released under the MIT License. See [LICENSE](https://github.com/your-username/dimension-forge/blob/main/LICENSE) for details.

## 🔗 Links

- [GitHub Repository](https://github.com/your-username/dimension-forge)
- [Issues](https://github.com/your-username/dimension-forge/issues)
- [Discussions](https://github.com/your-username/dimension-forge/discussions)

---

<div align="center">
  <p>Built with ❤️ using Elixir and Phoenix</p>
  <p>
    <a href="https://github.com/your-username/dimension-forge">⭐ Star on GitHub</a> |
    <a href="https://github.com/your-username/dimension-forge/issues">🐛 Report Bug</a> |
    <a href="https://github.com/your-username/dimension-forge/discussions">💬 Discussions</a>
  </p>
</div>