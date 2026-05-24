package main

import (
	"fmt"
	"os"
	"path/filepath"

	"tui/internal/config"
	"tui/internal/installer"
	"tui/internal/menu"
)

func findRepoDir() (string, error) {
	dir, err := os.Getwd()
	if err != nil {
		return "", err
	}
	for {
		if _, err := os.Stat(filepath.Join(dir, "config.json")); err == nil {
			return dir, nil
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			break
		}
		dir = parent
	}

	execPath, err := os.Executable()
	if err == nil {
		dir = filepath.Dir(execPath)
		for {
			if _, err := os.Stat(filepath.Join(dir, "config.json")); err == nil {
				return dir, nil
			}
			parent := filepath.Dir(dir)
			if parent == dir {
				break
			}
			dir = parent
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
		fmt.Printf("Error: %v\n", err)
		os.Exit(1)
	}
	switch cmd {
	case "menu":
		if err := menu.Run(repoDir); err != nil {
			fmt.Printf("Main Menu error: %v\n", err)
			os.Exit(1)
		}
	case "install":
		if err := installer.Run(repoDir); err != nil {
			fmt.Printf("Installer error: %v\n", err)
			os.Exit(1)
		}
	case "config":
		if err := config.Run(repoDir); err != nil {
			fmt.Printf("Config Editor error: %v\n", err)
			os.Exit(1)
		}
	default:
		fmt.Printf("Unknown command: %s. Usage: tui [menu|install|config]\n", cmd)
		os.Exit(1)
	}
}
