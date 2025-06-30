---
layout: default
---

<div class="hero-banner-fullwidth">
  <div class="hero-content">
    <h1 class="hero-title">Dimension Forge</h1>    
    <p class="hero-subtitle">High-performance image processing and optimization API for cloud applications</p>
    <p class="hero-description">Provides on-demand image resizing, format conversion, and optimization with intelligent caching and cloud storage integration.</p>    
    <div class="hero-actions">
      <a href="{{ "/installation" | relative_url }}" class="btn btn-primary">
        🚀 Get Started
      </a>
      <a href="{{ "/api-reference" | relative_url }}" class="btn btn-secondary">
        📚 View API Docs
      </a>
    </div>
  </div>
</div>

<div class="content-container">
<section class="features-section">
  <div class="container">
    <h2>Why Choose Dimension Forge?</h2>
    <div class="features-grid">
      <div class="feature-card">
        <div class="feature-icon">⚡</div>
        <h3>On-demand Processing</h3>
        <p>Resize, crop, and convert images in real-time with instant delivery</p>
      </div>
      <div class="feature-card">
        <div class="feature-icon">☁️</div>
        <h3>Multi-Cloud Support</h3>
        <p>Works with Google Cloud Storage, AWS S3, and Azure Blob Storage</p>
      </div>
      <div class="feature-card">
        <div class="feature-icon">🔐</div>
        <h3>Secure by Design</h3>
        <p>API key authentication with project-based access control</p>
      </div>
      <div class="feature-card">
        <div class="feature-icon">🚀</div>
        <h3>High Performance</h3>
        <p>Built with Elixir/Phoenix for maximum concurrency and speed</p>
      </div>
      <div class="feature-card">
        <div class="feature-icon">🖼️</div>
        <h3>Multiple Formats</h3>
        <p>Support for JPEG, PNG, WebP, GIF, BMP, TIFF, and SVG</p>
      </div>
      <div class="feature-card">
        <div class="feature-icon">✅</div>
        <h3>Production Ready</h3>
        <p>Docker support, health checks, metrics, and monitoring</p>
      </div>
    </div>
  </div>
</section>

<section class="quick-start-section" id="quick-start">
  <div class="container">
    <h2>🚀 Quick Start</h2>
    <div class="quick-start-grid">
      <div class="step-card">
        <div class="step-number">1</div>
        <h3>Upload an Image</h3>
        <div class="code-block">
<pre><code>curl -X POST "https://your-domain.com/api/upload" \
  -H "Content-Type: multipart/form-data" \
  -F "image=@your-image.jpg" \
  -F "key=your-api-key" \
  -F "project_name=my-project"</code></pre>
        </div>
      </div>
      <div class="step-card">
        <div class="step-number">2</div>
        <h3>Get Resized Images</h3>
        <div class="code-block">
<pre><code>&lt;!-- Original image --&gt;
&lt;img src="https://your-domain.com/image/my-project/image-id/800/600/image.webp" /&gt;

&lt;!-- Different sizes --&gt;
&lt;img src="https://your-domain.com/image/my-project/image-id/400/300/image.webp" /&gt;
&lt;img src="https://your-domain.com/image/my-project/image-id/200/150/image.jpg" /&gt;</code></pre>
        </div>
      </div>
    </div>
  </div>
</section>

</div>