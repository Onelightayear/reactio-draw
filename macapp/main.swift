// Reactio Draw for Mac: its own window around the page (system WebKit), with native Save/Open panels
// and the clipboard for Word. Built on the Mac by "Install Reactio Draw.command" (swiftc from the Command Line Tools).
import Cocoa
import WebKit
import Network

let GV = NSPasteboard.PasteboardType("com.microsoft.Art--GVML-ClipFormat")

/* Command line: "ReactioDraw --cli <command> …" (the reactio script beside it in the app) runs the page without
   showing a window. The files named on the command line are read here and handed to the page with the arguments; the
   page answers with cliDone {out, err, code, writes}, and only the path after -o (or files inside that folder) is written. */
let cliArgs: [String]? = CommandLine.arguments.count > 1 && CommandLine.arguments[1] == "--cli" ? Array(CommandLine.arguments.dropFirst(2)) : nil
var cliOut = ""
func cliErr(_ s: String) { FileHandle.standardError.write(s.data(using: .utf8) ?? Data()) }
func cliScript(_ args: [String]) -> String {
    var files: [String: [String: String]] = [:], dirs: [String] = []
    let fm = FileManager.default
    var i = 0
    while i < args.count {
        let a = args[i]
        var isDir: ObjCBool = false
        if a == "-o" || a == "--output" {
            if i + 1 < args.count {
                let p = args[i + 1]
                cliOut = URL(fileURLWithPath: p).standardizedFileURL.path
                if fm.fileExists(atPath: p, isDirectory: &isDir), isDir.boolValue { dirs.append(p) }
            }
            i += 2; continue
        }
        if fm.fileExists(atPath: a, isDirectory: &isDir), !isDir.boolValue,
           let d = try? Data(contentsOf: URL(fileURLWithPath: a)), d.count < 64 << 20 {
            files[a] = ["name": (a as NSString).lastPathComponent, "b64": d.base64EncodedString()]
        }
        i += 1
    }
    let obj: [String: Any] = ["argv": args, "files": files, "dirs": dirs]
    let j = (try? JSONSerialization.data(withJSONObject: obj)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
    return "window.__rdCli=\(j);"
}
func cliDone(_ msg: String) -> Never {
    guard let d = msg.data(using: .utf8), let r = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any] else {
        cliErr("reactio: bad answer from the page\n"); cliExit(1)
    }
    var err = r["err"] as? String ?? ""
    var code = (r["code"] as? NSNumber)?.int32Value ?? 1
    let root = cliOut.hasSuffix("/") ? cliOut : cliOut + "/"
    for w in r["writes"] as? [[String: Any]] ?? [] {
        let path = w["path"] as? String ?? ""
        let p = URL(fileURLWithPath: path).standardizedFileURL.path
        if cliOut.isEmpty || !(p == cliOut || p.hasPrefix(root)) { err += "reactio: not written (outside -o): \(path)\n"; code = 1; continue }
        let data = Data(base64Encoded: w["b64"] as? String ?? "") ?? Data()
        try? FileManager.default.createDirectory(at: URL(fileURLWithPath: p).deletingLastPathComponent(), withIntermediateDirectories: true)
        do { try data.write(to: URL(fileURLWithPath: p)) } catch { err += "reactio: \(error.localizedDescription)\n"; code = 1 }
    }
    FileHandle.standardOutput.write((r["out"] as? String ?? "").data(using: .utf8) ?? Data())
    cliErr(err)
    cliExit(code)
}
func cliExit(_ code: Int32) -> Never { Opsin.shared.stop(); Namer.shared.stop(); exit(code) }

/* The page may write only to files the user chose: in a Save or Open panel, or opened from Finder. A path the page
   makes up is refused, so a document cannot make the app overwrite other files. The list is kept in the app's
   preferences, so a document restored after a restart can still be saved to its own file. */
func normPath(_ p: String) -> String { return URL(fileURLWithPath: p).standardizedFileURL.path.lowercased() }
func allowPath(_ p: String) {
    if p.isEmpty { return }
    let n = normPath(p)
    var list = UserDefaults.standard.stringArray(forKey: "rd.allowedPaths") ?? []
    list.removeAll { $0 == n }
    list.insert(n, at: 0)
    if list.count > 500 { list = Array(list.prefix(500)) }
    UserDefaults.standard.set(list, forKey: "rd.allowedPaths")
}
/* the page may add .reactio (or .json) to a name chosen in Save as when the extension is not one it saves */
func pathAllowed(_ p: String) -> Bool {
    let n = normPath(p)
    let list = UserDefaults.standard.stringArray(forKey: "rd.allowedPaths") ?? []
    return list.contains(n) || list.contains { $0 + ".json" == n || $0 + ".reactio" == n }
}

final class Bridge: NSObject, WKScriptMessageHandler, NSWindowDelegate {
    weak var web: WKWebView?
    var lastCC = NSPasteboard.general.changeCount

    func reply(_ id: String, _ obj: [String: Any]) {
        guard let d = try? JSONSerialization.data(withJSONObject: obj), let s = String(data: d, encoding: .utf8),
              let idj = try? JSONSerialization.data(withJSONObject: [id, s]), let args = String(data: idj, encoding: .utf8) else { return }
        // args is ["id","{...}"]
        web?.evaluateJavaScript("window.__rdReply.apply(null,\(args))", completionHandler: nil)
    }

    func userContentController(_ ucc: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let s = message.body as? String, let d = s.data(using: .utf8),
              let m = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any],
              let id = m["id"] as? String, let cmd = m["cmd"] as? String else { return }
        switch cmd {
        case "save":
            let p = NSSavePanel(); p.nameFieldStringValue = m["name"] as? String ?? "Reactio Draw"; p.canCreateDirectories = true
            if p.runModal() == .OK, let url = p.url, let b = m["b64"] as? String, let data = Data(base64Encoded: b) {
                do { try data.write(to: url); allowPath(url.path); reply(id, ["ok": true, "path": url.path]) } catch { reply(id, ["ok": false, "error": "\(error)"]) }
            } else { reply(id, ["ok": false]) }
        case "open":
            let o = NSOpenPanel(); o.allowsMultipleSelection = false; o.canChooseDirectories = false
            if o.runModal() == .OK, let url = o.url, let data = try? Data(contentsOf: url) {
                allowPath(url.path)
                reply(id, ["name": url.lastPathComponent, "path": url.path, "b64": data.base64EncodedString()])
            } else { reply(id, ["cancel": true]) }
        case "saveAs":
            // Save as: the panel only; the page then writes the file in the format the name asks for
            let p = NSSavePanel(); p.nameFieldStringValue = m["name"] as? String ?? "Reactio Draw.reactio"; p.canCreateDirectories = true
            p.allowsOtherFileTypes = true; p.isExtensionHidden = false
            let chosen = p.runModal() == .OK ? (p.url?.path ?? "") : ""
            allowPath(chosen)
            reply(id, ["path": chosen])
        case "write":
            guard let path = m["path"] as? String, !path.isEmpty, let d = Data(base64Encoded: m["b64"] as? String ?? "") else { reply(id, ["ok": false, "err": "no file"]); return }
            if !pathAllowed(path) { reply(id, ["ok": false, "ask": true]); return }
            do { try d.write(to: URL(fileURLWithPath: path), options: .atomic); reply(id, ["ok": true]) } catch { reply(id, ["ok": false, "err": "\(error.localizedDescription)"]) }
        case "link":
            // a link on the page (Credits, what is new) opens in the default browser; only web addresses
            if let s = m["url"] as? String, let u = URL(string: s), ["http", "https"].contains(u.scheme?.lowercased() ?? "") {
                NSWorkspace.shared.open(u); reply(id, ["ok": true])
            } else { reply(id, ["ok": false]) }
        case "quit":
            reply(id, ["ok": true]); Bridge.quitOK = true; NSApp.terminate(nil)
        case "wordReturn":
            // a drawing edited for Word (Reactio Draw tab in Word: Edit in Reactio Draw): its picture, its drawing tag and an SVG go to
            // the exchange folder Word can read (Office's group container), then Word is asked to run the tab's RD_Update macro,
            // which puts the new picture in place of the old one. The first time, macOS asks to let Reactio Draw control Word.
            let wid = m["wid"] as? String ?? ""
            guard wid.range(of: "^[A-Za-z0-9_-]{1,64}$", options: .regularExpression) != nil,
                  let png = Data(base64Encoded: m["png"] as? String ?? ""), !png.isEmpty else { reply(id, ["ok": false, "err": "no drawing"]); return }
            let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Group Containers/UBF8T346G9.Office/Reactio Draw", isDirectory: true)
            do {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                try png.write(to: dir.appendingPathComponent(wid + ".png"), options: .atomic)
                let svg = m["svg"] as? String ?? ""
                if !svg.isEmpty { try Data(svg.utf8).write(to: dir.appendingPathComponent(wid + ".svg"), options: .atomic) }
                try Data((m["tag"] as? String ?? "").utf8).write(to: dir.appendingPathComponent(wid + ".tag"), options: .atomic)
            } catch { reply(id, ["ok": false, "err": error.localizedDescription]); return }
            var err: NSDictionary?
            _ = NSAppleScript(source: "tell application \"Microsoft Word\" to run VB macro macro name \"RD_Update\"")?.executeAndReturnError(&err)
            reply(id, ["ok": true, "word": err == nil])
        case "clipgvml":
            guard let g = Data(base64Encoded: m["gvml"] as? String ?? ""), let png = Data(base64Encoded: m["png"] as? String ?? "") else { reply(id, ["ok": false]); return }
            let pb = NSPasteboard.general; pb.clearContents()
            let it = NSPasteboardItem(); it.setData(g, forType: GV); it.setData(png, forType: .png)
            // Ctrl+C also carries the CDXML text: chemistry editors and Reactio Draw paste structures from it
            if let t = m["text"] as? String, !t.isEmpty { it.setString(t, forType: .string) }
            let ok = pb.writeObjects([it]); lastCC = pb.changeCount; reply(id, ["ok": ok])
        case "clipown":
            // a Reactio Draw object copied in Word (made on Windows): Word on Mac puts the object's storage here
            if let d = NSPasteboard.general.data(forType: NSPasteboard.PasteboardType("com.microsoft.Embedded-Object")), !d.isEmpty {
                reply(id, ["b64": d.base64EncodedString()])
            } else if let c = Bridge.cdxData() {
                // copied in a chemistry editor: its binary drawing (CDX) or CDXML text, whatever type name it goes by
                reply(id, c)
            } else if let tag = Bridge.findTag(NSPasteboard.general.pasteboardItems ?? []) {
                // a Reactio Draw picture copied in Word or PowerPoint before the app was running
                reply(id, ["tag": tag])
            } else { reply(id, [:]) }
        case "apiStart":
            // the local API listens only after it is turned on in the page (Info tab), never by itself
            if let w = web { LocalAPI.shared.start(web: w) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { self.reply(id, ["ok": LocalAPI.shared.port > 0, "port": LocalAPI.shared.port]) }
        case "apiStop":
            LocalAPI.shared.stop(); reply(id, ["ok": true])
        case "cliDone":
            cliDone(m["msg"] as? String ?? "")
        case "apiResult":
            LocalAPI.shared.deliver(m["name"] as? String ?? "", m["msg"] as? String ?? "")
            reply(id, ["ok": true])
        case "iupac":
            let smi = m["name"] as? String ?? ""
            Namer.queue.async {
                let r = Namer.shared.name(for: smi)
                DispatchQueue.main.async { self.reply(id, r) }
            }
        case "opsin":
            // OPSIN may take a second to start: work off the main thread, answer on it
            let name = m["name"] as? String ?? ""
            Opsin.queue.async {
                let r = Opsin.shared.smiles(for: name)
                DispatchQueue.main.async { self.reply(id, r) }
            }
        default: reply(id, ["ok": false])
        }
    }

    /* a Reactio Draw picture copied in Word or PowerPoint: add its drawing as text, so Cmd+V in Reactio Draw restores it */
    @objc func watchClipboard() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastCC else { return }
        lastCC = pb.changeCount
        guard let items = pb.pasteboardItems, let it = items.first else { return }
        if let s = it.string(forType: .string), s.range(of: Bridge.tagRe, options: .regularExpression) != nil { return }
        guard let tag = Bridge.findTag(items) else { return }
        let ni = NSPasteboardItem()
        for t in it.types where t != .string { if let d = it.data(forType: t), !d.isEmpty { ni.setData(d, forType: t) } }
        ni.setString(tag, forType: .string)
        pb.clearContents(); pb.writeObjects([ni]); lastCC = pb.changeCount
    }

    /* the drawing tag (RDRAW1:...) wherever Office put it: the alt text in the drawing XML (Word), the PNG text chunk
       of the picture (PowerPoint drops alt text), inside zipped clipboard packages, in any pasteboard type */
    /* the tag that carries a Reactio Draw drawing inside a picture */
    static let tagRe = "RDRAW1:[A-Za-z0-9+/=]+"

    static func findTag(_ items: [NSPasteboardItem]) -> String? {
        let re = tagRe
        for it in items {
            for t in it.types {
                guard let d = it.data(forType: t), d.count > 20, d.count < 80_000_000 else { continue }
                var hay = String(decoding: d, as: UTF8.self)
                if hay.range(of: re, options: .regularExpression) == nil, d.prefix(2) == Data("PK".utf8) { hay = unzipped(d, "*") ?? "" }
                if let r = hay.range(of: re, options: .regularExpression) { return "Reactio Draw drawing " + hay[r] }
            }
        }
        return nil
    }

    /* Help > Clipboard Report: what the clipboard holds now (types, sizes, where a drawing tag was found), saved to Downloads */
    static func clipReport() -> URL? {
        let pb = NSPasteboard.general
        var lines = ["Reactio Draw clipboard report", "changeCount \(pb.changeCount)", ""]
        for (n, it) in (pb.pasteboardItems ?? []).enumerated() {
            lines.append("item \(n)")
            for t in it.types {
                let d = it.data(forType: t) ?? Data()
                var found = String(decoding: d, as: UTF8.self).range(of: tagRe, options: .regularExpression) != nil
                var note = ""
                if !found, d.prefix(2) == Data("PK".utf8) { found = (unzipped(d, "*") ?? "").range(of: tagRe, options: .regularExpression) != nil; note = " zip" }
                lines.append("  \(t.rawValue)  \(d.count) bytes\(note)\(found ? "  <- drawing tag found" : "")")
            }
        }
        let url = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0].appendingPathComponent("Reactio Draw clipboard report.txt")
        do { try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8) } catch { return nil }
        return url
    }

    static func cdxData() -> [String: Any]? {
        guard let it = NSPasteboard.general.pasteboardItems?.first else { return nil }
        for t in it.types {
            guard let d = it.data(forType: t), d.count > 30 else { continue }
            if d.prefix(8) == Data("VjCD0100".utf8) { return ["cdx": d.base64EncodedString()] }
        }
        for t in it.types where t.rawValue.lowercased().contains("cdx") {
            if let d = it.data(forType: t), let x = String(data: d, encoding: .utf8), x.contains("<CDXML") { return ["cdxml": x] }
        }
        return nil
    }

    static func drawingXML(_ zip: Data) -> String? { unzipped(zip, "clipboard/drawings/*.xml") }

    static func unzipped(_ zip: Data, _ pattern: String) -> String? {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("rd-gvml.zip")
        guard (try? zip.write(to: tmp)) != nil else { return nil }
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/unzip"); p.arguments = ["-p", tmp.path, pattern]
        let out = Pipe(); p.standardOutput = out; p.standardError = Pipe()
        do { try p.run() } catch { return nil }
        let d = out.fileHandleForReading.readDataToEndOfFile(); p.waitUntilExit()
        return String(decoding: d, as: UTF8.self)
    }

    /* closing the window or quitting asks the page first: documents with unsaved changes ask to be saved */
    static var quitOK = false
    func askQuit() { web?.evaluateJavaScript("window.__rdBeforeQuit?window.__rdBeforeQuit():window.webkit.messageHandlers.rd.postMessage(JSON.stringify({id:'x',cmd:'quit'}))", completionHandler: nil) }
    func windowShouldClose(_ sender: NSWindow) -> Bool { if Bridge.quitOK { return true }; askQuit(); return false }
    func windowWillClose(_ notification: Notification) { Opsin.shared.stop(); Namer.shared.stop(); LocalAPI.shared.stop(); NSApp.terminate(nil) }
}


/* Name → structure: OPSIN (MIT, https://github.com/dan2097/opsin), shipped unchanged in the app's Resources and run
   as a separate Java program that stays running and answers one SMILES line per name line */
final class Opsin {
    static let shared = Opsin()
    static let queue = DispatchQueue(label: "opsin")
    var proc: Process?
    var inH: FileHandle?
    var outH: FileHandle?
    var errBuf = Data()
    let errLock = NSLock()
    var outBuf = Data()

    func javaPath() -> String? {
        var c: [String] = []
        if let h = ProcessInfo.processInfo.environment["JAVA_HOME"] { c.append(h + "/bin/java") }
        // /usr/libexec/java_home knows the installed JDKs; plain /usr/bin/java is only a stub when none is installed
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/libexec/java_home")
        let o = Pipe(); p.standardOutput = o; p.standardError = Pipe()
        if (try? p.run()) != nil { p.waitUntilExit()
            if p.terminationStatus == 0 { let h = String(decoding: o.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines); if !h.isEmpty { c.append(h + "/bin/java") } } }
        c += ["/opt/homebrew/opt/openjdk/bin/java", "/usr/local/opt/openjdk/bin/java"]
        return c.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    func start() -> String? {
        guard let java = javaPath() else { return "nojava" }
        guard let jar = Bundle.main.path(forResource: "opsin", ofType: "jar") else { return "noopsin" }
        let p = Process(); p.executableURL = URL(fileURLWithPath: java); p.arguments = ["-jar", jar, "-osmi"]
        let i = Pipe(), o = Pipe(), e = Pipe(); p.standardInput = i; p.standardOutput = o; p.standardError = e
        e.fileHandleForReading.readabilityHandler = { [weak self] h in let d = h.availableData; guard let s = self else { return }; s.errLock.lock(); s.errBuf.append(d); if s.errBuf.count > 4000 { s.errBuf = s.errBuf.suffix(4000) }; s.errLock.unlock() }
        do { try p.run() } catch { return "nojava" }
        proc = p; inH = i.fileHandleForWriting; outH = o.fileHandleForReading; outBuf = Data()
        return nil
    }

    func stop() { proc?.terminate(); proc = nil }

    func readLine(timeout: TimeInterval) -> String? {
        let end = Date().addingTimeInterval(timeout)
        while Date() < end {
            if let r = outBuf.firstIndex(of: 10) { let line = outBuf[outBuf.startIndex..<r]; outBuf = outBuf[(r + 1)...]; return String(decoding: line, as: UTF8.self) }
            guard let h = outH, proc?.isRunning == true else { return nil }
            let d = h.availableData; if d.isEmpty { return nil }; outBuf.append(d)
        }
        return nil
    }

    func smiles(for raw: String) -> [String: Any] {
        let name = raw.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "\r", with: " ").trimmingCharacters(in: .whitespaces)
        if name.isEmpty { return ["err": "empty"] }
        for _ in 0..<2 {
            if proc == nil || proc?.isRunning != true { if let err = start() { return ["err": err] } }
            errLock.lock(); errBuf = Data(); errLock.unlock()
            inH?.write((name + "\n").data(using: .utf8)!)
            guard let line = readLine(timeout: 30) else { stop(); continue }
            let smi = line.trimmingCharacters(in: .whitespaces)
            if !smi.isEmpty { return ["smiles": smi] }
            Thread.sleep(forTimeInterval: 0.03)
            errLock.lock(); var msg = String(decoding: errBuf, as: UTF8.self); errLock.unlock()
            if let r = msg.range(of: "uninterpretable: ") { msg = String(msg[r.upperBound...]); if let t = msg.range(of: " The following") { msg = String(msg[..<t.lowerBound]) }; msg = "not understood: " + msg.trimmingCharacters(in: .whitespacesAndNewlines) }
            return ["err": "unparsable", "msg": msg.trimmingCharacters(in: .whitespacesAndNewlines)]
        }
        return ["err": "nojava"]
    }
}


/* Structure → name: openclatura (MIT, https://github.com/lamalab-org/openclatura) in the Mac's own Python, unchanged, through
   reactio_name.py (in the app's Resources): it stays running, one SMILES line in, one JSON line out */
final class Namer {
    static let shared = Namer()
    static let queue = DispatchQueue(label: "namer")
    var proc: Process?
    var inH: FileHandle?
    var outH: FileHandle?
    var outBuf = Data()

    func candidates() -> [String] {
        let home = NSHomeDirectory()
        var c: [String] = []
        if let p = ProcessInfo.processInfo.environment["REACTIO_PYTHON"] { c.append(p) }
        /* a Python made just for Reactio Draw (see README: python3 -m venv ~/.reactio-python) */
        c.append(home + "/.reactio-python/bin/python3")
        /* the Python the user's own terminal finds (a Mac app does not get the terminal's PATH) */
        let sh = Process(); sh.executableURL = URL(fileURLWithPath: "/bin/zsh")
        sh.arguments = ["-lic", "for n in python3.14 python3.13 python3.12 python3.11 python3; do whence -ap $n; done 2>/dev/null; for q in $(whence -ap pip3 pip 2>/dev/null); do head -1 \"$q\" 2>/dev/null; echo; done"]
        let so = Pipe(); sh.standardOutput = so; sh.standardError = FileHandle.nullDevice; sh.standardInput = FileHandle.nullDevice
        if (try? sh.run()) != nil {
            let t = Date().addingTimeInterval(8); while sh.isRunning && Date() < t { usleep(50000) }
            if sh.isRunning { sh.terminate() }
            let out = String(decoding: so.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            for l in out.split(separator: "\n") { let x = l.trimmingCharacters(in: .whitespaces); if x.hasPrefix("/") { c.append(x) } else if x.hasPrefix("#!/") { let i = String(x.dropFirst(2)).split(separator: " ").first.map(String.init) ?? ""; if !i.hasSuffix("/env") { c.append(i) } } }
        }
        for b in ["/opt/homebrew/bin", "/usr/local/bin"] { for n in ["python3.14", "python3.13", "python3.12", "python3.11", "python3"] { c.append(b + "/" + n) } }
        let pyenv = home + "/.pyenv/versions"
        if let vs = try? FileManager.default.contentsOfDirectory(atPath: pyenv) { for v in vs.sorted(by: >) { c.append(pyenv + "/" + v + "/bin/python3") } }
        for v in ["3.14", "3.13", "3.12", "3.11"] { c.append("/Library/Frameworks/Python.framework/Versions/\(v)/bin/python3") }
        for d in ["miniconda3", "anaconda3", "miniforge3", "mambaforge", "opt/anaconda3", ".pyenv/shims"] { c.append(home + "/" + d + (d.hasSuffix("shims") ? "/python3" : "/bin/python3")) }
        c.append("/usr/bin/python3")
        var seen = Set<String>()
        return c.filter { FileManager.default.isExecutableFile(atPath: $0) && seen.insert(URL(fileURLWithPath: $0).resolvingSymlinksInPath().path).inserted }
    }

    func readLine(timeout: TimeInterval) -> String? {
        let end = Date().addingTimeInterval(timeout)
        while Date() < end {
            if let r = outBuf.firstIndex(of: 10) { let line = outBuf[outBuf.startIndex..<r]; outBuf = outBuf[(r + 1)...]; return String(decoding: line, as: UTF8.self) }
            guard let h = outH, proc?.isRunning == true else { return nil }
            let d = h.availableData; if d.isEmpty { return nil }; outBuf.append(d)
        }
        return nil
    }

    func start() -> [String: Any]? {
        guard let script = Bundle.main.path(forResource: "reactio_name", ofType: "py") else { return ["err": "nopython", "msg": "reactio_name.py is missing"] }
        var last = "no Python 3 found"; var tried: [String] = []
        for py in candidates() {
            let p = Process(); p.executableURL = URL(fileURLWithPath: py); p.arguments = ["-u", script]
            var env = ProcessInfo.processInfo.environment; env["PYTHONIOENCODING"] = "utf-8"; p.environment = env
            let i = Pipe(), o = Pipe(); p.standardInput = i; p.standardOutput = o; p.standardError = FileHandle.nullDevice
            do { try p.run() } catch { continue }
            proc = p; inH = i.fileHandleForWriting; outH = o.fileHandleForReading; outBuf = Data()
            if let first = readLine(timeout: 90), let d = first.data(using: .utf8), let m = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any] {
                if m["ready"] != nil { return nil }
                if let s = m["msg"] as? String { tried.append(py + " (" + s + ")") }
            } else { tried.append(py + " (did not start)") }
            p.terminate(); proc = nil
        }
        if !tried.isEmpty { last = "tried " + tried.joined(separator: "; ") }
        return ["err": "nopython", "msg": last]
    }

    func stop() { proc?.terminate(); proc = nil }

    func name(for raw: String) -> [String: Any] {
        let smi = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if smi.isEmpty { return ["err": "empty"] }
        for _ in 0..<2 {
            if proc == nil || proc?.isRunning != true { if let e = start() { return e } }
            inH?.write((smi + "\n").data(using: .utf8)!)
            guard let line = readLine(timeout: 60), let d = line.data(using: .utf8),
                  let m = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any] else { stop(); continue }
            if let n = m["name"] as? String, !n.isEmpty { return ["name": n] }
            return ["err": "noname", "msg": m["msg"] as? String ?? ""]
        }
        return ["err": "nopython"]
    }
}


/* Local API: scripts on this Mac send commands over HTTP on 127.0.0.1 only.
   POST http://127.0.0.1:<port>/api, header X-Reactio-Token, JSON body {"op":"calc","args":{"smiles":"CCO"}}.
   Port and token are in ~/Library/Application Support/ReactioDraw/api.json while the app runs. */
final class LocalAPI {
    static let shared = LocalAPI()
    var listener: NWListener?
    var token = ""
    weak var web: WKWebView?
    var waits: [String: NWConnection] = [:]
    var seq = 0
    var infoURL: URL { FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("ReactioDraw/api.json") }

    var port = 0
    func start(web: WKWebView) {
        self.web = web
        if listener != nil { return }
        token = (0..<16).map { _ in String(format: "%02x", UInt8.random(in: 0...255)) }.joined()
        tryPort(47615)
    }

    func tryPort(_ p: UInt16) {
        guard p < 47630, let port = NWEndpoint.Port(rawValue: p) else { return }
        let params = NWParameters.tcp
        params.requiredLocalEndpoint = NWEndpoint.hostPort(host: "127.0.0.1", port: port)
        params.allowLocalEndpointReuse = false
        guard let l = try? NWListener(using: params) else { tryPort(p + 1); return }
        l.stateUpdateHandler = { [weak self] st in
            guard let self = self else { return }
            switch st {
            case .ready:
                self.port = Int(p)
                let info: [String: Any] = ["port": Int(p), "token": self.token, "url": "http://127.0.0.1:\(p)/api", "pid": Int(ProcessInfo.processInfo.processIdentifier)]
                try? FileManager.default.createDirectory(at: self.infoURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                if let d = try? JSONSerialization.data(withJSONObject: info) { try? d.write(to: self.infoURL); try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: self.infoURL.path) }
            case .failed(_):
                l.cancel(); DispatchQueue.main.async { self.tryPort(p + 1) }
            default: break
            }
        }
        l.newConnectionHandler = { [weak self] c in self?.accept(c) }
        l.start(queue: .main)
        listener = l
    }

    func stop() { listener?.cancel(); listener = nil; port = 0; try? FileManager.default.removeItem(at: infoURL) }

    func accept(_ c: NWConnection) {
        c.start(queue: .main)
        read(c, Data())
    }

    func read(_ c: NWConnection, _ buf: Data) {
        c.receive(minimumIncompleteLength: 1, maximumLength: 1 << 20) { [weak self] data, _, done, err in
            guard let self = self else { return }
            var b = buf; if let d = data { b.append(d) }
            if let r = b.range(of: Data("\r\n\r\n".utf8)) {
                let head = String(decoding: b[b.startIndex..<r.lowerBound], as: UTF8.self)
                var len = 0, tok = "", origin = "", host = ""
                let lines = head.components(separatedBy: "\r\n")
                for line in lines.dropFirst() {
                    let kv = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
                    if kv.count == 2 {
                        switch kv[0].lowercased() {
                        case "content-length": len = Int(kv[1]) ?? 0
                        case "x-reactio-token": tok = kv[1]
                        case "origin": origin = kv[1]
                        case "host": host = kv[1]
                        default: break
                        }
                    }
                }
                // only scripts on this computer: a browser request for a web page carries an Origin header, and the Host
                // must be this address (a site that points its own name at 127.0.0.1 is turned away too); at most 8 MB
                if !origin.isEmpty || (host != "127.0.0.1:\(self.port)" && host != "localhost:\(self.port)") || len > 8 << 20 {
                    self.send(c, "403 Forbidden", "{\"ok\":false,\"error\":\"the local API answers scripts on this computer only (no browser requests)\"}"); return
                }
                let body = b[r.upperBound...]
                if body.count >= len || done || err != nil {
                    self.handle(c, method: lines.first?.components(separatedBy: " ").first ?? "", token: tok, body: Data(body.prefix(len)))
                    return
                }
            } else if done || err != nil || b.count > 64 << 10 { c.cancel(); return }
            self.read(c, b)
        }
    }

    /* compared in constant time, so the answer time says nothing about how much of a guess was right */
    func sameToken(_ a: String, _ b: String) -> Bool {
        let x = Array(a.utf8), y = Array(b.utf8)
        if x.count != y.count { return false }
        var d: UInt8 = 0
        for i in 0..<x.count { d |= x[i] ^ y[i] }
        return d == 0
    }

    func send(_ c: NWConnection, _ status: String, _ json: String) {
        let body = Data(json.utf8)
        var h = "HTTP/1.1 \(status)\r\nContent-Type: application/json\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n"
        var d = Data(h.utf8); d.append(body); h = ""
        c.send(content: d, completion: .contentProcessed { _ in c.cancel() })
    }

    func handle(_ c: NWConnection, method: String, token tok: String, body: Data) {
        if !sameToken(tok, token) { send(c, "403 Forbidden", "{\"ok\":false,\"error\":\"wrong or missing X-Reactio-Token (see api.json)\"}"); return }
        var op = "help", args = "{}"
        if method == "POST" {
            guard let m = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any], let o = m["op"] as? String else {
                send(c, "400 Bad Request", "{\"ok\":false,\"error\":\"send JSON like {\\\"op\\\":\\\"calc\\\",\\\"args\\\":{\\\"smiles\\\":\\\"CCO\\\"}}\"}"); return }
            op = o
            if let a = m["args"], let d = try? JSONSerialization.data(withJSONObject: a, options: [.fragmentsAllowed]) { args = String(decoding: d, as: UTF8.self) }
        }
        seq += 1; let id = "api\(seq)"; waits[id] = c
        guard let opj = try? JSONSerialization.data(withJSONObject: [id, op]), let pair = String(data: opj, encoding: .utf8) else { send(c, "500 Internal Server Error", "{\"ok\":false}"); return }
        // pair is ["id","op"]; the page gets (id, op, args)
        let js = "(function(p){window.__rdApiCall&&window.__rdApiCall(p[0],p[1],\(args));})(\(pair))"
        web?.evaluateJavaScript(js, completionHandler: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 180) { [weak self] in
            if let w = self?.waits.removeValue(forKey: id) { self?.send(w, "504 Gateway Timeout", "{\"ok\":false,\"error\":\"timed out\"}") }
        }
    }

    func deliver(_ id: String, _ out: String) {
        if let c = waits.removeValue(forKey: id) { send(c, "200 OK", out) }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, WKNavigationDelegate {
    var window: NSWindow!
    var web: WKWebView!
    let bridge = Bridge()
    var timer: Timer?

    func applicationDidFinishLaunching(_ n: Notification) {
        if let args = cliArgs { startCli(args); return }
        buildMenu()
        let cfg = WKWebViewConfiguration()
        cfg.userContentController.add(bridge, name: "rd")
        cfg.preferences.setValue(true, forKey: "developerExtrasEnabled")
        let rect = NSRect(x: 0, y: 0, width: 1440, height: 920)
        web = WKWebView(frame: rect, configuration: cfg); web.autoresizingMask = [.width, .height]
        web.navigationDelegate = self
        bridge.web = web
        window = NSWindow(contentRect: rect, styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "Reactio Draw"; window.minSize = NSSize(width: 800, height: 560); window.contentView = web; window.delegate = bridge
        window.isReleasedWhenClosed = false
        if let url = Bundle.main.url(forResource: "index", withExtension: "html"), let html = try? String(contentsOf: url, encoding: .utf8) {
            web.loadHTMLString(html, baseURL: URL(string: "https://app.reactiodraw.local/"))
        }
        window.center(); window.setFrameAutosaveName("ReactioDrawMain"); window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        timer = Timer.scheduledTimer(timeInterval: 0.5, target: bridge, selector: #selector(Bridge.watchClipboard), userInfo: nil, repeats: true)
    }

    /* the command line: the page in a window nobody sees (transparent, ignores the mouse, not in the Dock) */
    func startCli(_ args: [String]) {
        let cfg = WKWebViewConfiguration()
        cfg.userContentController.add(bridge, name: "rd")
        cfg.userContentController.addUserScript(WKUserScript(source: cliScript(args), injectionTime: .atDocumentStart, forMainFrameOnly: true))
        let rect = NSRect(x: 0, y: 0, width: 1200, height: 800)
        web = WKWebView(frame: rect, configuration: cfg)
        bridge.web = web
        window = NSWindow(contentRect: rect, styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = web; window.alphaValue = 0; window.ignoresMouseEvents = true; window.isReleasedWhenClosed = false
        window.collectionBehavior = [.transient, .ignoresCycle]
        window.orderBack(nil)
        guard let url = Bundle.main.url(forResource: "index", withExtension: "html"), let html = try? String(contentsOf: url, encoding: .utf8) else {
            cliErr("reactio: index.html is missing from the app\n"); exit(1)
        }
        web.loadHTMLString(html, baseURL: URL(string: "https://app.reactiodraw.local/?embed&cli"))
        DispatchQueue.main.asyncAfter(deadline: .now() + 600) { cliErr("reactio: no answer after 10 minutes\n"); cliExit(1) }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ s: NSApplication) -> Bool { true }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if Bridge.quitOK || !loaded { return .terminateNow }
        bridge.askQuit(); return .terminateCancel
    }

    /* files opened from Finder (double-click, Open With, dropped on the Dock icon): handed to the page once it has loaded */
    var pending: [URL] = []
    var loaded = false
    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        if cliArgs != nil { sender.reply(toOpenOrPrint: .success); return } // the command line reads its own files
        pending += filenames.map { URL(fileURLWithPath: $0) }
        flushFiles()
        sender.reply(toOpenOrPrint: .success)
    }
    func webView(_ w: WKWebView, didFinish navigation: WKNavigation!) { loaded = true; flushFiles() }
    func flushFiles() {
        guard loaded, let web = web else { return }
        let list = pending; pending = []
        for url in list {
            guard let d = try? Data(contentsOf: url), d.count < 64 << 20,
                  let j = try? JSONSerialization.data(withJSONObject: [url.lastPathComponent, d.base64EncodedString(), url.path]),
                  let a = String(data: j, encoding: .utf8) else { continue }
            allowPath(url.path)
            web.evaluateJavaScript("window.__rdOpenFile&&window.__rdOpenFile.apply(null,\(a))", completionHandler: nil)
        }
        if !list.isEmpty { window?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
    }

    func buildMenu() {
        let bar = NSMenu()
        let appItem = NSMenuItem(); let am = NSMenu(title: "Reactio Draw")
        am.addItem(withTitle: "Hide Reactio Draw", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        am.addItem(.separator())
        am.addItem(withTitle: "Quit Reactio Draw", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = am; bar.addItem(appItem)
        let editItem = NSMenuItem(); let em = NSMenu(title: "Edit")
        em.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        em.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        em.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        em.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = em; bar.addItem(editItem)
        let winItem = NSMenuItem(); let wm = NSMenu(title: "Window")
        wm.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        wm.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        winItem.submenu = wm; bar.addItem(winItem)
        let helpItem = NSMenuItem(); let hm = NSMenu(title: "Help")
        hm.addItem(withTitle: "Clipboard Report (saved to Downloads)", action: #selector(AppDelegate.clipReport(_:)), keyEquivalent: "")
        helpItem.submenu = hm; bar.addItem(helpItem)
        NSApp.mainMenu = bar
    }

    @objc func clipReport(_ sender: Any?) {
        if let u = Bridge.clipReport() { NSWorkspace.shared.open(u) }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(cliArgs == nil ? .regular : .accessory)
app.run()
