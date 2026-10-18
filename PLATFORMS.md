# Reactio Draw: one feature, every platform

Reactio Draw ships as:
1. the web page (`index.html`)
2. the Mac app (`macapp/`: Swift window, built on the Mac by "Install Reactio Draw.command")
3. the Windows app (`windows-app/`: ReactioDraw.exe, Go + WebView2, OLE server for Word)
4. the Linux app (`linux-app/`: Go + GTK/WebKitGTK)
5. the Reactio Draw tab for Word (`word-addin/`: `Reactio Draw.dotm`, Windows and Mac)

Every feature goes into all versions unless a platform cannot support it.
