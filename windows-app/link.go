package main

// A link on the page (Credits, what is new, the project page) opens in the default browser. Only web addresses.

import (
	"strings"
	"unsafe"

	"golang.org/x/sys/windows"
)

var pShellExecuteW = windows.NewLazySystemDLL("shell32.dll").NewProc("ShellExecuteW")

func openLink(u string) bool {
	l := strings.ToLower(u)
	if !strings.HasPrefix(l, "https://") && !strings.HasPrefix(l, "http://") {
		return false
	}
	verb, _ := windows.UTF16PtrFromString("open")
	p, err := windows.UTF16PtrFromString(u)
	if err != nil {
		return false
	}
	r, _, _ := pShellExecuteW.Call(0, uintptr(unsafe.Pointer(verb)), uintptr(unsafe.Pointer(p)), 0, 0, 1) // SW_SHOWNORMAL
	return r > 32
}
