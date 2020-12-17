//
//  WebView.swift
//  LiamRank (iOS)
//
//  Created by Liam on 11/28/20.
//

import SwiftUI
import WebKit
import UniformTypeIdentifiers

struct Webview: UIViewControllerRepresentable {
    let webviewController = WebviewController()
    let url: URL
    
    func makeUIViewController(context: Context) -> WebviewController {
        return webviewController
    }
    
    func updateUIViewController(_ webviewController: WebviewController, context: Context) {
        //loadPage()
    }
    
    func loadPage() {
        print("[VIEW] Reloading web app")
        let request = URLRequest(url: self.url, cachePolicy: .returnCacheDataElseLoad)
        webviewController.webview.load(request)
    }
}

class WebviewController: UIViewController {
    lazy var webview: WKWebView = WKWebView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        clean()
        
        self.webview.evaluateJavaScript("navigator.userAgent")
        self.webview.allowsBackForwardNavigationGestures = true
        self.webview.frame = self.view.frame
        self.webview.navigationDelegate = self
        // cutoff fix on index pages, not selection however
        self.webview.scrollView.contentInset = UIEdgeInsets.init(top: 0.0, left: 0.0, bottom: 100.0, right: 0.0)
        self.view.addSubview(self.webview)
    }
    
    // wipe cache
    func clean() {
        let websiteDataTypes = NSSet(array: [WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache])
        let date = Date(timeIntervalSince1970: 0)
        WKWebsiteDataStore.default().removeData(ofTypes: websiteDataTypes as! Set<String>, modifiedSince: date, completionHandler:{ })
    }
}

extension WebviewController: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let req = navigationAction.request.url!.absoluteString
        if req.starts(with: "data") && req.contains(",") {
            decisionHandler(WKNavigationActionPolicy.cancel)

            // determine file name
            let mimeType = req[indexPlus(str: req, char: ":")...indexMinus(str: req, char: ";")]
            var name = "export.txt"
            if mimeType == "text/csv" {
                name = "export.csv"
            }
            else if mimeType == "application/json" {
                name = "export.json"
            }
            
            // parse data from url
            var data = String(req[indexPlus(str: req, char: ",")...])
            data = data.removingPercentEncoding ?? data
            
            // create temp file path
            let docURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let file = docURL.appendingPathComponent(name)
            
            // save file
            do {
                try data.write(to: file, atomically: true, encoding: String.Encoding.utf8)
                
                // create file picker to move to user-accessible directory
                let docPicker = UIDocumentPickerViewController(forExporting: [file])
                docPicker.shouldShowFileExtensions = true
                self.present(docPicker, animated: true, completion: nil)
                print(name, data)
            }
            catch {
                print("Failed to save file")
            }
            return
        }
        decisionHandler(WKNavigationActionPolicy.allow)
    }
}

func indexPlus(str: String, char: Character) -> String.Index {
    return str.index(after: str.firstIndex(of: char)!)
}

func indexMinus(str: String, char: Character) -> String.Index {
    return str.index(before: str.firstIndex(of: char)!)
}
