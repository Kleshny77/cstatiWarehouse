package filetype

import (
	"testing"
)

func TestDetectImageType(t *testing.T) {
	tests := []struct {
		name      string
		data      []byte
		wantMIME  string
		wantExt   string
		wantError error
	}{
		{
			name:      "JPEG image",
			data:      []byte{0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01},
			wantMIME:  "image/jpeg",
			wantExt:   ".jpg",
			wantError: nil,
		},
		{
			name:      "PNG image",
			data:      []byte{0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D},
			wantMIME:  "image/png",
			wantExt:   ".png",
			wantError: nil,
		},
		{
			name:      "WebP image",
			data:      []byte{0x52, 0x49, 0x46, 0x46, 0x00, 0x00, 0x00, 0x00, 0x57, 0x45, 0x42, 0x50},
			wantMIME:  "image/webp",
			wantExt:   ".webp",
			wantError: nil,
		},
		{
			name:      "HEIC image (heic brand)",
			data:      []byte{0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70, 0x68, 0x65, 0x69, 0x63},
			wantMIME:  "image/heic",
			wantExt:   ".heic",
			wantError: nil,
		},
		{
			name:      "HEIC image (heix brand)",
			data:      []byte{0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70, 0x68, 0x65, 0x69, 0x78},
			wantMIME:  "image/heic",
			wantExt:   ".heic",
			wantError: nil,
		},
		{
			name:      "HEIF image (mif1 brand)",
			data:      []byte{0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70, 0x6D, 0x69, 0x66, 0x31},
			wantMIME:  "image/heif",
			wantExt:   ".heif",
			wantError: nil,
		},
		{
			name:      "Unknown file type",
			data:      []byte{0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00},
			wantMIME:  "",
			wantExt:   "",
			wantError: ErrUnknownFileType,
		},
		{
			name:      "Insufficient data",
			data:      []byte{0xFF, 0xD8},
			wantMIME:  "",
			wantExt:   "",
			wantError: ErrInsufficientData,
		},
		{
			name:      "Text file disguised as JPEG (wrong magic)",
			data:      []byte{0x00, 0x00, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01},
			wantMIME:  "",
			wantExt:   "",
			wantError: ErrUnknownFileType,
		},
		{
			name:      "WebP without WEBP marker (invalid)",
			data:      []byte{0x52, 0x49, 0x46, 0x46, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00},
			wantMIME:  "",
			wantExt:   "",
			wantError: ErrUnknownFileType,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := DetectImageType(tt.data)

			if tt.wantError != nil {
				if err != tt.wantError {
					t.Errorf("DetectImageType() error = %v, wantError %v", err, tt.wantError)
				}
				return
			}

			if err != nil {
				t.Errorf("DetectImageType() unexpected error = %v", err)
				return
			}

			if got.MIME != tt.wantMIME {
				t.Errorf("DetectImageType() MIME = %v, want %v", got.MIME, tt.wantMIME)
			}
			if got.Extension != tt.wantExt {
				t.Errorf("DetectImageType() Extension = %v, want %v", got.Extension, tt.wantExt)
			}
		})
	}
}

func TestIsImageMIME(t *testing.T) {
	tests := []struct {
		mimeType string
		want     bool
	}{
		{"image/jpeg", true},
		{"image/png", true},
		{"image/webp", true},
		{"image/heic", true},
		{"image/heif", true},
		{"image/gif", false},
		{"image/svg+xml", false},
		{"text/plain", false},
		{"application/pdf", false},
		{"", false},
	}

	for _, tt := range tests {
		t.Run(tt.mimeType, func(t *testing.T) {
			if got := IsImageMIME(tt.mimeType); got != tt.want {
				t.Errorf("IsImageMIME(%q) = %v, want %v", tt.mimeType, got, tt.want)
			}
		})
	}
}

func TestValidateImageFile(t *testing.T) {
	tests := []struct {
		name      string
		data      []byte
		wantValid bool
	}{
		{
			name:      "Valid JPEG",
			data:      []byte{0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01},
			wantValid: true,
		},
		{
			name:      "Valid PNG",
			data:      []byte{0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D},
			wantValid: true,
		},
		{
			name:      "Invalid file",
			data:      []byte{0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00},
			wantValid: false,
		},
		{
			name:      "Insufficient data",
			data:      []byte{0xFF, 0xD8},
			wantValid: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err := ValidateImageFile(tt.data)
			gotValid := err == nil

			if gotValid != tt.wantValid {
				t.Errorf("ValidateImageFile() valid = %v, want %v (error: %v)", gotValid, tt.wantValid, err)
			}
		})
	}
}
