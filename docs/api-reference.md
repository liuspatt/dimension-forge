# API Reference

Complete API documentation for DimensionForge image processing service.

## Base URL

```
https://your-domain.com
```

## Authentication

DimensionForge uses API key authentication. Include your API key in requests either as:

1. **Form parameter**: `key=your_api_key`
2. **Header**: `X-API-Key: your_api_key`
3. **Query parameter**: `?key=your_api_key`

### Getting an API Key

Contact your administrator or create one programmatically:

```bash
# Using the console
docker exec -it dimension-forge-container mix run -e "
  {:ok, api_key} = DimensionForge.ApiKeys.create_api_key(%{
    \"name\" => \"My Project API\",
    \"project_name\" => \"my-project\"
  })
  IO.puts(\"API Key: #{api_key.key}\")
"
```

## Endpoints Overview

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/api/upload` | Upload an image |
| `GET` | `/image/{project}/{id}/{width}/{height}/{filename}` | Get resized image |
| `GET` | `/{width}/{height}/{filename}` | Get resized image (with headers) |
| `POST` | `/api/validate-key` | Validate API key |
| `GET` | `/api/image/{id}` | Get image metadata |
| `DELETE` | `/api/image/{id}/variants` | Reset image variants |
| `DELETE` | `/api/images/variants` | Reset all variants |
| `GET` | `/` | Health check |

---

## Image Upload

Upload an image to be processed and stored.

### Request

```http
POST /api/upload
Content-Type: multipart/form-data
```

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `image` | file | Yes | Image file to upload |
| `key` | string | Yes | API key for authentication |
| `project_name` | string | No | Project name (uses API key default if not provided) |

#### Supported Formats

- **Input**: JPEG, PNG, GIF, BMP, TIFF, WebP, SVG
- **Output**: JPEG, PNG, WebP, GIF, BMP, TIFF

#### Size Limits

- **Maximum file size**: 10MB (configurable)
- **Maximum resolution**: 8000x8000 pixels

### Response

#### Success Response

```json
{
  "success": true,
  "data": {
    "image_id": "550e8400-e29b-41d4-a716-446655440000",
    "project_name": "my-project",
    "original_url": "https://storage.googleapis.com/bucket/originals/my-project/550e8400.jpg",
    "formats": ["jpg", "png", "webp", "gif", "bmp", "tiff"],
    "variants": {
      "400x300_webp": "https://storage.googleapis.com/bucket/variants/my-project/550e8400/400x300.webp",
      "800x600_jpg": "https://storage.googleapis.com/bucket/variants/my-project/550e8400/800x600.jpg"
    }
  }
}
```

#### Error Response

```json
{
  "success": false,
  "error": "File must be an image"
}
```

### Example Requests

#### cURL

```bash
curl -X POST "https://your-domain.com/api/upload" \
  -H "Content-Type: multipart/form-data" \
  -F "image=@photo.jpg" \
  -F "key=your_api_key" \
  -F "project_name=my-project"
```

#### JavaScript

```javascript
const formData = new FormData();
formData.append('image', fileInput.files[0]);
formData.append('key', 'your_api_key');
formData.append('project_name', 'my-project');

const response = await fetch('https://your-domain.com/api/upload', {
  method: 'POST',
  body: formData
});

const result = await response.json();
console.log(result);
```

#### Python

```python
import requests

files = {'image': open('photo.jpg', 'rb')}
data = {
    'key': 'your_api_key',
    'project_name': 'my-project'
}

response = requests.post(
    'https://your-domain.com/api/upload',
    files=files,
    data=data
)

print(response.json())
```

---

## Image Retrieval

Get resized and optimized images on-demand.

### Request

```http
GET /image/{project_name}/{image_id}/{width}/{height}/{filename}
```

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `project_name` | string | Yes | Project name |
| `image_id` | string | Yes | Image ID from upload response |
| `width` | integer | Yes | Desired width in pixels |
| `height` | integer | Yes | Desired height in pixels |
| `filename` | string | Yes | Filename with desired format extension |
| `mode` | string | No | Resize mode: `crop`, `fit`, `fill`, `stretch` (default: `crop`) |

#### Resize Modes

- **`crop`**: Crop to exact dimensions (default)
- **`fit`**: Fit within dimensions, maintaining aspect ratio
- **`fill`**: Fill dimensions, may stretch image
- **`stretch`**: Stretch to exact dimensions, ignoring aspect ratio

#### Format Detection

The output format is determined by the file extension in the filename:

- `.jpg`, `.jpeg` → JPEG
- `.png` → PNG
- `.webp` → WebP
- `.gif` → GIF
- `.bmp` → BMP
- `.tiff` → TIFF

### Response

Returns the processed image binary data with appropriate content-type headers.

### Example Requests

#### Direct Image URLs

```html
<!-- Crop to 800x600 WebP -->
<img src="https://your-domain.com/image/my-project/550e8400-e29b-41d4-a716-446655440000/800/600/photo.webp" />

<!-- Fit within 400x300 JPEG -->
<img src="https://your-domain.com/image/my-project/550e8400-e29b-41d4-a716-446655440000/400/300/photo.jpg?mode=fit" />

<!-- Fill 1200x800 PNG -->
<img src="https://your-domain.com/image/my-project/550e8400-e29b-41d4-a716-446655440000/1200/800/photo.png?mode=fill" />
```

#### Responsive Images

```html
<picture>
  <source media="(min-width: 1200px)" 
          srcset="https://your-domain.com/image/my-project/550e8400/1200/800/photo.webp">
  <source media="(min-width: 768px)" 
          srcset="https://your-domain.com/image/my-project/550e8400/800/600/photo.webp">
  <img src="https://your-domain.com/image/my-project/550e8400/400/300/photo.webp" 
       alt="Description" />
</picture>
```

---

## URL-based Resizing

Alternative endpoint for resizing with project/image info in headers.

### Request

```http
GET /{width}/{height}/{filename}
X-Project-Name: my-project
X-Image-Id: 550e8400-e29b-41d4-a716-446655440000
```

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `width` | integer | Yes | Desired width in pixels |
| `height` | integer | Yes | Desired height in pixels |
| `filename` | string | Yes | Filename with desired format extension |
| `project_name` | string | Yes | Project name (header or query param) |
| `image_id` | string | Yes | Image ID (header or query param) |
| `mode` | string | No | Resize mode |

### Example

```bash
curl -H "X-Project-Name: my-project" \
     -H "X-Image-Id: 550e8400-e29b-41d4-a716-446655440000" \
     "https://your-domain.com/800/600/photo.webp"
```

---

## API Key Validation

Validate an API key and get key information.

### Request

```http
POST /api/validate-key
Content-Type: application/json
```

#### Body

```json
{
  "key": "your_api_key"
}
```

### Response

#### Success Response

```json
{
  "valid": true,
  "name": "My Project API",
  "id": 123,
  "project_name": "my-project"
}
```

#### Error Response

```json
{
  "valid": false,
  "error": "Invalid API key"
}
```

### Example

```bash
curl -X POST "https://your-domain.com/api/validate-key" \
  -H "Content-Type: application/json" \
  -d '{"key": "your_api_key"}'
```

---

## Image Metadata

Get metadata for an uploaded image.

### Request

```http
GET /api/image/{image_id}
X-API-Key: your_api_key
```

### Response

```json
{
  "success": true,
  "data": {
    "id": 123,
    "image_id": "550e8400-e29b-41d4-a716-446655440000",
    "project_name": "my-project",
    "image_name": "photo",
    "original_filename": "photo.jpg",
    "content_type": "image/jpeg",
    "file_size": 1024768,
    "width": 1920,
    "height": 1080,
    "formats": ["jpg", "png", "webp", "gif", "bmp", "tiff"],
    "variants": {
      "400x300_webp": "https://storage.googleapis.com/bucket/variants/...",
      "800x600_jpg": "https://storage.googleapis.com/bucket/variants/..."
    },
    "inserted_at": "2023-12-01T10:00:00Z",
    "updated_at": "2023-12-01T10:00:00Z"
  }
}
```

---

## Reset Image Variants

Delete all cached variants for an image to force regeneration.

### Request

```http
DELETE /api/image/{image_id}/variants
X-API-Key: your_api_key
```

### Response

```json
{
  "success": true,
  "message": "All variants reset successfully",
  "data": {
    "image_id": "550e8400-e29b-41d4-a716-446655440000",
    "variants_cleared": 5
  }
}
```

---

## Reset All Variants

Delete all cached variants for all images in a project.

### Request

```http
DELETE /api/images/variants
X-API-Key: your_api_key
X-Project-Name: my-project
```

### Response

```json
{
  "success": true,
  "message": "All image variants reset successfully",
  "data": {
    "project_name": "my-project",
    "images_processed": 25,
    "total_variants_cleared": 150,
    "errors": []
  }
}
```

---

## Health Check

Check if the service is running and healthy.

### Request

```http
GET /
```

### Response

```json
{
  "status": "ok",
  "service": "DimensionForge",
  "version": "0.1.0",
  "timestamp": "2023-12-01T10:00:00Z"
}
```

---

## Error Responses

All endpoints return consistent error responses:

### Error Structure

```json
{
  "success": false,
  "error": "Error message",
  "code": "ERROR_CODE",
  "details": {}
}
```

### Common Error Codes

| Code | HTTP Status | Description |
|------|-------------|-------------|
| `INVALID_API_KEY` | 401 | API key is invalid or inactive |
| `MISSING_PARAMETER` | 400 | Required parameter is missing |
| `FILE_TOO_LARGE` | 400 | File exceeds size limit |
| `INVALID_FORMAT` | 400 | Unsupported file format |
| `IMAGE_NOT_FOUND` | 404 | Image not found |
| `PROCESSING_ERROR` | 500 | Image processing failed |
| `STORAGE_ERROR` | 500 | Cloud storage error |

### Example Error Responses

```json
{
  "success": false,
  "error": "File size exceeds 10MB limit",
  "code": "FILE_TOO_LARGE",
  "details": {
    "max_size": "10MB",
    "received_size": "15MB"
  }
}
```

```json
{
  "success": false,
  "error": "Invalid API key",
  "code": "INVALID_API_KEY"
}
```

---

## Rate Limiting

API requests are rate-limited to prevent abuse:

- **Rate limit**: 1000 requests per hour per API key
- **Burst limit**: 100 requests per minute per API key

Rate limit headers are included in responses:

```http
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 999
X-RateLimit-Reset: 1638360000
```

---

## SDKs and Libraries

### JavaScript/Node.js

```javascript
// npm install dimension-forge-client
const DimensionForge = require('dimension-forge-client');

const client = new DimensionForge({
  apiKey: 'your_api_key',
  baseUrl: 'https://your-domain.com'
});

// Upload image
const result = await client.upload({
  file: fs.readFileSync('photo.jpg'),
  filename: 'photo.jpg',
  projectName: 'my-project'
});

// Get image URL
const imageUrl = client.getImageUrl({
  projectName: 'my-project',
  imageId: result.data.image_id,
  width: 800,
  height: 600,
  format: 'webp'
});
```

### Python

```python
# pip install dimension-forge-python
from dimension_forge import DimensionForge

client = DimensionForge(
    api_key='your_api_key',
    base_url='https://your-domain.com'
)

# Upload image
with open('photo.jpg', 'rb') as f:
    result = client.upload(
        file=f,
        filename='photo.jpg',
        project_name='my-project'
    )

# Get image URL
image_url = client.get_image_url(
    project_name='my-project',
    image_id=result['data']['image_id'],
    width=800,
    height=600,
    format='webp'
)
```

### Go

```go
// go get github.com/your-username/dimension-forge-go
package main

import (
    "github.com/your-username/dimension-forge-go"
)

func main() {
    client := dimensionforge.NewClient(&dimensionforge.Config{
        APIKey:  "your_api_key",
        BaseURL: "https://your-domain.com",
    })

    // Upload image
    result, err := client.Upload(&dimensionforge.UploadRequest{
        File:        file,
        Filename:    "photo.jpg",
        ProjectName: "my-project",
    })

    // Get image URL
    imageURL := client.GetImageURL(&dimensionforge.ImageURLRequest{
        ProjectName: "my-project",
        ImageID:     result.Data.ImageID,
        Width:       800,
        Height:      600,
        Format:      "webp",
    })
}
```

---

## Webhooks

Configure webhooks to receive notifications about image processing events.

### Webhook Events

- `image.uploaded` - Image successfully uploaded
- `image.processed` - Image processing completed
- `image.failed` - Image processing failed
- `variant.created` - New variant created
- `variant.failed` - Variant creation failed

### Webhook Payload

```json
{
  "event": "image.uploaded",
  "timestamp": "2023-12-01T10:00:00Z",
  "data": {
    "image_id": "550e8400-e29b-41d4-a716-446655440000",
    "project_name": "my-project",
    "original_filename": "photo.jpg",
    "file_size": 1024768
  }
}
```

### Webhook Configuration

```bash
# Set webhook URL via environment variable
export WEBHOOK_URL=https://your-app.com/webhooks/dimension-forge

# Or configure via API (if webhook management endpoint exists)
curl -X POST "https://your-domain.com/api/webhooks" \
  -H "X-API-Key: your_api_key" \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://your-app.com/webhooks/dimension-forge",
    "events": ["image.uploaded", "image.processed"]
  }'
```

---

## Best Practices

### 1. Image Optimization

- Use WebP format for modern browsers
- Implement responsive images with multiple sizes
- Cache images with appropriate headers
- Use progressive JPEG for large images

### 2. Error Handling

```javascript
try {
  const result = await client.upload(file);
  console.log('Upload successful:', result);
} catch (error) {
  if (error.code === 'FILE_TOO_LARGE') {
    console.error('File is too large');
  } else if (error.code === 'INVALID_FORMAT') {
    console.error('Invalid file format');
  } else {
    console.error('Upload failed:', error.message);
  }
}
```

### 3. Performance Optimization

- Preload critical images
- Use appropriate image dimensions
- Implement lazy loading for non-critical images
- Consider using a CDN for global distribution

### 4. Security

- Keep API keys secure and rotate regularly
- Validate file types on client-side before upload
- Implement CSP headers for image sources
- Use HTTPS for all API requests

---

## Support

- **Documentation**: [https://dimension-forge.github.io](https://dimension-forge.github.io)
- **API Status**: [https://status.dimension-forge.com](https://status.dimension-forge.com)
- **GitHub Issues**: [Report bugs](https://github.com/your-username/dimension-forge/issues)
- **Community**: [Join discussions](https://github.com/your-username/dimension-forge/discussions)