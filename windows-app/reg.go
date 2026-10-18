package main

// Per-user registration (HKEY_CURRENT_USER\Software\Classes): no administrator rights needed.
// Keys as described in the COM/OLE documentation:
// https://learn.microsoft.com/windows/win32/com/clsid-key-hklm

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"

	"golang.org/x/sys/windows"
	"golang.org/x/sys/windows/registry"
)

func clsidString() string {
	return strings.ToUpper(CLSID_RD.String())
}

func setKey(path string, vals map[string]string) {
	k, _, err := registry.CreateKey(registry.CURRENT_USER, `Software\Classes\`+path, registry.ALL_ACCESS)
	if err != nil {
		logf("registry %s: %v", path, err)
		return
	}
	defer k.Close()
	for n, v := range vals {
		k.SetStringValue(n, v)
	}
}

func register(exe string) {
	c := `CLSID\` + clsidString()
	setKey(c, map[string]string{"": userType})
	setKey(c+`\LocalServer32`, map[string]string{"": `"` + exe + `"`})
	setKey(c+`\InprocHandler32`, map[string]string{"": "ole32.dll"})
	setKey(c+`\ProgID`, map[string]string{"": progID})
	setKey(c+`\VersionIndependentProgID`, map[string]string{"": "ReactioDraw.Drawing"})
	setKey(c+`\Insertable`, nil)
	setKey(c+`\DefaultIcon`, map[string]string{"": exe + ",0"})
	setKey(c+`\AuxUserType\2`, map[string]string{"": appName})
	setKey(c+`\AuxUserType\3`, map[string]string{"": appName})
	setKey(c+`\MiscStatus`, map[string]string{"": "0"})
	setKey(c+`\Verb\0`, map[string]string{"": "&Edit,0,2"})
	setKey(c+`\Verb\1`, map[string]string{"": "&Open,0,2"})
	// formats the object gives its container (cf, aspect, tymed, direction)
	setKey(c+`\DataFormats\GetSet\0`, map[string]string{"": "14,1,64,1"})
	setKey(c+`\DataFormats\GetSet\1`, map[string]string{"": "8,1,1,1"})
	deleteTree(`Software\Classes\` + c + `\DataFormats\GetSet\2`)
	setKey(c+`\DataFormats\DefaultFile`, map[string]string{"": "Embed Source"})
	for _, p := range []string{progID, "ReactioDraw.Drawing"} {
		setKey(p, map[string]string{"": userType})
		setKey(p+`\CLSID`, map[string]string{"": clsidString()})
		setKey(p+`\Insertable`, nil)
	}
	setKey(`ReactioDraw.Drawing\CurVer`, map[string]string{"": progID})
	registerFiles(exe)
}

func unregister() {
	for _, p := range []string{`CLSID\` + clsidString(), progID, "ReactioDraw.Drawing", fileProgID} {
		deleteTree(`Software\Classes\` + p)
	}
	exe, _ := os.Executable()
	deleteTree(`Software\Classes\Applications\` + filepath.Base(exe))
	deleteTree(`Software\Classes\.reactio`)
	uninstallWordTab()
	for _, e := range fileExts {
		if k, err := registry.OpenKey(registry.CURRENT_USER, `Software\Classes\`+e+`\OpenWithProgids`, registry.SET_VALUE); err == nil {
			k.DeleteValue(fileProgID)
			k.Close()
		}
	}
	pSHChangeNotify.Call(0x08000000, 0, 0, 0)
}

// Files: Reactio Draw is offered in Explorer's "Open with" for these extensions, so it can be made the default app
// (Open with → Choose another app → Always). It takes over only its own extension, .reactio.
// Keys as described in https://learn.microsoft.com/windows/win32/shell/fa-progids and
// https://learn.microsoft.com/windows/win32/shell/app-registration
const fileProgID = "ReactioDraw.File"

var fileExts = []string{".reactio", ".cdxml", ".cdx", ".json", ".mol", ".rxn", ".sdf", ".smi"}

var pSHChangeNotify = windows.NewLazySystemDLL("shell32.dll").NewProc("SHChangeNotify")

func registerFiles(exe string) {
	open := `"` + exe + `" "%1"`
	setKey(fileProgID, map[string]string{"": "Reactio Draw document", "FriendlyTypeName": "Reactio Draw document"})
	setKey(fileProgID+`\DefaultIcon`, map[string]string{"": exe + ",0"})
	setKey(fileProgID+`\shell\open\command`, map[string]string{"": open})
	app := `Applications\` + filepath.Base(exe)
	setKey(app, map[string]string{"FriendlyAppName": appName})
	setKey(app+`\DefaultIcon`, map[string]string{"": exe + ",0"})
	setKey(app+`\shell\open\command`, map[string]string{"": open})
	for _, e := range fileExts {
		setKey(e+`\OpenWithProgids`, map[string]string{fileProgID: ""})
		setKey(app+`\SupportedTypes`, map[string]string{e: ""})
	}
	// .reactio is Reactio Draw's own document: it opens in Reactio Draw on double-click
	setKey(".reactio", map[string]string{"": fileProgID, "Content Type": "application/x-reactio+json", "PerceivedType": "document"})
	pSHChangeNotify.Call(0x08000000, 0, 0, 0) // SHCNE_ASSOCCHANGED
}

func deleteTree(path string) {
	k, err := registry.OpenKey(registry.CURRENT_USER, path, registry.ALL_ACCESS)
	if err != nil {
		return
	}
	names, _ := k.ReadSubKeyNames(-1)
	k.Close()
	for _, n := range names {
		deleteTree(path + `\` + n)
	}
	registry.DeleteKey(registry.CURRENT_USER, path)
}

var _ = windows.GUID{}

// hasReactioExt: .reactio already opens in Reactio Draw (installs from before .reactio register it once at start)
func hasReactioExt() bool {
	k, err := registry.OpenKey(registry.CURRENT_USER, `Software\Classes\.reactio`, registry.QUERY_VALUE)
	if err != nil {
		return false
	}
	defer k.Close()
	v, _, err := k.GetStringValue("")
	return err == nil && v == fileProgID
}

// registeredAs: this exe is already the registered server (then nothing is written at start)
func registeredAs(exe string) bool {
	k, err := registry.OpenKey(registry.CURRENT_USER, `Software\Classes\CLSID\`+clsidString()+`\LocalServer32`, registry.QUERY_VALUE)
	if err != nil {
		return false
	}
	defer k.Close()
	v, _, err := k.GetStringValue("")
	return err == nil && strings.EqualFold(v, `"`+exe+`"`)
}

// The Reactio Draw tab in Word: "Reactio Draw.dotm" (beside the program) goes into Word's Startup folder, where Word
// loads it as an add-in on start, and the program's folder goes where the tab's macros read it (VBA's GetSetting).
// Checked at every start: cheap, and it follows the program when it moves or is updated.
const vbaSettings = `Software\VB and VBA Program Settings\ReactioDraw\App`

func wordTabPath() string {
	d := os.Getenv("APPDATA")
	if d == "" {
		return ""
	}
	return filepath.Join(d, "Microsoft", "Word", "STARTUP", "Reactio Draw.dotm")
}

func installWordTab(exe string) {
	dir := filepath.Dir(exe)
	if k, _, err := registry.CreateKey(registry.CURRENT_USER, vbaSettings, registry.ALL_ACCESS); err == nil {
		if v, _, e := k.GetStringValue("Folder"); e != nil || v != dir {
			k.SetStringValue("Folder", dir)
		}
		if v, _, e := k.GetStringValue("Exe"); e != nil || v != exe {
			k.SetStringValue("Exe", exe)
		}
		k.Close()
	}
	src, err := os.ReadFile(filepath.Join(dir, "Reactio Draw.dotm"))
	dst := wordTabPath()
	if err != nil || dst == "" {
		return
	}
	if cur, e := os.ReadFile(dst); e == nil && bytes.Equal(cur, src) {
		return
	}
	os.MkdirAll(filepath.Dir(dst), 0o755)
	if e := os.WriteFile(dst, src, 0o644); e != nil {
		logf("word tab: %v", e) // Word keeps it open while it runs: the next start puts it there
	}
}

func uninstallWordTab() {
	if p := wordTabPath(); p != "" {
		os.Remove(p)
	}
	deleteTree(`Software\VB and VBA Program Settings\ReactioDraw`)
}
