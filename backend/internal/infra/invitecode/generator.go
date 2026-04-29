package invitecode

import (
	"crypto/rand"
	"math/big"
)

const alphabet = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"

const DefaultLength = 20

type Generator struct {
	length int
}

func NewGenerator(length int) *Generator {
	if length <= 0 {
		length = DefaultLength
	}
	return &Generator{length: length}
}

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
