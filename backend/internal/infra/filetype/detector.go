// Package filetype provides file type detection based on magic numbers (file signatures).
package filetype

import (
	"bytes"
	"errors"
)

type FileType struct {
	MIME      string
	Extension string
}

var (
	ErrUnknownFileType = errors.New("unknown file type")

	ErrInsufficientData = errors.New("insufficient data for file type detection")
)

var imageSignatures = []struct {
	magic     []byte
	offset    int
	mimeType  string
	extension string
}{
	{[]byte{0xFF, 0xD8, 0xFF}, 0, "image/jpeg", ".jpg"},

	{[]byte{0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A}, 0, "image/png", ".png"},

	{[]byte{0x52, 0x49, 0x46, 0x46}, 0, "image/webp", ".webp"},

	{[]byte{0x66, 0x74, 0x79, 0x70, 0x68, 0x65, 0x69, 0x63}, 4, "image/heic", ".heic"},
	{[]byte{0x66, 0x74, 0x79, 0x70, 0x68, 0x65, 0x69, 0x78}, 4, "image/heic", ".heic"},
	{[]byte{0x66, 0x74, 0x79, 0x70, 0x68, 0x65, 0x76, 0x63}, 4, "image/heic", ".heic"},
	{[]byte{0x66, 0x74, 0x79, 0x70, 0x68, 0x65, 0x76, 0x78}, 4, "image/heic", ".heic"},
	{[]byte{0x66, 0x74, 0x79, 0x70, 0x6D, 0x69, 0x66, 0x31}, 4, "image/heif", ".heif"},
}

func DetectImageType(data []byte) (FileType, error) {
	if len(data) < 12 {
		return FileType{}, ErrInsufficientData
	}

	for _, sig := range imageSignatures {
		if matchesSignature(data, sig.magic, sig.offset) {
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

func matchesSignature(data, magic []byte, offset int) bool {
	if len(data) < offset+len(magic) {
		return false
	}
	return bytes.Equal(data[offset:offset+len(magic)], magic)
}

func IsImageMIME(mimeType string) bool {
	switch mimeType {
	case "image/jpeg", "image/png", "image/webp", "image/heic", "image/heif":
		return true
	default:
		return false
	}
}

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
