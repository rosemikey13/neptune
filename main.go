package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"strings"
)

var modes = map[string]struct{}{"regular": struct{}{}, "development": struct{}{}}

type vmInfo struct {
	Resource struct {
		Address string `json:"address"`
		Values  struct {
			IpAddress string `json:"ip_address"`
		} `json:"values"`
	} `json:"resource"`
}

func main() {
	fmt.Println(`
....................................................................................................
..........................................:=*############+-.........................................
......................................+*#####################**-....................................
..................................:*#############*###############*=.................................
................................=*######*#################*#########+:..............................
..............................=**#################################*##**:............................
............................:****#**########################***==+******=...........................
...........................=********######################****==++********:.........................
..........................***********########*+=---==+*********++**********.........................
.........................+******+******##*=------======++*******************:.......................
........................+**************+-------=====++++*********************.......................
.......................-**************-----========+++*******#***************+......................
.......................+*************===========++++++++****####**************:.....................
......................:************+=------=======+++++****######*************=.....................
......................=************=============++++*******######*******=*****+.....................
......................==+++++++++++========++++++************#####*************.....................
.........................:+++++++++++++++++++++++++++++****#######+++++++++++++.....................
...................:......:-=++++++++++++++=+==++++++****#########++++++=::=+++.....................
...................:.........-=====+++++++++++++++*****##########+++++=......==.....................
................::::::::........-==+++++++++***********##########=====:.....:::.....................
.......................=============+*++************############===-......::::::....................
.......................:-------------+*******##################=-------------:......................
........................-----=++=-----=*#################%###+---------------.......................
.......................:=++++**********+=#########%%%%%%###=---++*********+-........................
..........................-################***#%%%%%%##*=-=++**###########+-::......................
...........................:*############################################:..........................
.............................-*####********####***#####################+............................
................................*#########*********##################=..............................
..................................:*#########*####################*.................................
......................................:+********##############*:....................................
............................................::--=++++==-:::.........................................
    		    ███╗   ██╗███████╗██████╗ ████████╗██╗   ██╗███╗   ██╗███████╗
    		    ████╗  ██║██╔════╝██╔══██╗╚══██╔══╝██║   ██║████╗  ██║██╔════╝
    		    ██╔██╗ ██║█████╗  ██████╔╝   ██║   ██║   ██║██╔██╗ ██║█████╗  
    		    ██║╚██╗██║██╔══╝  ██╔═══╝    ██║   ██║   ██║██║╚██╗██║██╔══╝  
    		    ██║ ╚████║███████╗██║        ██║   ╚██████╔╝██║ ╚████║███████╗
    		    ╚═╝  ╚═══╝╚══════╝╚═╝        ╚═╝    ╚═════╝ ╚═╝  ╚═══╝╚══════╝`)

	cli := bufio.NewReader(os.Stdin)
	fmt.Print("What mode should the project start in? (default: regular) : ")
	mode, err := cli.ReadString('\n')
	if err != nil {
		fmt.Printf("ERROR: Unable to parse input: %v", err)
		os.Exit(1)
	}

	mode = mode[:len(mode)-1]

	if mode == "" {
		mode = "regular"
	}

	if _, exists := modes[mode]; !exists {
		fmt.Printf("ERROR: Invalid mode input -- '%v'\n", mode)
		os.Exit(1)
	}

	terraformLogFile, err := os.Create("terraform.log")
	if err != nil {
		fmt.Printf("ERROR: Unable to create log file: %v", err)
		os.Exit(1)
	}

	defer terraformLogFile.Close()
	terraformBuffer := bytes.Buffer{}
	multiwriter := io.MultiWriter(terraformLogFile, &terraformBuffer)

	startTerraform := exec.Command("terraform", "apply", "-auto-approve", fmt.Sprintf("-var=op_mode=%v", mode))
	startTerraform.Stdout = multiwriter
	startTerraform.Stderr = terraformLogFile
	fmt.Println("Deploying servers...")
	err = startTerraform.Run()
	if err != nil {
		fmt.Printf("ERROR: Terraform failed execution: %v\n", err)
		os.Exit(1)
	}
	fmt.Println("Deployment complete")

	buffer := bytes.Buffer{}

	terraformList := exec.Command("terraform", "state", "list")
	terraformList.Stdout = &buffer
	err = terraformList.Run()
	if err != nil {
		fmt.Printf("ERROR: Terraform list failed execution: %v\n", err)
		os.Exit(1)
	}
	ips := []vmInfo{}
	cmdOutput := buffer.String()
	resources := strings.Split(cmdOutput, "\n")

	for _, resource := range resources {
		if strings.Contains(resource, "_vm.azurerm_public_ip.application_public_ip") {
			ipCmd := exec.Command("terraform", "state", "show", "-json", resource)
			ipCmdBuffer := bytes.Buffer{}
			ipCmd.Stdout = &ipCmdBuffer
			ipCmd.Stderr = os.Stderr
			err := ipCmd.Run()
			if err != nil {
				fmt.Printf("ERROR: %v IP command failed execution: %v\n", err, resource)
				fmt.Println(ipCmd.String())
				os.Exit(1)
			}

			vmInfo := vmInfo{}

			decoder := json.NewDecoder(&ipCmdBuffer)

			decoder.Decode(&vmInfo)

			ips = append(ips, vmInfo)
		}
	}

	bufStr := strings.Split(terraformBuffer.String(), "\n")

	jenkinsUnlock := ""

	for _, str := range bufStr {
		if strings.Contains(str, "unlock:") {
			fmt.Println(str)
			jenkinsUnlock = strings.Split(str, "unlock:")[1]
		}
	}

	fmt.Println("++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++")
	for _, vm := range ips {
		if strings.Contains(vm.Resource.Address, "jenkins") {
			fmt.Printf("++\n++\n++ %v ++++  %v \n", strings.Split(vm.Resource.Address, ".")[1], vm.Resource.Values.IpAddress+":8080")
			fmt.Println("++ Jenkins Unlock Code: " + jenkinsUnlock[:len(jenkinsUnlock)-1])
		} else {
			fmt.Printf("++\n++\n++ %v ++++  %v \n", strings.Split(vm.Resource.Address, ".")[1], vm.Resource.Values.IpAddress+":3000")
		}
	}
	fmt.Println("++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++")
}
