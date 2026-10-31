package installer

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestGenerateInstallScript(t *testing.T) {
	repoDir := t.TempDir()
	modulesDir := filepath.Join(repoDir, "scripts", "install_modules")
	if err := os.MkdirAll(modulesDir, 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(modulesDir, "helpers.sh"), nil, 0644); err != nil {
		t.Fatal(err)
	}

	commands := []string{"install_paru", "bash /tmp/load_configs.sh"}
	script := generateInstallScript(repoDir, commands)

	helpersPath := filepath.Join(modulesDir, "helpers.sh")
	if !strings.Contains(script, "source "+helpersPath) {
		t.Errorf("script does not source helpers: %q", script)
	}

	for _, command := range commands {
		call := fmt.Sprintf("run_command %q", command)
		if !strings.Contains(script, call) {
			t.Errorf("script does not contain %q", call)
		}
	}
}
