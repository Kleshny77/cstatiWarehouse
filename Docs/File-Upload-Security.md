# File Upload Security

## Overview

The cstatiWarehouse backend implements robust file upload validation using **magic number detection** (file signature verification) to prevent malicious file uploads and ensure only valid image files are accepted.

## What are Magic Numbers?

Magic numbers (also called file signatures) are specific byte sequences at the beginning of a file that identify its format. Unlike file extensions (which can be easily spoofed), magic numbers are embedded in the file content itself.

### Example Magic Numbers

| Format | Magic Bytes (Hex) | Offset |
|--------|------------------|--------|
| JPEG | `FF D8 FF` | 0 |
| PNG | `89 50 4E 47 0D 0A 1A 0A` | 0 |
| WebP | `52 49 46 46 ... 57 45 42 50` | 0, 8 |
| HEIC | `66 74 79 70 68 65 69 63` | 4 |

## Why Magic Number Validation?

### Security Risks Without Validation

1. **Extension Spoofing**: Attacker renames `malware.exe` → `malware.jpg`
2. **MIME Type Manipulation**: Client sends fake `Content-Type` header
3. **Polyglot Files**: Files valid as both image and executable
4. **Server-Side Exploits**: Malicious files processed by image libraries

### Our Defense

✅ **Magic number validation** - Verifies actual file content
✅ **Strict type allowlist** - Only JPEG, PNG, WebP, HEIC, HEIF
✅ **Size limits** - Max 10MB per upload
✅ **Extension normalization** - Uses detected type, not client-provided

## Implementation

### File Type Detector

Located in: [`backend/internal/infra/filetype/detector.go`](../backend/internal/infra/filetype/detector.go)

**Key Functions**:

```go
// DetectImageType detects image type from first bytes
func DetectImageType(data []byte) (FileType, error)

// ValidateImageFile validates file is a supported image
func ValidateImageFile(data []byte) (FileType, error)

// IsImageMIME checks if MIME type is supported
func IsImageMIME(mimeType string) bool
```

### Supported Formats

| Format | MIME Type | Extension | Magic Bytes |
|--------|-----------|-----------|-------------|
| JPEG | `image/jpeg` | `.jpg` | `FF D8 FF` |
| PNG | `image/png` | `.png` | `89 50 4E 47 0D 0A 1A 0A` |
| WebP | `image/webp` | `.webp` | `52 49 46 46` + `57 45 42 50` at offset 8 |
| HEIC | `image/heic` | `.heic` | `66 74 79 70 68 65 69 63` at offset 4 |
| HEIF | `image/heif` | `.heif` | `66 74 79 70 6D 69 66 31` at offset 4 |

### Upload Handler Integration

Located in: [`backend/internal/adapter/httpapi/uploads_handler.go`](../backend/internal/adapter/httpapi/uploads_handler.go)

**Validation Flow**:

1. Read first 512 bytes of uploaded file
2. Detect file type using magic numbers
3. Reject if type is unknown or unsupported
4. Use detected extension (not client-provided)
5. Save file with UUID filename

```go
// Read first 512 bytes
buf := make([]byte, 512)
n, err := io.ReadFull(file, buf)

// Validate using magic numbers
fileType, err := filetype.ValidateImageFile(buf[:n])
if err != nil {
    // Reject upload
    return
}

// Use detected extension
ext := fileType.Extension
```

## Security Features

### 1. Magic Number Validation

**Before** (vulnerable):
```go
// ❌ Only checks extension
ext := filepath.Ext(filename)
if ext != ".jpg" {
    return errors.New("invalid file")
}
```

**After** (secure):
```go
// ✅ Checks actual file content
fileType, err := filetype.ValidateImageFile(data)
if err != nil {
    return err
}
```

### 2. Strict Type Allowlist

Only 5 image formats are allowed:
- JPEG (most common)
- PNG (lossless)
- WebP (modern, efficient)
- HEIC/HEIF (iOS photos)

**Not allowed**:
- GIF (can contain scripts)
- SVG (XML-based, XSS risk)
- BMP (large, inefficient)
- TIFF (complex, security issues)

### 3. Size Limits

```go
// Max 10MB per upload
r.Body = http.MaxBytesReader(w, r.Body, 10<<20)
```

Configurable via `MAX_UPLOAD_BYTES` environment variable.

### 4. Filename Sanitization

```go
// Generated UUID filename, not user-provided
filename := uuid.New().String() + ext
// Example: "a1b2c3d4-e5f6-7890-abcd-ef1234567890.jpg"
```

Prevents:
- Path traversal (`../../etc/passwd`)
- Special characters
- Filename collisions

### 5. Path Traversal Protection

```go
// Verify file is within upload directory
if rel, err := filepath.Rel(h.uploadDir, full); err != nil || strings.Contains(rel, "..") {
    return domain.ErrUnauthorized
}
```

## Attack Scenarios Prevented

### Scenario 1: Extension Spoofing

**Attack**:
```bash
# Rename malware to look like image
mv malware.exe malware.jpg
curl -F "file=@malware.jpg" http://api/uploads
```

**Defense**:
```
1. Read file bytes: 4D 5A 90 00 ... (PE executable signature)
2. Detect type: ErrUnknownFileType
3. Reject upload: "unsupported or invalid image file"
```

### Scenario 2: MIME Type Manipulation

**Attack**:
```bash
# Send fake Content-Type header
curl -F "file=@malware.exe;type=image/jpeg" http://api/uploads
```

**Defense**:
```
1. Ignore Content-Type header
2. Read actual file bytes
3. Validate magic numbers
4. Reject if not a real image
```

### Scenario 3: Polyglot File

**Attack**:
```
Create file that is both:
- Valid JPEG (starts with FF D8 FF)
- Valid PHP script (contains <?php ... ?>)
```

**Defense**:
```
1. Validate magic numbers (passes as JPEG)
2. Save with .jpg extension
3. Serve with image/jpeg MIME type
4. Web server won't execute as PHP
```

**Additional Protection**: Never serve uploads from same domain as application.

### Scenario 4: Path Traversal

**Attack**:
```bash
# Try to overwrite system files
curl -F "file=@image.jpg" "http://api/uploads?name=../../etc/passwd"
```

**Defense**:
```
1. Ignore user-provided filename
2. Generate UUID filename
3. Validate path is within upload directory
4. Reject if path contains ".."
```

## Testing

### Unit Tests

Located in: [`backend/internal/infra/filetype/detector_test.go`](../backend/internal/infra/filetype/detector_test.go)

**Test Coverage**:
- ✅ Valid JPEG detection
- ✅ Valid PNG detection
- ✅ Valid WebP detection
- ✅ Valid HEIC/HEIF detection
- ✅ Invalid file rejection
- ✅ Insufficient data handling
- ✅ Spoofed extension detection

**Run Tests**:
```bash
cd backend
go test ./internal/infra/filetype/... -v
```

### Manual Testing

**Test Valid Upload**:
```bash
# Upload real JPEG
curl -X POST http://localhost:8080/uploads \
  -H "Authorization: Bearer <token>" \
  -F "file=@photo.jpg"
```

**Test Invalid Upload** (should fail):
```bash
# Try to upload text file as JPEG
echo "malicious content" > fake.jpg
curl -X POST http://localhost:8080/uploads \
  -H "Authorization: Bearer <token>" \
  -F "file=@fake.jpg"
```

Expected response:
```json
{
  "error": {
    "code": "validation_error",
    "message": "unsupported or invalid image file"
  }
}
```

## Configuration

### Environment Variables

```bash
# Maximum upload size (default: 10MB)
MAX_UPLOAD_BYTES=10485760

# Upload directory (default: ./uploads)
UPLOADS_DIR=/var/www/uploads

# Public base URL for signed URLs
PUBLIC_BASE_URL=https://api.example.com
```

### Supported Formats

To add/remove supported formats, edit:
- [`backend/internal/infra/filetype/detector.go`](../backend/internal/infra/filetype/detector.go) - Add magic number signature
- [`backend/internal/adapter/httpapi/uploads_handler.go`](../backend/internal/adapter/httpapi/uploads_handler.go) - Update `allowedImageTypes` map

## Best Practices

### 1. Never Trust Client Input

❌ **Bad**:
```go
ext := filepath.Ext(header.Filename)  // User-controlled
```

✅ **Good**:
```go
fileType, _ := filetype.DetectImageType(data)
ext := fileType.Extension  // Verified from content
```

### 2. Validate Early

Validate file type **before** saving to disk:
```go
// 1. Read bytes
// 2. Validate type
// 3. Only then save to disk
```

### 3. Use Allowlist, Not Blocklist

❌ **Bad**:
```go
if ext == ".exe" || ext == ".sh" {
    return errors.New("blocked")
}
```

✅ **Good**:
```go
if !isAllowedType(fileType) {
    return errors.New("not allowed")
}
```

### 4. Separate Upload Domain

Serve uploads from different domain:
- Application: `https://app.example.com`
- Uploads: `https://cdn.example.com` or `https://uploads.example.com`

Prevents XSS if malicious file is uploaded.

### 5. Scan Uploaded Files

Consider integrating antivirus scanning:
- ClamAV
- VirusTotal API
- Cloud-based scanning services

## Error Messages

| Error | Meaning | HTTP Status |
|-------|---------|-------------|
| `file too small` | Less than 12 bytes | 400 |
| `unsupported or invalid image file` | Not a valid image or unknown type | 400 |
| `could not validate file type` | Internal validation error | 400 |
| `missing 'file' field` | No file in multipart form | 400 |

## Monitoring

### Metrics to Track

1. **Upload attempts by type**:
   - Valid uploads (JPEG, PNG, etc.)
   - Rejected uploads (invalid type)

2. **Rejection reasons**:
   - Unknown file type
   - Insufficient data
   - Size limit exceeded

3. **Attack patterns**:
   - Multiple rejections from same IP
   - Unusual file types attempted

### Logging

Upload validation failures are logged:

```go
slog.WarnContext(r.Context(), "file type validation failed", "err", err)
```

Monitor logs for patterns indicating attacks.

## Future Improvements

1. **Image dimension validation**: Reject extremely large images
2. **Content scanning**: Integrate antivirus/malware detection
3. **Image reprocessing**: Re-encode images to strip metadata/malicious content
4. **Rate limiting**: Limit uploads per user/IP
5. **Quarantine**: Hold suspicious uploads for manual review

## Resources

- [File Signatures Database](https://www.garykessler.net/library/file_sigs.html)
- [OWASP: Unrestricted File Upload](https://owasp.org/www-community/vulnerabilities/Unrestricted_File_Upload)
- [CWE-434: Unrestricted Upload of File with Dangerous Type](https://cwe.mitre.org/data/definitions/434.html)
- [Magic Numbers (Wikipedia)](https://en.wikipedia.org/wiki/List_of_file_signatures)
