package invitecode

import (
	"crypto/rand"
	"math/big"
)

// alphabet — без визуально похожих символов (0/O, 1/I/L).
const alphabet = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"

// Generator выпускает короткие читаемые коды инвайтов.
type Generator struct {
	length int
}

// NewGenerator возвращает генератор кодов заданной длины. length <= 0 заменяется на 8.
func NewGenerator(length int) *Generator {
	if length <= 0 {
		length = 8
	}
	return &Generator{length: length}
}

// Generate возвращает случайный код длиной length из alphabet.
func (g *Generator) Generate() (string, error) {
	out := make([]byte, g.length)
	max := big.NewInt(int64(len(alphabet)))
	for i := range out {
		n, err := rand.Int(rand.Reader, max)
		if err != nil {
			return "", err
		}
		out[i] = alphabet[n.Int64()]
	}
	return string(out), nil
}
