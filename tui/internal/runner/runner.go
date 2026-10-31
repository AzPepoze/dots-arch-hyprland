package runner

import (
	"os"
	"os/exec"
)

func Bash(path string, args ...string) *exec.Cmd {
	c := exec.Command("bash", append([]string{path}, args...)...)
	c.Stdin = os.Stdin
	c.Stdout = os.Stdout
	c.Stderr = os.Stderr
	return c
}
