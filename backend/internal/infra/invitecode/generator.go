package invitecode

import (
	"crypto/rand"
	"math/big"
)

// alphabet — без визуально похожих символов (0/O, 1/I/L).
const alphabet = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"

// DefaultLength — длина кода по умолчанию (≈100 бит энтропии при алфавите из 32 символов).
const DefaultLength = 20

// Generator выпускает читаемые коды инвайтов.
type Generator struct {
	length int
}

// NewGenerator возвращает генератор кодов заданной длины. length <= 0 заменяется на DefaultLength.
func NewGenerator(length int) *Generator {
	if length <= 0 {
		length = DefaultLength
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
