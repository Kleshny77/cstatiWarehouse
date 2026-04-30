package httpapi

import (
	"encoding/json"
	"net/http"

	"github.com/Kleshny77/cstatiWarehouse/backend/pkg/apierror"
)

type errorBody = apierror.Response

func writeJSON(w http.ResponseWriter, status int, body any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	if body == nil {
		return
	}
	_ = json.NewEncoder(w).Encode(body)
}

func writeError(w http.ResponseWriter, r *http.Request, err error) {
	status, code, message := apierror.MapDomainError(err)
	apierror.LogError(status, err, r.URL.Path)
	writeJSON(w, status, apierror.Response{Error: code, Message: message})
}

func writeHTTPError(w http.ResponseWriter, httpErr apierror.HTTPError) {
	writeJSON(w, httpErr.StatusCode, httpErr.Response)
}
