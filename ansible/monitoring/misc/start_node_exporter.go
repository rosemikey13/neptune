package main

import (
	"os"
	"os/exec"
)

func main() {
	cmd := exec.Command("/usr/local/prometheus/node_exporter")
	cmd.Stderr = os.Stderr

	cmd.Start()
}
