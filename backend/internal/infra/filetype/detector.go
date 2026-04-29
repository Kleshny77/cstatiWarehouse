// Package filetype provides file type detection based on magic numbers (file signatures).
package filetype

import (
	"bytes"
	"errors"
)

// FileType represents a detected file type.
type FileType struct {
	MIME      string
	Extension string
}

var (
	// ErrUnknownFileType indicates the file type could not be determined.
	ErrUnknownFileType = errors.New("unknown file type")

	// ErrInsufficientData indicates not enough bytes were provided for detection.
	ErrInsufficientData = errors.New("insufficient data for file type detection")
)

// Supported image types with their magic numbers (file signatures).
var imageSignatures = []struct {
	magic     []byte
	offset    int
	mimeType  string
	extension string
}{
	// JPEG (FF D8 FF)
	{[]byte{0xFF, 0xD8, 0xFF}, 0, "image/jpeg", ".jpg"},

	// PNG (89 50 4E 47 0D 0A 1A 0A)
	{[]byte{0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A}, 0, "image/png", ".png"},

	// WebP (RIFF....WEBP)
	// WebP files start with "RIFF" at offset 0 and "WEBP" at offset 8
	{[]byte{0x52, 0x49, 0x46, 0x46}, 0, "image/webp", ".webp"},

	// HEIC/HEIF (....ftypheic or ....ftypheix or ....ftyphevc or ....ftyphevx)
	// HEIC files have "ftyp" at offset 4, followed by brand (heic, heix, hevc, hevx, mif1)
	{[]byte{0x66, 0x74, 0x79, 0x70, 0x68, 0x65, 0x69, 0x63}, 4, "image/heic", ".heic"},
	{[]byte{0x66, 0x74, 0x79, 0x70, 0x68, 0x65, 0x69, 0x78}, 4, "image/heic", ".heic"},
	{[]byte{0x66, 0x74, 0x79, 0x70, 0x68, 0x65, 0x76, 0x63}, 4, "image/heic", ".heic"},
	{[]byte{0x66, 0x74, 0x79, 0x70, 0x68, 0x65, 0x76, 0x78}, 4, "image/heic", ".heic"},
	{[]byte{0x66, 0x74, 0x79, 0x70, 0x6D, 0x69, 0x66, 0x31}, 4, "image/heif", ".heif"},
}

// DetectImageType detects the image type from the first bytes of a file.
// It requires at least 12 bytes for reliable detection.
// Returns FileType with MIME type and extension, or error if type is unknown or unsupported.
func DetectImageType(data []byte) (FileType, error) {
	if len(data) < 12 {
		return FileType{}, ErrInsufficientData
	}

	// Check each signature
	for _, sig := range imageSignatures {
		if matchesSignature(data, sig.magic, sig.offset) {
			// Special case for WebP: verify "WEBP" at offset 8
			if sig.mimeType == "image/webp" {
				if len(data) >= 12 && bytes.Equal(data[8:12], []byte("WEBP")) {
					return FileType{MIME: sig.mimeType, Extension: sig.extension}, nil
				}
				continue
			}

			return FileType{MIME: sig.mimeType, Extension: sig.extension}, nil
		}
	}

	return FileType{}, ErrUnknownFileType
}

// matchesSignature checks if data contains the magic bytes at the specified offset.
func matchesSignature(data, magic []byte, offset int) bool {
	if len(data) < offset+len(magic) {
		return false
	}
	return bytes.Equal(data[offset:offset+len(magic)], magic)
}

// IsImageMIME checks if the given MIME type is a supported image type.
func IsImageMIME(mimeType string) bool {
	switch mimeType {
	case "image/jpeg", "image/png", "image/webp", "image/heic", "image/heif":
		return true
	default:
		return false
	}
}

// ValidateImageFile validates that the file data matches one of the supported image types.
// Returns the detected FileType or an error.
func ValidateImageFile(data []byte) (FileType, error) {
	ft, err := DetectImageType(data)
	if err != nil {
		return FileType{}, err
	}

	if !IsImageMIME(ft.MIME) {
		return FileType{}, ErrUnknownFileType
	}

	return ft, nil
}
