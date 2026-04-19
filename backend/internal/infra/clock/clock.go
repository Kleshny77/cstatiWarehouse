package clock

import "time"

// Real возвращает текущее время. Реализует usecase.Clock.
type Real struct{}

func (Real) Now() time.Time { return time.Now() }
