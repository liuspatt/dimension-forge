# DimensionForge 🖼️

**High-performance image processing and optimization API for cloud applications**

DimensionForge is a powerful, scalable image processing service built with Phoenix and Elixir. It provides on-demand image resizing, format conversion, and optimization with intelligent caching and cloud storage integration.

## ✨ Features

- **<iconify-icon icon="material-symbols:rocket-launch"></iconify-icon> On-demand Image Processing**: Resize, crop, and convert images in real-time
- **<iconify-icon icon="material-symbols:cloud"></iconify-icon> Multi-Cloud Support**: Google Cloud Storage, AWS S3, Azure Blob Storage
- **<iconify-icon icon="material-symbols:security"></iconify-icon> API Key Authentication**: Secure project-based access control
- **<iconify-icon icon="material-symbols:cached"></iconify-icon> Smart Caching**: Intelligent variant caching to minimize processing overhead
- **<iconify-icon icon="material-symbols:bolt"></iconify-icon> High Performance**: Built with Elixir/Phoenix for maximum concurrency
- **<iconify-icon icon="material-symbols:image"></iconify-icon> Multiple Formats**: Support for JPEG, PNG, WebP, GIF, BMP, TIFF, SVG
- **<iconify-icon icon="material-symbols:tune"></iconify-icon> Flexible Resizing**: Crop, fit, fill, and stretch modes
- **<iconify-icon icon="material-symbols:verified"></iconify-icon> Production Ready**: Docker support, health checks, metrics

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
- [<iconify-icon icon="material-symbols:construction"></iconify-icon> Installation Guide]({{ "/installation" | relative_url }}) - Complete setup instructions
- [<iconify-icon icon="logos:google-cloud"></iconify-icon> Google Cloud Platform]({{ "/gcp-deployment" | relative_url }}) - Deploy on GCP Cloud Run & GKE
- [<iconify-icon icon="logos:aws"></iconify-icon> AWS Deployment]({{ "/aws-deployment" | relative_url }}) - Deploy on ECS, Fargate & Elastic Beanstalk  
- [<iconify-icon icon="logos:microsoft-azure"></iconify-icon> Azure Deployment]({{ "/azure-deployment" | relative_url }}) - Deploy on Container Instances & Container Apps
- [<iconify-icon icon="logos:docker-icon"></iconify-icon> Docker Deployment]({{ "/docker-deployment" | relative_url }}) - Self-hosted Docker setup

### API Reference
- [<iconify-icon icon="material-symbols:api"></iconify-icon> API Documentation]({{ "/api-reference" | relative_url }}) - Complete API reference

### Advanced Topics
- [<iconify-icon icon="material-symbols:settings"></iconify-icon> Configuration]({{ "/installation#environment-variables" | relative_url }}) - Environment variables and settings
- [<iconify-icon icon="material-symbols:shield"></iconify-icon> Security]({{ "/installation#security-configuration" | relative_url }}) - Security best practices
- [<iconify-icon icon="material-symbols:build"></iconify-icon> Troubleshooting]({{ "/installation#troubleshooting" | relative_url }}) - Common issues and solutions

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
  <a href="{{ "/gcp-deployment" | relative_url }}" class="install-card">
    <h3><iconify-icon icon="logos:google-cloud"></iconify-icon> Google Cloud</h3>
    <p>Deploy on Cloud Run or GKE with one command</p>
  </a>
  
  <a href="{{ "/aws-deployment" | relative_url }}" class="install-card">
    <h3><iconify-icon icon="logos:aws"></iconify-icon> AWS</h3>
    <p>ECS Fargate and Elastic Beanstalk ready</p>
  </a>
  
  <a href="{{ "/azure-deployment" | relative_url }}" class="install-card">
    <h3><iconify-icon icon="logos:microsoft-azure"></iconify-icon> Azure</h3>
    <p>Container Instances and Container Apps</p>
  </a>
  
  <a href="{{ "/docker-deployment" | relative_url }}" class="install-card">
    <h3><iconify-icon icon="logos:docker-icon"></iconify-icon> Docker</h3>
    <p>Self-hosted with Docker Compose</p>
  </a>
</div>

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](contributing.md) for details.

## 📄 License

DimensionForge is released under the MIT License. See [LICENSE](https://github.com/liuspatt/dimension-forge/blob/main/LICENSE) for details.

## 🔗 Links

- [GitHub Repository](https://github.com/liuspatt/dimension-forge)
- [Issues](https://github.com/liuspatt/dimension-forge/issues)
- [Discussions](https://github.com/liuspatt/dimension-forge/discussions)

---

<div align="center">
  <p>Built with ❤️ using Elixir and Phoenix</p>
  <p>
    <a href="https://github.com/liuspatt/dimension-forge">⭐ Star on GitHub</a> |
    <a href="https://github.com/liuspatt/dimension-forge/issues">🐛 Report Bug</a> |
    <a href="https://github.com/liuspatt/dimension-forge/discussions">💬 Discussions</a>
  </p>
</div>