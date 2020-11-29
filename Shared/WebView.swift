//
//  WebView.swift
//  LiamRank (iOS)
//
//  Created by Liam on 11/28/20.
//

import SwiftUI
import WebKit

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
    lazy var progressbar: UIProgressView = UIProgressView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        clean()
        
        self.webview.evaluateJavaScript("navigator.userAgent")
        self.webview.allowsBackForwardNavigationGestures = true
        self.webview.frame = self.view.frame
        self.view.addSubview(self.webview)
    }
    
    // wipe cache
    func clean() {
        let websiteDataTypes = NSSet(array: [WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache])
        let date = Date(timeIntervalSince1970: 0)
        WKWebsiteDataStore.default().removeData(ofTypes: websiteDataTypes as! Set<String>, modifiedSince: date, completionHandler:{ })
    }
}
