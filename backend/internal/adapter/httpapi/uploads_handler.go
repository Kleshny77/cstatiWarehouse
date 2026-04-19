package httpapi

import (
	"errors"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"github.com/google/uuid"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/domain"
)

// UploadsHandler принимает multipart/form-data с полем `file`, сохраняет на диск
// и возвращает относительный URL `/uploads/<filename>`. Проверяет тип и размер файла.
type UploadsHandler struct {
	uploadDir string
	publicURL string
	maxBytes  int64
}

const (
	defaultMaxUploadBytes int64 = 10 << 20 // 10 MB
)

func NewUploadsHandler(uploadDir, publicURL string, maxBytes int64) *UploadsHandler {
	if maxBytes <= 0 {
		maxBytes = defaultMaxUploadBytes
	}
	return &UploadsHandler{uploadDir: uploadDir, publicURL: publicURL, maxBytes: maxBytes}
}

type uploadResponse struct {
	URL string `json:"url"`
}

// Allowed MIME → extension. Только изображения, чтобы не открывать загрузку exe/dll.
var allowedImageTypes = map[string]string{
	"image/jpeg": ".jpg",
	"image/png":  ".png",
	"image/webp": ".webp",
	"image/heic": ".heic",
	"image/heif": ".heif",
}

func (h *UploadsHandler) Upload(w http.ResponseWriter, r *http.Request) {
	if _, ok := currentUserID(r); !ok {
		writeError(w, r, domain.ErrUnauthorized)
		return
	}

	r.Body = http.MaxBytesReader(w, r.Body, h.maxBytes)
	if err := r.ParseMultipartForm(h.maxBytes); err != nil {
		writeError(w, r, domain.NewValidationError("invalid multipart form: "+err.Error()))
		return
	}

	file, header, err := r.FormFile("file")
	if err != nil {
		writeError(w, r, domain.NewValidationError("missing 'file' field"))
		return
	}
	defer file.Close()

	// Определяем тип по первым 512 байтам — не доверяем заголовку Content-Type клиента.
	buf := make([]byte, 512)
	n, err := io.ReadFull(file, buf)
	if err != nil && !errors.Is(err, io.EOF) && !errors.Is(err, io.ErrUnexpectedEOF) {
		writeError(w, r, err)
		return
	}
	mime := http.DetectContentType(buf[:n])
	ext, ok := allowedImageTypes[mime]
	if !ok {
		writeError(w, r, domain.NewValidationError("unsupported image type: "+mime))
		return
	}

	// Если клиент прислал расширение, которое совпадает с детектированным типом,
	// оставляем его, чтобы сохранить оригинальные png/jpg отметки.
	if headerExt := strings.ToLower(filepath.Ext(header.Filename)); headerExt != "" {
		switch headerExt {
		case ".jpg", ".jpeg", ".png", ".webp", ".heic", ".heif":
			ext = headerExt
		}
	}

	if err := os.MkdirAll(h.uploadDir, 0o755); err != nil {
		writeError(w, r, err)
		return
	}

	filename := uuid.New().String() + ext
	dst, err := os.Create(filepath.Join(h.uploadDir, filename))
	if err != nil {
		writeError(w, r, err)
		return
	}
	defer dst.Close()

	if _, err := dst.Write(buf[:n]); err != nil {
		writeError(w, r, err)
		return
	}
	if _, err := io.Copy(dst, file); err != nil {
		writeError(w, r, err)
		return
	}

	url := strings.TrimRight(h.publicURL, "/") + "/uploads/" + filename
	writeJSON(w, http.StatusCreated, uploadResponse{URL: url})
}

// Static возвращает http.Handler, отдающий сохранённые файлы. Без auth — URL
// сам по себе случайный UUID, это достаточно для локальной разработки.
func (h *UploadsHandler) Static() http.Handler {
	return http.StripPrefix("/uploads/", http.FileServer(http.Dir(h.uploadDir)))
}
