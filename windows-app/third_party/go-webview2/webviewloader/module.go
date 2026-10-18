package webviewloader

// Changed for Reactio Draw: WebView2Loader.dll (Microsoft-signed, from the WebView2 SDK) is loaded from a file beside
// the program (WebView2Loader-x64.dll / WebView2Loader-arm64.dll, or WebView2Loader.dll), never unpacked into memory.

import (
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"unsafe"

	"golang.org/x/sys/windows"
)

func loaderPath() string {
	exe, err := os.Executable()
	if err == nil {
		dir := filepath.Dir(exe)
		arch := "x64"
		if runtime.GOARCH == "arm64" {
			arch = "arm64"
		} else if runtime.GOARCH == "386" {
			arch = "x86"
		}
		for _, n := range []string{"WebView2Loader-" + arch + ".dll", "WebView2Loader.dll"} {
			p := filepath.Join(dir, n)
			if st, e := os.Stat(p); e == nil && !st.IsDir() {
				return p
			}
		}
	}
	return "WebView2Loader.dll"
}

var (
	nativeModule                                       = windows.NewLazyDLL(loaderPath())
	nativeCreate                                       = nativeModule.NewProc("CreateCoreWebView2EnvironmentWithOptions")
	nativeCompareBrowserVersions                       = nativeModule.NewProc("CompareBrowserVersions")
	nativeGetAvailableCoreWebView2BrowserVersionString = nativeModule.NewProc("GetAvailableCoreWebView2BrowserVersionString")
)

func loadErr(err error) error {
	return fmt.Errorf("Unable to load WebView2Loader.dll (it should be beside the program): %w", err)
}

// CompareBrowserVersions will compare the 2 given versions and return:
//
//	-1 = v1 < v2
//	 0 = v1 == v2
//	 1 = v1 > v2
func CompareBrowserVersions(v1 string, v2 string) (int, error) {
	_v1, err := windows.UTF16PtrFromString(v1)
	if err != nil {
		return 0, err
	}
	_v2, err := windows.UTF16PtrFromString(v2)
	if err != nil {
		return 0, err
	}
	if e := nativeCompareBrowserVersions.Find(); e != nil {
		return 0, loadErr(e)
	}
	var result int
	_, _, err = nativeCompareBrowserVersions.Call(
		uintptr(unsafe.Pointer(_v1)),
		uintptr(unsafe.Pointer(_v2)),
		uintptr(unsafe.Pointer(&result)))
	if err != windows.ERROR_SUCCESS {
		return result, err
	}
	return result, nil
}

// GetInstalledVersion returns the installed version of the webview2 runtime.
// If there is no version installed, a blank string is returned.
func GetInstalledVersion() (string, error) {
	if e := nativeGetAvailableCoreWebView2BrowserVersionString.Find(); e != nil {
		return "", loadErr(e)
	}
	var result *uint16
	hr, _, _ := nativeGetAvailableCoreWebView2BrowserVersionString.Call(
		uintptr(unsafe.Pointer(nil)),
		uintptr(unsafe.Pointer(&result)))
	defer windows.CoTaskMemFree(unsafe.Pointer(result)) // Safe even if result is nil
	if hr != uintptr(windows.S_OK) {
		if hr&0xFFFF == uintptr(windows.ERROR_FILE_NOT_FOUND) {
			return "", nil // no runtime installed
		}
		return "", fmt.Errorf("GetAvailableCoreWebView2BrowserVersionString returned HRESULT 0x%X", hr)
	}
	return windows.UTF16PtrToString(result), nil
}

// CreateCoreWebView2EnvironmentWithOptions loads WebView2Loader and calls CreateCoreWebView2EnvironmentWithOptions.
func CreateCoreWebView2EnvironmentWithOptions(browserExecutableFolder, userDataFolder *uint16, environmentOptions uintptr, environmentCompletedHandle uintptr) (uintptr, error) {
	if e := nativeCreate.Find(); e != nil {
		return 0, loadErr(e)
	}
	res, _, _ := nativeCreate.Call(
		uintptr(unsafe.Pointer(browserExecutableFolder)),
		uintptr(unsafe.Pointer(userDataFolder)),
		environmentOptions,
		environmentCompletedHandle,
	)
	return res, nil
}
