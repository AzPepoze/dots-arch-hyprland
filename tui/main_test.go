package main

import (
	"os"
	"path/filepath"
	"testing"
)

func TestWalkUpForConfig(t *testing.T) {
	root := t.TempDir()
	nested := filepath.Join(root, "a", "b", "c")
	if err := os.MkdirAll(nested, 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(root, "config.json"), nil, 0644); err != nil {
		t.Fatal(err)
	}

	got, ok := walkUpForConfig(nested)
	if !ok {
		t.Fatal("walkUpForConfig did not find config.json")
	}
	if got != root {
		t.Fatalf("walkUpForConfig = %q, want %q", got, root)
	}
}

func TestWalkUpForConfigMissing(t *testing.T) {
	root := t.TempDir()
	nested := filepath.Join(root, "a", "b")
	if err := os.MkdirAll(nested, 0755); err != nil {
		t.Fatal(err)
	}

	if _, ok := walkUpForConfig(nested); ok {
		t.Fatal("walkUpForConfig found config.json when none exists")
	}
}
