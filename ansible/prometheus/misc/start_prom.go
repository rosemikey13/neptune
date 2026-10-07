package main

import (
	"os"
	"os/exec"
)

func main() {
	cmd := exec.Command("/usr/local/prometheus/prometheus", "--config.file=prometheus.yml")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Start()
}
