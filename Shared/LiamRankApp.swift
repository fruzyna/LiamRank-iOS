//
//  LiamRankApp.swift
//  Shared
//
//  Created by Liam on 11/18/20.
//

import SwiftUI
import GCDWebServer
import ZIPFoundation
import ActionOver

/*
 * TODO
 * - Loading screen, stay up
 * - Fix Mac webview
 */

@main
struct LiamRankApp: App {
    @State var promptUser = true
    
    let webview = Webview(url: URL(string: "http://127.0.0.1:8080/index.html")!)
    var body: some Scene {
        WindowGroup {
            webview.actionOver(presented: $promptUser,
                               title: "Choose a Release",
                               message: "This will either use an existing local version or fetch a copy from GitHub.",
                               buttons: generateActionSheetOptions(),
                               ipadAndMacConfiguration: IpadAndMacConfiguration(anchor: UnitPoint.center, arrowEdge: Edge.bottom))
        }
    }
    
    let server = GCDWebServer()
    
    let docURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!  // documents folder
    let RELEASE_KEY = "LAST_USED_RELEASE"
    
    /*
     * UTILITY FUNCTIONS
     */
    
    // process the latest release page to get its name
    func determineRelease(fileURL: URL) -> String {
        do {
            let pageText = try String(contentsOf: fileURL)
            let releaseSearchKey = "/mail929/LiamRank/releases/tag/"
            if pageText.contains(releaseSearchKey) {
                let releaseRange = pageText.range(of: releaseSearchKey)
                var latestRelease = String(pageText[(releaseRange!.upperBound...)])
                latestRelease = String(latestRelease[...latestRelease.firstIndex(of: "\"")!].dropLast())
                print("[UPDATER] Latest release is \(latestRelease)")
                return latestRelease
            }
            print("[UPDATER] Release search key not found")
        }
        catch {
            print("[UPDATER] Release file not found")
        }
        return ""
    }
    
    // find the last recorded release
    func getLastRelease() -> String {
        return UserDefaults().string(forKey: RELEASE_KEY) ?? "master"
    }
    
    // determined if a given release is already downloaded
    func isReleaseCached(release: String) -> Bool {
        let fileManager = FileManager()
        let path = docURL.appendingPathComponent("LiamRank-\(release)").relativePath
        return fileManager.fileExists(atPath: path)
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
    
    /*
     * EXECUTION
     */
    
    // generate list of available releases to use
    func generateActionSheetOptions() -> [ActionOverButton] {
        var buttons = [ActionOverButton]()
        let latest = getLastRelease()
        buttons.append(ActionOverButton(title: "Last Used: \(latest)",
                                        type: .normal,
                                        action: { start(release: latest) }))
        buttons.append(ActionOverButton(title: "Latest Remote Release",
                                        type: .normal,
                                        action: { start(release: "latest") }))
        buttons.append(ActionOverButton(title: "Master Branch",
                                        type: .normal,
                                        action: { start(release: "master") }))
        do {
            let files = try FileManager.default.contentsOfDirectory(at: docURL, includingPropertiesForKeys: nil)
            for file in files {
                // filters by potential releases
                let name = file.lastPathComponent
                if name.starts(with: "LiamRank-") {
                    let release = String(name.split(separator: "-")[1])
                    if release != latest &&
                        release != "master" {
                        buttons.append(ActionOverButton(title: "Cached: \(release)",
                                                        type: .normal,
                                                        action: { start(release: release) }))
                    }
                }
            }
        }
        catch {
            print("[DIALOG] Failed to get contents of documents directory")
        }
        return buttons
    }
    
    // on startup
    init() {
        if !promptUser {
            start(release: "latest")
        }
    }
    
    // runs after init
    func start(release: String) {
        if release == "latest" {
            let latestURL = URL(string: "https://github.com/mail929/LiamRank/releases/latest")!
            URLSession.shared.downloadTask(with: latestURL, completionHandler: processLatest(urlOrNil:responseOrNil:errorOrNil:)).resume()
        }
        else {
            useRelease(release: release)
        }
    }
    
    // determines the latest available release and runs server
    func processLatest(urlOrNil: URL?, responseOrNil: URLResponse?, errorOrNil: Error?) {
        let fileURL = urlOrNil
        
        if fileURL != nil {
            // if given a valid URL, passes release found from it
            useRelease(release: determineRelease(fileURL: fileURL!))
        }
        else {
            print("[UPDATER] Could not retrieve latest release, using existing")
            useRelease(release: "")
        }
    }
    
    // attempt to use a given or the last used release
    func useRelease(release: String) {
        var release = release
        
        // if no release was given
        if release.count == 0 {
            // use the last used release
            release = getLastRelease()
        }
        
        // if the desired release does not exist
        if !isReleaseCached(release: release) {
            // download it
            fetchRelease(release: release)
        }
        else {
            // otherwise, start app with release
            startRelease(release: release)
        }
    }
    
    // fetch a given release from GitHub
    func fetchRelease(release: String) {
        print("[UPDATER] Fetching release \(release)")
        let remoteURL = URL(string: "https://github.com/mail929/LiamRank/archive/\(release).zip")!
        URLSession.shared.downloadTask(with: remoteURL, completionHandler: processArchive(urlOrNil:responseOrNil:errorOrNil:)).resume()
    }
    
    // attempts to extract the archive and start the app, uses local on failure
    func processArchive(urlOrNil: URL?, responseOrNil: URLResponse?, errorOrNil: Error?) {
        let fileURL = urlOrNil
        
        if fileURL != nil {
            let fileManager = FileManager()
            let release = responseOrNil!.url!.lastPathComponent
            
            // remove existing extracted archive
            do {
                try fileManager.removeItem(at: docURL.appendingPathComponent("LiamRank-\(release)"))
                print("[UPDATER] Removed existing release \(release)")
            }
            catch {
                // directory did not exist
            }
            
            // extract archive and start
            do {
                try fileManager.unzipItem(at: fileURL!, to: docURL)
                startRelease(release: release)
                return
            }
            catch {
                print("[UPDATER] Error unzipping: \(error)")
            }
        }
        else {
            print("[UPDATER] Failed to download archive")
        }
        
        // use a local release
        findReleaseLocal()
    }
    
    // find a release to use locally
    func findReleaseLocal() {
        // choose the last release
        var release = getLastRelease()
        
        // if the last release does not exist
        if !isReleaseCached(release: release) {
            print("[LOCAL] Searching for any existing releases")
            // try and find the newest release
            release = searchForRelease()
        }
        
        // if a release is found
        if release.count > 0 {
            // start
            startRelease(release: release)
        }
        else {
            // otherwise TODO: fail
            print("[LOCAL] Failed to find any existing releases")
        }
    }
    
    // attempts to find the latest local release
    func searchForRelease() -> String {
        do {
            var newestName = ""
            var newestDate = Date(timeIntervalSince1970: 0)
            
            // lays out contents of documents folder
            let files = try FileManager.default.contentsOfDirectory(at: docURL, includingPropertiesForKeys: nil)
            for file in files {
                // filters by potential releases
                let name = file.lastPathComponent
                if name.starts(with: "LiamRank-") {
                    do {
                        // determines last modification date
                        let attrs = try FileManager.default.attributesOfItem(atPath: file.path)
                        let date = attrs[FileAttributeKey.modificationDate]
                        if date is Date {
                            let dateDate = date as! Date
                            print("[LOCAL] Found \(name) from \(dateDate)")
                            // determines if the directory is newer
                            if (dateDate > newestDate) {
                                newestName = name
                                newestDate = dateDate
                            }
                        }
                        else {
                            print("[LOCAL] Failed to parse date of file \(name)")
                        }
                    }
                    catch {
                        print("[LOCAL] Failed to get date of file \(name)")
                    }
                }
            }
            
            // returns the release name if valid
            if newestName.contains("-") {
                return String(newestName.split(separator: "-")[1])
            }
        }
        catch {
            print("[LOCAL] Unable to get contents of documents directory")
        }
        return ""
    }
    
    // start the webserver and webview with a given release
    func startRelease(release: String) {
        print("[SERVER] Starting server for release \(release)")
        
        // save the name of the release
        UserDefaults().set(release, forKey: RELEASE_KEY)
        
        // construct the server for the release
        buildServer(repoURL: docURL.appendingPathComponent("LiamRank-\(release)"))
        
        // load the main page
        DispatchQueue.main.async() {
            webview.loadPage()
        }
    }
    
    // start webserver
    func buildServer(repoURL: URL) {
        let uploadsURL = repoURL.appendingPathComponent("uploads")
        
        var api_key = ""
        if let path = Bundle.main.path(forResource: "keys", ofType: "plist") {
            let dict = NSDictionary(contentsOfFile: path)!
            if dict.allKeys.contains(where: { (key) -> Bool in key as! String == "API_KEY" }) {
                let key = dict["API_KEY"]
                if (key is String) {
                    api_key = key as! String
                }
            }
        }
        
        server.addDefaultHandler(forMethod: "GET", request: GCDWebServerRequest.self, processBlock: { request in
            var path = String(request.path.replacingOccurrences(of: "/config/", with: "/assets/").dropFirst())
            if path == "" {
                path = "index.html"
            }
            let file = repoURL.appendingPathComponent(path)
            
            var ext = "json"
            var start: String
            
            // respond to request for list of uploads
            if path == "getPitResultNames" {
                start = "pit"
            }
            else if path == "getImageNames" {
                start = "image"
                ext = "png"
            }
            else if path == "getMatchResultNames" {
                start = "match"
            }
            else if path == "getNoteNames" {
                start = "note"
            }
            // about page
            else if path == "about" {
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
            // load in TBA API key
            else if path == "scripts/keys.js" {
                let response = GCDWebServerDataResponse(text: "API_KEY=\"\(api_key)\"")
                response!.contentType = "text/javascript"
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
        
        // start server on port 8080
        // TODO: configure port
        DispatchQueue.main.async() {
            server.start(withPort: 8080, bonjourName: "LiamRank iOS")
        }
    }
}
