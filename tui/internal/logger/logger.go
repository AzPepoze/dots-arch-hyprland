package logger

import (
	"fmt"
	"hash/fnv"
	"io"
	"os"
	"sync"
	"time"
)

type Level int

const (
	levelInfo Level = iota
	levelSuccess
	levelWarn
	levelError
)

const reset = "\x1b[0m"

var levelLabels = map[Level]string{
	levelInfo:    "INFO",
	levelSuccess: "SUCCESS",
	levelWarn:    "WARN",
	levelError:   "ERROR",
}

var levelColors = map[Level]string{
	levelInfo:    "\x1b[36m",
	levelSuccess: "\x1b[32m",
	levelWarn:    "\x1b[33m",
	levelError:   "\x1b[31m",
}

type Logger struct {
	mu    sync.Mutex
	out   io.Writer
	color bool
}

var std = &Logger{out: os.Stderr, color: colorEnabled(os.Stderr)}

func Info(category, format string, args ...any) {
	std.log(levelInfo, category, fmt.Sprintf(format, args...))
}

func Success(category, format string, args ...any) {
	std.log(levelSuccess, category, fmt.Sprintf(format, args...))
}

func Warn(category, format string, args ...any) {
	std.log(levelWarn, category, fmt.Sprintf(format, args...))
}

func Error(category, format string, args ...any) {
	std.log(levelError, category, fmt.Sprintf(format, args...))
}

func (l *Logger) log(level Level, category, message string) {
	l.mu.Lock()
	defer l.mu.Unlock()

	timestamp := time.Now().Format("15:04:05")
	label := levelLabels[level]

	if !l.color {
		fmt.Fprintf(l.out, "%s %s [%s] %s\n", timestamp, label, category, message)
		return
	}

	fmt.Fprintf(
		l.out,
		"%s %s%s%s %s[%s]%s %s\n",
		timestamp,
		levelColors[level], label, reset,
		categoryColor(category), category, reset,
		message,
	)
}

func colorEnabled(w io.Writer) bool {
	if _, ok := os.LookupEnv("NO_COLOR"); ok {
		return false
	}
	info, err := os.Stderr.Stat()
	if err != nil {
		return false
	}
	return info.Mode()&os.ModeCharDevice != 0
}

func categoryColor(category string) string {
	r, g, b := hslToRGB(categoryHue(category), 0.5, 0.8)
	return fmt.Sprintf("\x1b[38;2;%d;%d;%dm", r, g, b)
}

func categoryHue(category string) int {
	h := fnv.New32a()
	_, _ = h.Write([]byte(category))
	return int(h.Sum32() % 360)
}

func hslToRGB(hue int, saturation, lightness float64) (int, int, int) {
	h := float64(hue) / 360
	q := lightness + saturation - lightness*saturation
	if lightness < 0.5 {
		q = lightness * (1 + saturation)
	}
	p := 2*lightness - q

	r := hueToChannel(p, q, h+1.0/3)
	g := hueToChannel(p, q, h)
	b := hueToChannel(p, q, h-1.0/3)

	return int(r*255 + 0.5), int(g*255 + 0.5), int(b*255 + 0.5)
}

func hueToChannel(p, q, t float64) float64 {
	if t < 0 {
		t++
	}
	if t > 1 {
		t--
	}
	switch {
	case t < 1.0/6:
		return p + (q-p)*6*t
	case t < 1.0/2:
		return q
	case t < 2.0/3:
		return p + (q-p)*(2.0/3-t)*6
	default:
		return p
	}
}
