package main

// A link on the page (Credits, what is new, the project page) opens in the default browser. Only web addresses.

import (
	"os/exec"
	"strings"
)

func openLink(u string) bool {
	l := strings.ToLower(u)
	if !strings.HasPrefix(l, "https://") && !strings.HasPrefix(l, "http://") {
		return false
	}
	return exec.Command("xdg-open", u).Start() == nil
}
