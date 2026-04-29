package netutil_test

import (
	"net/http"
	"testing"

	"github.com/Kleshny77/cstatiWarehouse/backend/internal/infra/netutil"
)

func TestTrustedProxies_ClientIP_NoTrust(t *testing.T) {
	t.Parallel()
	tp, err := netutil.ParseTrustedProxyCIDRs("")
	if err != nil {
		t.Fatal(err)
	}
	req := httptestNewReq("192.168.1.10:5555", "203.0.113.5, 10.0.0.1")
	if got := tp.ClientIP(req); got != "192.168.1.10" {
		t.Fatalf("got %q", got)
	}
}

func TestTrustedProxies_ClientIP_FromXFF(t *testing.T) {
	t.Parallel()
	tp, err := netutil.ParseTrustedProxyCIDRs("127.0.0.1/32")
	if err != nil {
		t.Fatal(err)
	}
	req := httptestNewReq("127.0.0.1:5555", "203.0.113.8")
	if got := tp.ClientIP(req); got != "203.0.113.8" {
		t.Fatalf("got %q want 203.0.113.8", got)
	}
}

func httptestNewReq(remoteAddr, xff string) *http.Request {
	req := &http.Request{
		RemoteAddr: remoteAddr,
		Header:     http.Header{},
	}
	if xff != "" {
		req.Header.Set("X-Forwarded-For", xff)
	}
	return req
}
