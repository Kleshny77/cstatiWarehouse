package httpapi

import (
	"errors"
	"io"
	"log/slog"
	"mime"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"time"

	jwtpkg "github.com/Kleshny77/cstatiWarehouse/backend/internal/infra/jwt"

	"github.com/google/uuid"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/domain"
)

type UploadsHandler struct {
	uploadDir string
	publicURL string
	maxBytes  int64
	signer    *jwtpkg.UploadURLSigner
	now       func() time.Time
}

const (
	defaultMaxUploadBytes int64 = 10 << 20
)

func NewUploadsHandler(uploadDir, publicURL string, maxBytes int64, signer *jwtpkg.UploadURLSigner) *UploadsHandler {
	if maxBytes <= 0 {
		maxBytes = defaultMaxUploadBytes
	}
	return &UploadsHandler{
		uploadDir: uploadDir,
		publicURL: publicURL,
		maxBytes:  maxBytes,
		signer:    signer,
		now:       time.Now,
	}
}

type uploadResponse struct {
	URL string `json:"url"`
}

var allowedImageTypes = map[string]string{
	"image/jpeg": ".jpg",
	"image/png":  ".png",
	"image/webp": ".webp",
	"image/heic": ".heic",
	"image/heif": ".heif",
}

// Имена файлов вида <uuid>.<ext> — только то, что создаёт Upload.
var uploadFilenameRx = regexp.MustCompile(`(?i)^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(jpg|jpeg|png|webp|heic|heif)$`)

func (h *UploadsHandler) Upload(w http.ResponseWriter, r *http.Request) {
	if _, ok := currentUserID(r); !ok {
		writeError(w, r, domain.ErrUnauthorized)
		return
	}

	r.Body = http.MaxBytesReader(w, r.Body, h.maxBytes)
	if err := r.ParseMultipartForm(h.maxBytes); err != nil {
		slog.WarnContext(r.Context(), "multipart parse failed", "err", err)
		writeError(w, r, domain.NewValidationError("invalid multipart form"))
		return
	}

	file, header, err := r.FormFile("file")
	if err != nil {
		writeError(w, r, domain.NewValidationError("missing 'file' field"))
		return
	}
	defer file.Close()

	buf := make([]byte, 512)
	n, err := io.ReadFull(file, buf)
	if err != nil && !errors.Is(err, io.EOF) && !errors.Is(err, io.ErrUnexpectedEOF) {
		slog.WarnContext(r.Context(), "upload read header", "err", err)
		writeError(w, r, domain.NewValidationError("could not read upload"))
		return
	}
	mimeType := http.DetectContentType(buf[:n])
	ext, ok := allowedImageTypes[mimeType]
	if !ok {
		writeError(w, r, domain.NewValidationError("unsupported image type: "+mimeType))
		return
	}

	if headerExt := strings.ToLower(filepath.Ext(header.Filename)); headerExt != "" {
		switch headerExt {
		case ".jpg", ".jpeg", ".png", ".webp", ".heic", ".heif":
			ext = headerExt
		}
	}

	if err := os.MkdirAll(h.uploadDir, 0o755); err != nil {
		slog.ErrorContext(r.Context(), "upload mkdir", "err", err)
		writeError(w, r, domain.NewValidationError("storage unavailable"))
		return
	}

	filename := uuid.New().String() + ext
	dst, err := os.Create(filepath.Join(h.uploadDir, filename))
	if err != nil {
		slog.ErrorContext(r.Context(), "upload create file", "err", err)
		writeError(w, r, domain.NewValidationError("could not save file"))
		return
	}
	defer dst.Close()

	if _, err := dst.Write(buf[:n]); err != nil {
		slog.ErrorContext(r.Context(), "upload write head", "err", err)
		writeError(w, r, domain.NewValidationError("could not save file"))
		return
	}
	if _, err := io.Copy(dst, file); err != nil {
		slog.ErrorContext(r.Context(), "upload copy", "err", err)
		writeError(w, r, domain.NewValidationError("could not save file"))
		return
	}

	signedURL, err := h.buildSignedURL(filename)
	if err != nil {
		slog.ErrorContext(r.Context(), "upload sign url", "err", err)
		writeError(w, r, domain.NewValidationError("could not build file URL"))
		return
	}
	writeJSON(w, http.StatusCreated, uploadResponse{URL: signedURL})
}

// Download отдаёт файл только при валидном query token= (JWT).
func (h *UploadsHandler) Download(w http.ResponseWriter, r *http.Request) {
	token := strings.TrimSpace(r.URL.Query().Get("token"))
	if token == "" {
		writeError(w, r, domain.ErrUnauthorized)
		return
	}
	fileFromToken, err := h.signer.Verify(token)
	if err != nil {
		writeError(w, r, domain.ErrUnauthorized)
		return
	}

	name := strings.TrimSpace(r.PathValue("file"))
	if name == "" || name != fileFromToken || !uploadFilenameRx.MatchString(name) {
		writeError(w, r, domain.ErrUnauthorized)
		return
	}

	full := filepath.Join(h.uploadDir, filepath.Base(name))
	if rel, err := filepath.Rel(h.uploadDir, full); err != nil || strings.Contains(rel, "..") {
		writeError(w, r, domain.ErrUnauthorized)
		return
	}

	f, err := os.Open(full)
	if err != nil {
		if os.IsNotExist(err) {
			http.NotFound(w, r)
			return
		}
		slog.ErrorContext(r.Context(), "upload open", "err", err)
		writeError(w, r, domain.NewValidationError("storage unavailable"))
		return
	}
	defer f.Close()

	stat, err := f.Stat()
	if err != nil || stat.IsDir() {
		http.NotFound(w, r)
		return
	}

	ctype := mime.TypeByExtension(filepath.Ext(name))
	if ctype == "" {
		ctype = "application/octet-stream"
	}
	w.Header().Set("Content-Type", ctype)
	http.ServeContent(w, r, name, stat.ModTime(), f)
}

func (h *UploadsHandler) buildSignedURL(filename string) (string, error) {
	base := strings.TrimRight(strings.TrimSpace(h.publicURL), "/")
	if base == "" {
		return "", errors.New("PUBLIC_BASE_URL is empty")
	}
	tok, err := h.signer.Sign(filename, h.now())
	if err != nil {
		return "", err
	}
	return base + "/uploads/" + filename + "?token=" + url.QueryEscape(tok), nil
}
