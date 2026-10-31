package main

import (
	"fmt"
	"os"
	"path/filepath"

	"tui/internal/config"
	"tui/internal/installer"
	"tui/internal/logger"
	"tui/internal/menu"
)

func walkUpForConfig(start string) (string, bool) {
	dir := start
	for {
		if _, err := os.Stat(filepath.Join(dir, "config.json")); err == nil {
			return dir, true
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			return "", false
		}
		dir = parent
	}
}

func findRepoDir() (string, error) {
	cwd, err := os.Getwd()
	if err != nil {
		return "", err
	}
	if repoDir, ok := walkUpForConfig(cwd); ok {
		return repoDir, nil
	}

	if execPath, err := os.Executable(); err == nil {
		if repoDir, ok := walkUpForConfig(filepath.Dir(execPath)); ok {
			return repoDir, nil
		}
	}
	return "", fmt.Errorf("could not find repo root directory containing config.json")
}

func main() {
	cmd := "menu"
	if len(os.Args) >= 2 {
		cmd = os.Args[1]
	}

	repoDir, err := findRepoDir()
	if err != nil {
		logger.Error("main", "Error: %v", err)
		os.Exit(1)
	}
	switch cmd {
	case "menu":
		if err := menu.Run(repoDir); err != nil {
			logger.Error("menu", "Main Menu error: %v", err)
			os.Exit(1)
		}
	case "install":
		if err := installer.Run(repoDir); err != nil {
			logger.Error("installer", "Installer error: %v", err)
			os.Exit(1)
		}
	case "config":
		if err := config.Run(repoDir); err != nil {
			logger.Error("config", "Config Editor error: %v", err)
			os.Exit(1)
		}
	default:
		logger.Error("main", "Unknown command: %s. Usage: tui [menu|install|config]", cmd)
		os.Exit(1)
	}
}
