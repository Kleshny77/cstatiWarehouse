# CDN & S3 Integration — Интеграция с S3 и CDN для изображений

## Overview

Миграция хранения изображений с локального файлового хранилища на Amazon S3 с CloudFront CDN для улучшения производительности, масштабируемости и надежности. Система обеспечивает быструю доставку изображений пользователям по всему миру с минимальной задержкой.

## Current State vs Target State

### Current Implementation
- ✅ Локальное хранилище в `backend/uploads/`
- ✅ Прямая отдача файлов через Go HTTP handler
- ❌ Нет масштабируемости (один сервер)
- ❌ Нет географического распределения
- ❌ Нет автоматического резервного копирования
- ❌ Ограниченная пропускная способность
- ❌ Нет оптимизации изображений

### Target Implementation
- ✅ Amazon S3 для хранения
- ✅ CloudFront CDN для доставки
- ✅ Автоматическое резервное копирование
- ✅ Географическое распределение (edge locations)
- ✅ Неограниченная масштабируемость
- ✅ Оптимизация изображений (Lambda@Edge)
- ✅ Signed URLs для безопасности
- ✅ Lifecycle policies для управления хранением

## Architecture

```
┌─────────────┐
│  iOS Client │
└──────┬──────┘
       │
       │ 1. Request upload URL
       ▼
┌─────────────────┐
│  Backend API    │
│  (Go Server)    │
└────────┬────────┘
         │
         │ 2. Generate presigned URL
         ▼
┌─────────────────┐
│   Amazon S3     │
│   (Storage)     │
└────────┬────────┘
         │
         │ 3. Upload image
         │
         ▼
┌─────────────────┐
│  CloudFront CDN │
│  (Delivery)     │
└────────┬────────┘
         │
         │ 4. Fetch optimized image
         ▼
┌─────────────────┐
│   iOS Client    │
└─────────────────┘
```

## AWS Setup

### 1. S3 Bucket Configuration

**Bucket Name**: `cstati-warehouse-images-prod`

**Bucket Policy**:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowCloudFrontAccess",
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudfront.amazonaws.com"
      },
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::cstati-warehouse-images-prod/*",
      "Condition": {
        "StringEquals": {
          "AWS:SourceArn": "arn:aws:cloudfront::ACCOUNT_ID:distribution/DISTRIBUTION_ID"
        }
      }
    }
  ]
}
```

**CORS Configuration**:
```json
[
  {
    "AllowedHeaders": ["*"],
    "AllowedMethods": ["GET", "PUT", "POST", "DELETE"],
    "AllowedOrigins": [
      "https://cstati-warehouse.app",
      "http://localhost:3000"
    ],
    "ExposeHeaders": ["ETag"],
    "MaxAgeSeconds": 3000
  }
]
```

**Lifecycle Policy**:
```json
{
  "Rules": [
    {
      "Id": "DeleteIncompleteUploads",
      "Status": "Enabled",
      "Prefix": "",
      "AbortIncompleteMultipartUpload": {
        "DaysAfterInitiation": 7
      }
    },
    {
      "Id": "TransitionToIA",
      "Status": "Enabled",
      "Prefix": "archived/",
      "Transitions": [
        {
          "Days": 90,
          "StorageClass": "STANDARD_IA"
        },
        {
          "Days": 180,
          "StorageClass": "GLACIER"
        }
      ]
    }
  ]
}
```

### 2. CloudFront Distribution

**Origin Settings**:
- Origin Domain: `cstati-warehouse-images-prod.s3.amazonaws.com`
- Origin Access: Origin Access Control (OAC)
- Enable Origin Shield: Yes (us-east-1)

**Cache Behavior**:
- Viewer Protocol Policy: Redirect HTTP to HTTPS
- Allowed HTTP Methods: GET, HEAD, OPTIONS
- Cache Policy: CachingOptimized
- Compress Objects Automatically: Yes

**Custom Headers**:
```
Cache-Control: public, max-age=31536000, immutable
```

**Lambda@Edge Functions**:
1. **Image Optimization** (Origin Response):
   - Resize images on-the-fly
   - Convert to WebP format
   - Optimize quality

2. **Security Headers** (Viewer Response):
   - Add security headers
   - CORS headers

### 3. IAM Configuration

**IAM User**: `cstati-warehouse-s3-uploader`

**IAM Policy**:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::cstati-warehouse-images-prod",
        "arn:aws:s3:::cstati-warehouse-images-prod/*"
      ]
    }
  ]
}
```

## Backend Implementation

### Configuration

**`backend/internal/infra/config/config.go`** (add):

```go
type S3Config struct {
    Enabled         bool   `env:"S3_ENABLED" envDefault:"false"`
    Bucket          string `env:"S3_BUCKET" envDefault:"cstati-warehouse-images-prod"`
    Region          string `env:"S3_REGION" envDefault:"us-east-1"`
    AccessKeyID     string `env:"AWS_ACCESS_KEY_ID"`
    SecretAccessKey string `env:"AWS_SECRET_ACCESS_KEY"`
    CloudFrontURL   string `env:"CLOUDFRONT_URL" envDefault:"https://d1234567890.cloudfront.net"`
    PresignExpiry   int    `env:"S3_PRESIGN_EXPIRY" envDefault:"900"` // 15 minutes
}
```

**`.env`** (add):
```bash
# S3 Configuration
S3_ENABLED=true
S3_BUCKET=cstati-warehouse-images-prod
S3_REGION=us-east-1
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
CLOUDFRONT_URL=https://d1234567890.cloudfront.net
S3_PRESIGN_EXPIRY=900
```

### S3 Service

**`backend/internal/infra/storage/s3_storage.go`**:

```go
package storage

import (
    "context"
    "fmt"
    "io"
    "path/filepath"
    "time"
    
    "github.com/aws/aws-sdk-go-v2/aws"
    "github.com/aws/aws-sdk-go-v2/config"
    "github.com/aws/aws-sdk-go-v2/credentials"
    "github.com/aws/aws-sdk-go-v2/service/s3"
    "github.com/aws/aws-sdk-go-v2/service/s3/types"
    "github.com/google/uuid"
)

type S3Storage struct {
    client        *s3.Client
    bucket        string
    cloudFrontURL string
    presignExpiry time.Duration
}

func NewS3Storage(
    accessKeyID string,
    secretAccessKey string,
    region string,
    bucket string,
    cloudFrontURL string,
    presignExpiry int,
) (*S3Storage, error) {
    cfg, err := config.LoadDefaultConfig(context.Background(),
        config.WithRegion(region),
        config.WithCredentialsProvider(
            credentials.NewStaticCredentialsProvider(accessKeyID, secretAccessKey, ""),
        ),
    )
    if err != nil {
        return nil, fmt.Errorf("failed to load AWS config: %w", err)
    }
    
    client := s3.NewFromConfig(cfg)
    
    return &S3Storage{
        client:        client,
        bucket:        bucket,
        cloudFrontURL: cloudFrontURL,
        presignExpiry: time.Duration(presignExpiry) * time.Second,
    }, nil
}

// GeneratePresignedUploadURL generates a presigned URL for uploading
func (s *S3Storage) GeneratePresignedUploadURL(
    ctx context.Context,
    filename string,
    contentType string,
) (string, string, error) {
    // Generate unique key
    ext := filepath.Ext(filename)
    key := fmt.Sprintf("uploads/%s/%s%s", 
        time.Now().Format("2006/01/02"),
        uuid.New().String(),
        ext,
    )
    
    // Create presign client
    presignClient := s3.NewPresignClient(s.client)
    
    // Generate presigned PUT URL
    presignResult, err := presignClient.PresignPutObject(ctx, &s3.PutObjectInput{
        Bucket:      aws.String(s.bucket),
        Key:         aws.String(key),
        ContentType: aws.String(contentType),
        ACL:         types.ObjectCannedACLPrivate,
        Metadata: map[string]string{
            "uploaded-at": time.Now().Format(time.RFC3339),
        },
    }, s3.WithPresignExpires(s.presignExpiry))
    
    if err != nil {
        return "", "", fmt.Errorf("failed to generate presigned URL: %w", err)
    }
    
    // Return presigned URL and final CloudFront URL
    cloudFrontURL := fmt.Sprintf("%s/%s", s.cloudFrontURL, key)
    
    return presignResult.URL, cloudFrontURL, nil
}

// Upload uploads a file directly (alternative to presigned URL)
func (s *S3Storage) Upload(
    ctx context.Context,
    filename string,
    contentType string,
    body io.Reader,
) (string, error) {
    ext := filepath.Ext(filename)
    key := fmt.Sprintf("uploads/%s/%s%s",
        time.Now().Format("2006/01/02"),
        uuid.New().String(),
        ext,
    )
    
    _, err := s.client.PutObject(ctx, &s3.PutObjectInput{
        Bucket:      aws.String(s.bucket),
        Key:         aws.String(key),
        Body:        body,
        ContentType: aws.String(contentType),
        ACL:         types.ObjectCannedACLPrivate,
        Metadata: map[string]string{
            "uploaded-at": time.Now().Format(time.RFC3339),
        },
    })
    
    if err != nil {
        return "", fmt.Errorf("failed to upload to S3: %w", err)
    }
    
    cloudFrontURL := fmt.Sprintf("%s/%s", s.cloudFrontURL, key)
    return cloudFrontURL, nil
}

// Delete deletes a file from S3
func (s *S3Storage) Delete(ctx context.Context, url string) error {
    // Extract key from CloudFront URL
    key := extractKeyFromURL(url, s.cloudFrontURL)
    if key == "" {
        return fmt.Errorf("invalid URL format")
    }
    
    _, err := s.client.DeleteObject(ctx, &s3.DeleteObjectInput{
        Bucket: aws.String(s.bucket),
        Key:    aws.String(key),
    })
    
    if err != nil {
        return fmt.Errorf("failed to delete from S3: %w", err)
    }
    
    return nil
}

// GeneratePresignedDownloadURL generates a presigned URL for downloading
func (s *S3Storage) GeneratePresignedDownloadURL(
    ctx context.Context,
    url string,
    expiry time.Duration,
) (string, error) {
    key := extractKeyFromURL(url, s.cloudFrontURL)
    if key == "" {
        return "", fmt.Errorf("invalid URL format")
    }
    
    presignClient := s3.NewPresignClient(s.client)
    
    presignResult, err := presignClient.PresignGetObject(ctx, &s3.GetObjectInput{
        Bucket: aws.String(s.bucket),
        Key:    aws.String(key),
    }, s3.WithPresignExpires(expiry))
    
    if err != nil {
        return "", fmt.Errorf("failed to generate presigned download URL: %w", err)
    }
    
    return presignResult.URL, nil
}

// Helper function to extract S3 key from CloudFront URL
func extractKeyFromURL(url, cloudFrontURL string) string {
    if len(url) <= len(cloudFrontURL)+1 {
        return ""
    }
    return url[len(cloudFrontURL)+1:]
}
```

### Storage Interface

**`backend/internal/usecase/ports.go`** (add):

```go
type FileStorage interface {
    // GeneratePresignedUploadURL generates a presigned URL for client-side upload
    GeneratePresignedUploadURL(ctx context.Context, filename, contentType string) (uploadURL, finalURL string, err error)
    
    // Upload uploads a file directly (server-side)
    Upload(ctx context.Context, filename, contentType string, body io.Reader) (url string, err error)
    
    // Delete deletes a file
    Delete(ctx context.Context, url string) error
    
    // GeneratePresignedDownloadURL generates a presigned URL for downloading private files
    GeneratePresignedDownloadURL(ctx context.Context, url string, expiry time.Duration) (string, error)
}
```

### HTTP Handler Updates

**`backend/internal/adapter/httpapi/uploads_handler.go`** (update):

```go
package httpapi

import (
    "encoding/json"
    "net/http"
    
    "cstatiWarehouse/internal/usecase"
)

type UploadsHandler struct {
    storage usecase.FileStorage
}

func NewUploadsHandler(storage usecase.FileStorage) *UploadsHandler {
    return &UploadsHandler{storage: storage}
}

type generateUploadURLRequest struct {
    Filename    string `json:"filename"`
    ContentType string `json:"content_type"`
}

type generateUploadURLResponse struct {
    UploadURL string `json:"upload_url"`
    FinalURL  string `json:"final_url"`
    ExpiresIn int    `json:"expires_in"` // seconds
}

// GenerateUploadURL generates a presigned URL for client-side upload
func (h *UploadsHandler) GenerateUploadURL(w http.ResponseWriter, r *http.Request) {
    var req generateUploadURLRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        respondError(w, http.StatusBadRequest, "invalid request body")
        return
    }
    
    // Validate content type
    if !isValidImageContentType(req.ContentType) {
        respondError(w, http.StatusBadRequest, "invalid content type")
        return
    }
    
    uploadURL, finalURL, err := h.storage.GeneratePresignedUploadURL(
        r.Context(),
        req.Filename,
        req.ContentType,
    )
    if err != nil {
        respondError(w, http.StatusInternalServerError, "failed to generate upload URL")
        return
    }
    
    respondJSON(w, http.StatusOK, generateUploadURLResponse{
        UploadURL: uploadURL,
        FinalURL:  finalURL,
        ExpiresIn: 900, // 15 minutes
    })
}

func isValidImageContentType(contentType string) bool {
    validTypes := []string{
        "image/jpeg",
        "image/png",
        "image/webp",
        "image/heic",
        "image/heif",
    }
    
    for _, valid := range validTypes {
        if contentType == valid {
            return true
        }
    }
    
    return false
}
```

### Router Integration

**`backend/internal/adapter/httpapi/router.go`** (update):

```go
// Uploads
r.Route("/uploads", func(r chi.Router) {
    r.Use(authMiddleware)
    r.Post("/generate-url", uploadsHandler.GenerateUploadURL)
})
```

### Composition Root

**`backend/cmd/server/main.go`** (update):

```go
import (
    "cstatiWarehouse/internal/infra/storage"
)

func run() error {
    // ... existing code ...
    
    // Initialize storage
    var fileStorage usecase.FileStorage
    if cfg.S3.Enabled {
        s3Storage, err := storage.NewS3Storage(
            cfg.S3.AccessKeyID,
            cfg.S3.SecretAccessKey,
            cfg.S3.Region,
            cfg.S3.Bucket,
            cfg.S3.CloudFrontURL,
            cfg.S3.PresignExpiry,
        )
        if err != nil {
            return fmt.Errorf("failed to initialize S3 storage: %w", err)
        }
        fileStorage = s3Storage
        log.Println("Using S3 storage")
    } else {
        fileStorage = storage.NewLocalStorage("./uploads")
        log.Println("Using local storage")
    }
    
    // ... rest of code ...
}
```

## iOS Implementation

### Upload Service Update

**`ios/cstatiWarehouse/Services/Uploads/ApiUploadsService.swift`** (update):

```swift
//
//  ApiUploadsService.swift
//  cstatiWarehouse
//
//  Created by Артём on 29.04.2026.
//

import Foundation
import UIKit

final class ApiUploadsService: UploadsServiceProtocol {
    
    private let apiClient: APIClient
    
    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }
    
    func uploadImage(
        _ image: UIImage,
        completion: @escaping (Result<String, UploadError>) -> Void
    ) {
        // Step 1: Compress image
        guard let imageData = image.compressed(quality: 0.7, maxDimension: 2048) else {
            completion(.failure(.compressionFailed))
            return
        }
        
        // Step 2: Request presigned URL
        requestPresignedURL(
            filename: "image.jpg",
            contentType: "image/jpeg"
        ) { result in
            switch result {
            case .success(let response):
                // Step 3: Upload to S3
                self.uploadToS3(
                    data: imageData,
                    uploadURL: response.uploadURL,
                    contentType: "image/jpeg"
                ) { uploadResult in
                    switch uploadResult {
                    case .success:
                        // Return CloudFront URL
                        completion(.success(response.finalURL))
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    private func requestPresignedURL(
        filename: String,
        contentType: String,
        completion: @escaping (Result<PresignedURLResponse, UploadError>) -> Void
    ) {
        let body: [String: Any] = [
            "filename": filename,
            "content_type": contentType
        ]
        
        apiClient.request(
            method: .post,
            path: "/uploads/generate-url",
            body: body,
            decoder: JSONDecoder()
        ) { (result: Result<PresignedURLResponse, APIError>) in
            switch result {
            case .success(let response):
                completion(.success(response))
            case .failure(let error):
                completion(.failure(.networkError(error.localizedDescription)))
            }
        }
    }
    
    private func uploadToS3(
        data: Data,
        uploadURL: String,
        contentType: String,
        completion: @escaping (Result<Void, UploadError>) -> Void
    ) {
        guard let url = URL(string: uploadURL) else {
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        
        let task = URLSession.shared.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(.networkError(error.localizedDescription)))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(.invalidResponse))
                    return
                }
                
                if (200...299).contains(httpResponse.statusCode) {
                    completion(.success(()))
                } else {
                    completion(.failure(.uploadFailed(statusCode: httpResponse.statusCode)))
                }
            }
        }
        
        task.resume()
    }
}

struct PresignedURLResponse: Decodable {
    let uploadURL: String
    let finalURL: String
    let expiresIn: Int
    
    enum CodingKeys: String, CodingKey {
        case uploadURL = "upload_url"
        case finalURL = "final_url"
        case expiresIn = "expires_in"
    }
}

enum UploadError: Error {
    case compressionFailed
    case invalidURL
    case invalidResponse
    case networkError(String)
    case uploadFailed(statusCode: Int)
    
    var message: String {
        switch self {
        case .compressionFailed:
            return "Не удалось сжать изображение"
        case .invalidURL:
            return "Неверный URL"
        case .invalidResponse:
            return "Неверный ответ сервера"
        case .networkError(let message):
            return "Ошибка сети: \(message)"
        case .uploadFailed(let statusCode):
            return "Ошибка загрузки (код \(statusCode))"
        }
    }
}
```

## Lambda@Edge for Image Optimization

**`lambda-edge/image-optimizer/index.js`**:

```javascript
const AWS = require('aws-sdk');
const Sharp = require('sharp');

const S3 = new AWS.S3({ region: 'us-east-1' });

exports.handler = async (event) => {
    const response = event.Records[0].cf.response;
    const request = event.Records[0].cf.request;
    
    // Parse query parameters for image transformations
    const params = new URLSearchParams(request.querystring);
    const width = parseInt(params.get('w')) || null;
    const height = parseInt(params.get('h')) || null;
    const quality = parseInt(params.get('q')) || 80;
    const format = params.get('f') || 'webp';
    
    // Only process images
    if (!request.uri.match(/\.(jpg|jpeg|png|webp)$/i)) {
        return response;
    }
    
    // If no transformations requested, return original
    if (!width && !height && format === 'original') {
        return response;
    }
    
    try {
        // Get original image from S3
        const s3Object = await S3.getObject({
            Bucket: 'cstati-warehouse-images-prod',
            Key: request.uri.substring(1) // Remove leading slash
        }).promise();
        
        // Transform image with Sharp
        let transformer = Sharp(s3Object.Body);
        
        if (width || height) {
            transformer = transformer.resize(width, height, {
                fit: 'inside',
                withoutEnlargement: true
            });
        }
        
        if (format === 'webp') {
            transformer = transformer.webp({ quality });
        } else if (format === 'jpeg' || format === 'jpg') {
            transformer = transformer.jpeg({ quality });
        } else if (format === 'png') {
            transformer = transformer.png({ quality });
        }
        
        const transformedImage = await transformer.toBuffer();
        
        // Update response
        response.status = 200;
        response.body = transformedImage.toString('base64');
        response.bodyEncoding = 'base64';
        response.headers['content-type'] = [{ 
            key: 'Content-Type', 
            value: `image/${format}` 
        }];
        response.headers['cache-control'] = [{ 
            key: 'Cache-Control', 
            value: 'public, max-age=31536000, immutable' 
        }];
        
        return response;
    } catch (error) {
        console.error('Image optimization error:', error);
        return response; // Return original on error
    }
};
```

## Migration Strategy

### Phase 1: Dual Write (Week 1)
1. Deploy S3 integration code
2. Write to both local storage AND S3
3. Read from local storage (fallback to S3)
4. Monitor for errors

### Phase 2: Dual Read (Week 2)
1. Read from S3 (fallback to local)
2. Continue dual write
3. Verify all new uploads go to S3

### Phase 3: S3 Only (Week 3)
1. Stop writing to local storage
2. Read only from S3
3. Migrate existing files to S3

### Phase 4: Cleanup (Week 4)
1. Remove local storage code
2. Delete local files
3. Update documentation

## Cost Estimation

### S3 Storage
- **Standard Storage**: $0.023/GB/month
- **Requests**: $0.005 per 1,000 PUT, $0.0004 per 1,000 GET
- **Data Transfer Out**: $0.09/GB (first 10 TB)

**Example** (1000 users, 10 images each, 500KB average):
- Storage: 5 GB × $0.023 = $0.12/month
- Uploads: 10,000 × $0.005/1000 = $0.05
- **Total**: ~$0.20/month

### CloudFront
- **Data Transfer Out**: $0.085/GB (first 10 TB)
- **Requests**: $0.0075 per 10,000 HTTP requests

**Example** (100,000 image views/month, 200KB average):
- Transfer: 20 GB × $0.085 = $1.70/month
- Requests: 100,000 × $0.0075/10,000 = $0.075
- **Total**: ~$1.80/month

**Grand Total**: ~$2/month for small scale

## Monitoring & Alerts

### CloudWatch Metrics
- S3 bucket size
- Number of objects
- Request count
- Error rate
- CloudFront cache hit ratio

### Alerts
- High error rate (> 1%)
- Low cache hit ratio (< 80%)
- Unusual upload volume
- High costs

## Security Best Practices

1. **Never expose AWS credentials** in client code
2. **Use presigned URLs** with short expiry (15 min)
3. **Validate file types** on backend
4. **Scan uploads** for malware (optional: ClamAV)
5. **Enable S3 versioning** for backup
6. **Use CloudFront signed URLs** for private content
7. **Enable S3 access logging**
8. **Rotate IAM credentials** regularly

## Performance Optimization

1. **Use CloudFront** for global distribution
2. **Enable compression** in CloudFront
3. **Optimize images** before upload (iOS side)
4. **Use WebP format** when supported
5. **Implement lazy loading** (see next doc)
6. **Cache aggressively** (1 year for immutable images)
7. **Use responsive images** (multiple sizes)

## Backup & Disaster Recovery

1. **Enable S3 versioning**
2. **Cross-region replication** to backup bucket
3. **Lifecycle policy** to Glacier for old images
4. **Regular backup verification**
5. **Documented restore procedure**

## References

- [AWS S3 Documentation](https://docs.aws.amazon.com/s3/)
- [CloudFront Documentation](https://docs.aws.amazon.com/cloudfront/)
- [Lambda@Edge Documentation](https://docs.aws.amazon.com/lambda/latest/dg/lambda-edge.html)
- [AWS SDK for Go v2](https://aws.github.io/aws-sdk-go-v2/)
