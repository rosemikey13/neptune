package main

import (
	"bufio"
	"bytes"
	"fmt"
	"os"
	"os/exec"
	"strings"
)

func main() {
	data := []byte{}
	buffer := bytes.NewBuffer(data)

	cmd := exec.Command("ls", "../")
	cmd.Stdout = buffer
	cmd.Run()
	dirsRaw := strings.Split(buffer.String(), "\n")
	dirs := dirsRaw[:len(dirsRaw)-1]
	ips := make([]string, len(dirs))

	for i, dir := range dirs {
		file, err := os.Open(fmt.Sprintf("../%s/hosts", dir))
		if err != nil {
			file.Close()
			fmt.Println("ERROR GETTING HOSTS FOR PROM: %s", err.Error())
			fmt.Println("ls out is : " + strings.Join(dirsRaw, ""))
			os.Exit(1)
		}

		scanner := bufio.NewScanner(file)
		lineNum := 1

		for scanner.Scan() {

			if scanner.Err() != nil {
				file.Close()
				fmt.Println("ERROR GETTING IPS: %s", err.Error())
				os.Exit(1)
			}

			if lineNum == 2 {
				file.Close()
				ips[i] = scanner.Text()
				break
			}

			lineNum++
		}

	}

	promFile, err := os.Create("prometheus.yml")
	if err != nil {
		fmt.Println("ERROR CREATING PROMFILE: %s", err.Error())
		os.Exit(1)
	}

	_, err = promFile.WriteString(`global:
  scrape_interval:     15s 

scrape_configs:
  - job_name: 'prometheus'
    scrape_interval: 5s
    static_configs:
      - targets: ['localhost:9090']`)

	if err != nil {
		promFile.Close()
		fmt.Println("ERROR WRITING DEFAULT DATA TO PROMFILE: %s", err.Error())
		os.Exit(1)
	}

	for i, dir := range dirs {
		if dir == "prometheus" {
			continue
		}

		_, err = promFile.WriteString(fmt.Sprintf(`
  - job_name: '%v'
    static_configs:
      - targets: ['%v:9100']`, dir, ips[i]))

		if err != nil {
			promFile.Close()
			fmt.Println("ERROR WRITING %s DATA TO PROMFILE: %s", strings.ToUpper(dir), err.Error())
			os.Exit(1)
		}
	}

	promFile.Close()
	fmt.Println("DONE WITH PROMCONFIG")

}
