package repo

import "path/filepath"

func CLIScript(repoDir, rel string) string {
	return filepath.Join(repoDir, "cli", rel)
}

func LoadConfigsScript(repoDir string) string {
	return CLIScript(repoDir, "load_configs.sh")
}
