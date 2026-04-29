package netutil

import (
	"net"
	"net/http"
	"strings"

	"net/netip"
)

// TrustedProxies — если пусто, ClientIP всегда берёт адрес из TCP соединения.
type TrustedProxies struct {
	prefixes []netip.Prefix
}

// ParseTrustedProxyCIDRs парсит список через запятую, например "127.0.0.1/32,10.0.0.0/8".
func ParseTrustedProxyCIDRs(raw string) (*TrustedProxies, error) {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return &TrustedProxies{}, nil
	}
	parts := strings.Split(raw, ",")
	out := make([]netip.Prefix, 0, len(parts))
	for _, p := range parts {
		p = strings.TrimSpace(p)
		if p == "" {
			continue
		}
		pr, err := netip.ParsePrefix(p)
		if err != nil {
			return nil, err
		}
		out = append(out, pr)
	}
	return &TrustedProxies{prefixes: out}, nil
}

// ClientIP возвращает IP клиента: при доверенном прокси — первый адрес из X-Forwarded-For, иначе хост из RemoteAddr.
func (t *TrustedProxies) ClientIP(r *http.Request) string {
	peerHost := hostOnly(r.RemoteAddr)
	if t == nil || len(t.prefixes) == 0 || peerHost == "" {
		return peerHost
	}
	peerIP, err := netip.ParseAddr(peerHost)
	if err != nil || !t.peerTrusted(peerIP) {
		return peerHost
	}
	xff := r.Header.Get("X-Forwarded-For")
	if xff == "" {
		return peerHost
	}
	first := strings.TrimSpace(strings.Split(xff, ",")[0])
	clientIP, err := netip.ParseAddr(first)
	if err != nil {
		return peerHost
	}
	return clientIP.String()
}

func (t *TrustedProxies) peerTrusted(peer netip.Addr) bool {
	for _, pr := range t.prefixes {
		if pr.Contains(peer) {
			return true
		}
	}
	return false
}

func hostOnly(remoteAddr string) string {
	host, _, err := net.SplitHostPort(remoteAddr)
	if err != nil {
		return strings.TrimSpace(remoteAddr)
	}
	return host
}
