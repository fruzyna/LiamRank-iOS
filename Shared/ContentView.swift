//
//  ContentView.swift
//  LiamRank
//
//  Created by Liam on 11/18/20.
//

import SwiftUI
import WebKit

struct ContentView: View {
    var body: some View {
        Webview(url: URL(string: "https://wildrank.fruzyna.net")!)
    }
}

struct Webview: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> WebviewController {
        let webviewController = WebviewController()

        let request = URLRequest(url: self.url, cachePolicy: .returnCacheDataElseLoad)
        webviewController.webview.load(request)

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
