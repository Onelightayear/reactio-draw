// reactio.exe: the command line of Reactio Draw (reactio --help). ReactioDraw.exe is a window program, which a console
// does not wait for; this small console program starts it beside itself with --cli, passes its answer through and
// returns its exit code.
package main

import (
	"errors"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

func main() {
	exe, err := os.Executable()
	if err == nil {
		if e, err2 := filepath.EvalSymlinks(exe); err2 == nil {
			exe = e
		}
	}
	dir := filepath.Dir(exe)
	prog := ""
	for _, n := range []string{"ReactioDraw.exe", "ReactioDraw-ARM.exe"} {
		if st, err := os.Stat(filepath.Join(dir, n)); err == nil && !st.IsDir() {
			prog = filepath.Join(dir, n)
			break
		}
	}
	if prog == "" {
		os.Stderr.WriteString("reactio: ReactioDraw.exe is not in " + dir + " (keep reactio.exe in the Reactio Draw folder)\n")
		os.Exit(1)
	}
	// cmd and PowerShell leave *.mol as it is: expand it here, as a Unix shell would
	args := []string{"--cli"}
	for _, a := range os.Args[1:] {
		if strings.ContainsAny(a, "*?") {
			if m, _ := filepath.Glob(a); len(m) > 0 {
				args = append(args, m...)
				continue
			}
		}
		args = append(args, a)
	}
	c := exec.Command(prog, args...)
	// pipes rather than the console itself: a window program writes to them reliably
	c.Stdout = struct{ io.Writer }{os.Stdout}
	c.Stderr = struct{ io.Writer }{os.Stderr}
	if err := c.Run(); err != nil {
		var x *exec.ExitError
		if errors.As(err, &x) {
			os.Exit(x.ExitCode())
		}
		os.Stderr.WriteString("reactio: " + err.Error() + "\n")
		os.Exit(1)
	}
}
