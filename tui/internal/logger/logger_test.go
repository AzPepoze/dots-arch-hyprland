package logger

import (
	"bytes"
	"regexp"
	"strings"
	"testing"
)

func TestSameCategoryHasSameColor(t *testing.T) {
	var buf bytes.Buffer
	log := &Logger{out: &buf, color: true}

	log.log(levelInfo, "config", "first")
	log.log(levelWarn, "config", "second")

	colors := regexp.MustCompile(`\x1b\[38;2;\d+;\d+;\d+m`).FindAllString(buf.String(), -1)
	if len(colors) != 2 {
		t.Fatalf("expected 2 category colors, got %d in %q", len(colors), buf.String())
	}
	if colors[0] != colors[1] {
		t.Fatalf("same category produced different colors: %q and %q", colors[0], colors[1])
	}
}

func TestNoColorDisablesEscapes(t *testing.T) {
	t.Setenv("NO_COLOR", "1")

	var buf bytes.Buffer
	log := &Logger{out: &buf, color: colorEnabled(&buf)}
	log.log(levelError, "menu", "boom")

	if strings.Contains(buf.String(), "\x1b[") {
		t.Fatalf("expected no escape sequences, got %q", buf.String())
	}
}

func TestOutputContainsLevelCategoryAndTimestamp(t *testing.T) {
	var buf bytes.Buffer
	log := &Logger{out: &buf, color: false}
	log.log(levelSuccess, "installer", "done")

	out := buf.String()
	if !strings.Contains(out, "SUCCESS") {
		t.Fatalf("expected level in %q", out)
	}
	if !strings.Contains(out, "[installer]") {
		t.Fatalf("expected category in %q", out)
	}
	if !regexp.MustCompile(`\d{2}:\d{2}:\d{2}`).MatchString(out) {
		t.Fatalf("expected timestamp in %q", out)
	}
}
