// Screenshot a URL with the system WebKit (no browser download needed).
// Usage: swift scripts/shot.swift <url> <out.png> [width=1440] [height=900] [waitSeconds=2.5] [fullPage=1]
import AppKit
import WebKit

let args = CommandLine.arguments
guard args.count >= 3 else {
    FileHandle.standardError.write("usage: shot.swift <url> <out.png> [width] [height] [wait] [fullPage]\n".data(using: .utf8)!)
    exit(2)
}
let url = URL(string: args[1])!
let out = URL(fileURLWithPath: args[2])
let width = args.count > 3 ? Double(args[3]) ?? 1440 : 1440
let height = args.count > 4 ? Double(args[4]) ?? 900 : 900
let wait = args.count > 5 ? Double(args[5]) ?? 2.5 : 2.5
let fullPage = args.count > 6 ? args[6] != "0" : true

final class Shooter: NSObject, WKNavigationDelegate {
    let web: WKWebView
    let window: NSWindow
    init(width: Double, height: Double) {
        let config = WKWebViewConfiguration()
        web = WKWebView(frame: NSRect(x: 0, y: 0, width: width, height: height), configuration: config)
        window = NSWindow(contentRect: web.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = web
        window.setFrameOrigin(NSPoint(x: -20000, y: -20000))
        window.orderFrontRegardless()
        super.init()
        web.navigationDelegate = self
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.asyncAfter(deadline: .now() + wait) { self.capture() }
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { fail(error) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { fail(error) }
    func fail(_ e: Error) { FileHandle.standardError.write("load failed: \(e)\n".data(using: .utf8)!); exit(1) }
    func capture() {
        web.evaluateJavaScript("Math.max(document.documentElement.scrollHeight, document.body.scrollHeight)") { result, _ in
            let h = fullPage ? min((result as? Double) ?? height, 16000) : height
            self.web.setFrameSize(NSSize(width: width, height: h))
            self.window.setContentSize(NSSize(width: width, height: h))
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                let cfg = WKSnapshotConfiguration()
                cfg.rect = NSRect(x: 0, y: 0, width: width, height: h)
                self.web.takeSnapshot(with: cfg) { image, error in
                    guard let image, let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
                          let png = rep.representation(using: .png, properties: [:]) else {
                        FileHandle.standardError.write("snapshot failed: \(String(describing: error))\n".data(using: .utf8)!)
                        exit(1)
                    }
                    try? png.write(to: out)
                    print("wrote \(out.path) \(Int(width))x\(Int(h))")
                    exit(0)
                }
            }
        }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
let shooter = Shooter(width: width, height: height)
shooter.web.load(URLRequest(url: url))
DispatchQueue.main.asyncAfter(deadline: .now() + 60) { FileHandle.standardError.write("timeout\n".data(using: .utf8)!); exit(1) }
app.run()
