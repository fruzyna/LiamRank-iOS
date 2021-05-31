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
    
    // create Android like toast notification
    func showToast(message: String, duration: Double) {
        let fontSize = CGFloat(12)
        let width = fontSize / 2 * CGFloat(message.count) + fontSize * 2
        let label = UILabel(frame: CGRect(x: webviewController.view.frame.size.width/2 - width/2,
                                          y: webviewController.view.frame.height - 100,
                                          width: width, height: 35))
        label.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        label.textColor = UIColor.white
        label.font = .systemFont(ofSize: fontSize)
        label.textAlignment = .center
        label.text = message
        label.alpha = 1.0
        label.layer.cornerRadius = 10
        label.clipsToBounds = true
        webviewController.view.addSubview(label)
        UIView.animate(withDuration: duration / 2, delay: duration / 2, options: .curveEaseOut, animations: {
            label.alpha = 0.0
        }, completion: { (isCompleted) in
            label.removeFromSuperview()
        })
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
        self.webview.uiDelegate = self
        self.webview.autoresizingMask = [.flexibleHeight, .flexibleWidth]
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

// handle JS alert, confirm, and input
extension WebviewController: WKUIDelegate {

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        let action = UIAlertAction(title: "OK", style: .default) { (_) in
            completionHandler()
        }
        alert.addAction(action)
        present(alert, animated: true, completion: nil)
    }
    
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default) { (_) in
            completionHandler(true)
        }
        alert.addAction(okAction)
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (_) in
            completionHandler(false)
        }
        alert.addAction(cancelAction)
        present(alert, animated: true, completion: nil)
    }
    
    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        let alert = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
        alert.addTextField()
        let action = UIAlertAction(title: "Submit", style: .default) { [unowned alert] _ in
            completionHandler(alert.textFields?.first?.text)
        }
        alert.addAction(action)
        present(alert, animated: true, completion: nil)
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
            var base64 = false
            if mimeType == "text/csv" {
                name = "export.csv"
            }
            else if mimeType == "application/json" {
                name = "export.json"
            }
            else if mimeType == "application/zip" {
                name = "export.zip"
                base64 = true
            }
            
            // parse data from url
            var data = String(req[indexPlus(str: req, char: ",")...])
            data = data.removingPercentEncoding ?? data
            
            // create temp file path
            let docURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let file = docURL.appendingPathComponent(name)
            
            // save file
            do {
                if base64 {
                    try Data(base64Encoded: data)?.write(to: file)
                }
                else {
                    try data.write(to: file, atomically: true, encoding: String.Encoding.utf8)
                }
                
                // create file picker to move to user-accessible directory
                let docPicker = UIDocumentPickerViewController(forExporting: [file])
                docPicker.shouldShowFileExtensions = true
                self.present(docPicker, animated: true, completion: nil)
                //print(name, data)
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
