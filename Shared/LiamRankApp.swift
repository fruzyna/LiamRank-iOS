//
//  LiamRankApp.swift
//  Shared
//
//  Created by Liam on 11/18/20.
//

import SwiftUI
import GCDWebServer
import ZIPFoundation

@main
struct LiamRankApp: App {
    var content = ContentView()
    var body: some Scene {
        WindowGroup {
            content
        }
    }
    
    let server = GCDWebServer()
    
    let docURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!  // documents folder
    let RELEASE_KEY = "CURRENT_RELEASE"
    
    init() {
        let latestURL = URL(string: "https://github.com/mail929/LiamRank/releases/latest")!
        URLSession.shared.downloadTask(with: latestURL, completionHandler: processLatest(urlOrNil:responseOrNil:errorOrNil:)).resume()
    }
    
    // start webserver
    func buildServer(repoURL: URL) {
        let uploadsURL = repoURL.appendingPathComponent("uploads")
        
        server.addDefaultHandler(forMethod: "GET", request: GCDWebServerRequest.self, processBlock: { request in
            var path = String(request.path.replacingOccurrences(of: "/config/", with: "/assets/").dropFirst())
            if (path == "") {
                path = "index.html"
            }
            let file = repoURL.appendingPathComponent(path)
            
            var ext = "json"
            var start: String
            
            // load in TBA API key
            if (path == "scripts/keys.js") {
                let API_KEY = ""
                let response = GCDWebServerDataResponse(text: "API_KEY=\"\(API_KEY)\"")
                response!.contentType = "text/javascript"
                return response
            }
            // respond to request for list of uploads
            else if (path == "getPitResultNames") {
                start = "pit"
            }
            else if (path == "getImageNames") {
                start = "image"
                ext = "png"
            }
            else if (path == "getMatchResultNames") {
                start = "match"
            }
            else if (path == "getNoteNames") {
                start = "note"
            }
            // about page
            else if (path == "about") {
                let contents = """
                    <!DOCTYPE html>\
                    <html lang="en">\
                        <head>\
                            <meta charset="utf-8"/>\
                            <title>LiamRank</title>\
                        </head>\
                        <body>\
                            <h1>LiamRank</h1>\
                            LiamRankApp.swift Swift POST server<br>2020 Liam Fruzyna<br><a href="https://github.com/mail929/LiamRank-iOS">MPL Licensed on GitHub</a>\
                        </body>\
                    </html>
                    """
                let response = GCDWebServerDataResponse(text: contents)
                response!.contentType = "text/html"
                return response
            }
            // return normal files
            else if FileManager.default.fileExists(atPath: file.path) {
                return GCDWebServerFileResponse(file: file.relativePath)
            }
            else {
                return GCDWebServerFileResponse(statusCode: 404)
            }
            
            // build list of uploads
            do {
                var files = try FileManager.default.contentsOfDirectory(at: uploadsURL, includingPropertiesForKeys: nil)
                files = files.filter { $0.lastPathComponent.starts(with: start) && $0.pathExtension == ext }
                let names = files.map { $0.lastPathComponent }
                let response = GCDWebServerDataResponse(text: names.joined(separator: ","))
                response!.contentType = "text/plain"
                return response
            }
            catch {
                return GCDWebServerFileResponse(statusCode: 404)
            }
        })
        
        server.addDefaultHandler(forMethod: "POST", request: GCDWebServerDataRequest.self, processBlock: { request in
            guard let dataReq = request as? GCDWebServerDataRequest else {
                return GCDWebServerFileResponse(statusCode: 400)
            }
            if request.hasBody() {
                let body = dataReq.text ?? ""
                if body.contains("|||") {
                    let parts = body.split(separator: "|")
                    if parts.count == 2 {
                        let name = parts[0]
                        let data = parts[1]
                        if data.starts(with: "data:image/png;base64,") {
                            let decoded = data.data(using: .utf8)
                            do {
                                try decoded?.write(to: uploadsURL.appendingPathComponent("\(name).png"))
                                return GCDWebServerResponse(statusCode: 200)
                            }
                            catch {
                                print("[POST] Failed to write \(name).png")
                                return GCDWebServerResponse(statusCode: 415)
                            }
                        }
                        else {
                            do {
                                try data.write(to: uploadsURL.appendingPathComponent("\(name).json"), atomically: false, encoding: .utf8)
                                return GCDWebServerResponse(statusCode: 200)
                            }
                            catch {
                                print("[POST] Failed to write \(name).json")
                                return GCDWebServerResponse(statusCode: 415)
                            }
                        }
                    }
                }
            }
            return GCDWebServerResponse(statusCode: 400)
        })
        
        DispatchQueue.main.async() {
            server.start(withPort: 8080, bonjourName: "LiamRank iOS")
        }
    }
    
    // determines the latest available release and runs server
    func processLatest(urlOrNil: URL?, responseOrNil: URLResponse?, errorOrNil: Error?) {
        let fileURL = urlOrNil
        
        let prefs = UserDefaults()
        var currentRelease = prefs.string(forKey: RELEASE_KEY) ?? "master"
        var updating = false
        if (fileURL != nil) {
            do {
                var pageText = try String(contentsOf: fileURL!)
                let range = pageText.range(of: "/mail929/LiamRank/releases/tag/")
                pageText = String(pageText[(range!.upperBound...)])
                let latestRelease = String(pageText[...pageText.firstIndex(of: "\"")!].dropLast())
                
                if (currentRelease != latestRelease) {
                    // download source
                    print("[UPDATER] Fetching release \(latestRelease)")
                    let remoteURL = URL(string: "https://github.com/mail929/LiamRank/archive/\(latestRelease).zip")!
                    URLSession.shared.downloadTask(with: remoteURL, completionHandler: processArchive(urlOrNil:responseOrNil:errorOrNil:)).resume()
                    currentRelease = latestRelease
                    updating = true
                }
                else {
                    print("[UPDATER] Release \(currentRelease) is up to date")
                }
            }
            catch {
                print("[UPDATER] Unable to read latest release")
            }
        }
        else {
            print("[UPDATER] Could not retrieve latest release, using existing")
        }
        
        prefs.set(currentRelease, forKey: RELEASE_KEY)
        print("[SERVER] Starting server for release \(currentRelease)")
        buildServer(repoURL: docURL.appendingPathComponent("LiamRank-\(currentRelease)"))
        if (!updating) {
            // load page when resources ready
            DispatchQueue.main.async() {
                content.webview.loadPage()
            }
        }
    }
    
    // extracts a given zip archive, then reloads webview
    func processArchive(urlOrNil: URL?, responseOrNil: URLResponse?, errorOrNil: Error?) {
        let fileURL = urlOrNil
        
        if (fileURL != nil) {
            let fileManager = FileManager()
            
            // remove existing extracted archive
            let release = responseOrNil!.url!.lastPathComponent
            do {
                try fileManager.removeItem(at: docURL.appendingPathComponent("LiamRank-\(release)"))
                print("[UPDATER] Removed existing release \(release)")
            } catch {
                // directory did not exist
            }
            
            // extract archive
            do {
                try fileManager.unzipItem(at: fileURL!, to: docURL)
            } catch {
                print ("[UPDATER] Error unzipping: \(error)")
            }
        }
        
        // load page when resources ready
        DispatchQueue.main.async() {
            content.webview.loadPage()
        }
    }
    
    // get list of files in a given directory
    // throws if not a directory
    func ls(dirURL: URL) throws -> String {
        let files = try FileManager.default.contentsOfDirectory(at: dirURL, includingPropertiesForKeys: nil)
        var output = ""
        for file in files {
            output += file.absoluteString + "\n"
        }
        return output
    }
}
