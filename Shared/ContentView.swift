//
//  ContentView.swift
//  LiamRank
//
//  Created by Liam on 11/18/20.
//

import SwiftUI
import WebKit
import Swifter
import GCDWebServer
import ZIPFoundation

struct ContentView: View {
    var body: some View {
        Webview(url: URL(string: "http://127.0.0.1/index.html")!)
    }
}

struct Webview: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> WebviewController {
        let webviewController = WebviewController()
        
        let server = GCDWebServer()
        
        let docURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dirURL = docURL.appendingPathComponent("LiamRank-master")
        let url = URL(string: "https://github.com/mail929/LiamRank/archive/master.zip")!
        
        let downloadTask = URLSession.shared.downloadTask(with: url) {
            urlOrNil, responseOrNil, errorOrNil in
            
            guard let fileURL = urlOrNil else { return }
            do {
                let fileManager = FileManager()
                if (fileManager.fileExists(atPath: dirURL.absoluteString)) {
                    try fileManager.removeItem(at: dirURL)
                }
                try fileManager.unzipItem(at: fileURL, to: docURL)
                print("Unzipped file")
            } catch {
                print ("Error unzipping: \(error)")
            }
            
            //let files = FileManager.default.contentsOfDirectory(at: dirURL, includingPropertiesForKeys: nil)
            //var output = ""
            //for file in files {
            //    output += file.absoluteString + "\n"
            //}
            server.addDefaultHandler(forMethod: "GET", request: GCDWebServerRequest.self, processBlock: { request in
                var file_text = "File not found"
                var path = request.path
                path = path.replacingOccurrences(of: "/config/", with: "/assets/")
                do {
                    file_text = try String(contentsOf: dirURL.appendingPathComponent(path))
                }
                catch {
                    print("Unable to read file")
                }
                return GCDWebServerDataResponse(html: file_text)
            })
            server.start(withPort: 80, bonjourName: "LiamRank iOS")
            
            let request = URLRequest(url: self.url, cachePolicy: .returnCacheDataElseLoad)
            webviewController.webview.load(request)
        }
        downloadTask.resume()
        
        return webviewController
    }
    
    func updateUIViewController(_ webviewController: WebviewController, context: Context) {
        let request = URLRequest(url: self.url, cachePolicy: .returnCacheDataElseLoad)
        webviewController.webview.load(request)
    }
}

class WebviewController: UIViewController {
    lazy var webview: WKWebView = WKWebView()
    lazy var progressbar: UIProgressView = UIProgressView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.webview.evaluateJavaScript("navigator.userAgent")
        self.webview.frame = self.view.frame
        self.view.addSubview(self.webview)
    }
}
