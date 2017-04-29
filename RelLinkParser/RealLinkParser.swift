//
//  RealLinkParser.swift
//  RelLinkParser
//
//  Created by Eddie Hinkle on 4/29/17.
//  Copyright © 2017 Studio H, LLC. All rights reserved.
//

import Foundation

public class RealLinkParser {
    
    struct IndieWebMeEndpoints {
        var authorization_endpoint: URL?
        var token_endpoint: URL?
        var micropub: URL?
    }

    public func fetchEndpoints(url: URL, completion: @escaping (IndieWebMeEndpoints) -> ()) {
        let endpointGroup = DispatchGroup()
        var endpoints = IndieWebMeEndpoints()
        
        endpointGroup.enter()
        discoverEndpoint(.Authorization, atUrl: url) { endpointUrl in
            if let authorizationEndpoint = endpointUrl {
                print("Authorization Endpoint Found \(authorizationEndpoint)")
                endpoints.authorization_endpoint = authorizationEndpoint
            } else {
                print("Authorization Endpoint Failed");
            }
            
            endpointGroup.leave()
        }
        
        endpointGroup.enter()
        discoverEndpoint(.Token, atUrl: url) { endpointUrl in
            if let tokenEndpoint = endpointUrl {
                print("Token Endpoint Found \(tokenEndpoint)")
                endpoints.token_endpoint = tokenEndpoint
            } else {
                print("Token Endpoint Failed");
            }
            endpointGroup.leave()
        }
        
        endpointGroup.enter()
        discoverEndpoint(.Micropub, atUrl: url) { endpointUrl in
            if let micropubEndpoint = endpointUrl {
                print("Micropub Endpoint Found \(micropubEndpoint)")
                endpoints.micropub = micropubEndpoint
            } else {
                print("Micropub Endpoint Failed");
            }
            
            endpointGroup.leave()
        }
        
        endpointGroup.notify(queue: DispatchQueue.global(qos: .background)) {
            print("AReturning Endpoints")
            completion(endpoints)
        }
    }
    
    // Input: Any URL or string like "eddiehinkle.com"
    // Output: Normlized URL (default to http if no scheme, default "/" path)
    //         or return false if not a valid URL (has query string params, etc)
    public func normalizeMeURL(url: String) -> URL? {
        
        var meUrl = URLComponents(string: url)
        
        // If there is no scheme or host, the host is probably in the path
        if (meUrl?.scheme == nil && meUrl?.host == nil) {
            // If the path is nil or empty, then our url is probably empty. Mayday!
            if (meUrl?.path == nil || meUrl?.path == "") {
                return nil;
            }
            
            // Split the path into segments so we can seperate the host and the path
            let pathSegments = meUrl?.path.characters.split(separator: "/").map(String.init)
            
            meUrl?.host = pathSegments?.first;
            meUrl?.path = "/" + (pathSegments?.dropFirst().joined() ?? "")
        }
        
        // If no scheme, we default to http
        if (meUrl?.scheme == nil) {
            meUrl?.scheme = "http"
        } else if (meUrl?.scheme != "http" && meUrl?.scheme != "https") {
            // If there is a scheme, we only accept http and https schemes
            print("Scheme existed and wasn't http or https: \(meUrl?.scheme ?? "No Scheme")")
            return nil
        }
        
        // We default to a path of /
        if (meUrl?.path == nil || meUrl?.path == "") {
            meUrl?.path = "/"
        }
        
        // We don't want query or fragment messing up our url. Just set those to nil
        meUrl?.fragment = nil
        meUrl?.query = nil
        
        return meUrl?.url
    }
    
    public func discoverEndpoint(_ endpointType: IndieWebEndpointType, atUrl meUrl: URL, completion: @escaping (URL?) -> ()) {
        let request = URLRequest(url: meUrl)
        
        // set up the session
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config)
        
        let task = session.dataTask(with: request) {
            (data, response, error) in
            // check for any errors
            guard error == nil else {
                print("error calling GET on \(meUrl)")
                print(error ?? "No error present")
                return
            }
            
            // Check if endpoint is in the HTTP Header fields
            if let httpResponse = response as? HTTPURLResponse {
                if let linkHeaderString = httpResponse.allHeaderFields["Link"] as? String {
                    let linkHeaders = linkHeaderString.characters.split(separator: ",").map({charactersSequence in
                        return self.matches(for: "<([a-zA-Z:\\/\\.]+)>; rel=\"\(endpointType.rawValue)\"", in: String.init(charactersSequence))
                    })
                    
                    for headerLink in linkHeaders {
                        for link in headerLink {
                            if let headerUrl = URL(string: link) {
                                completion(headerUrl)
                                return
                            }
                        }
                    }
                    
                }
            }
            
            // Check if endpoint is in the HTML Head
            //            if let responseData = data {
            //
            //            }
            
            
            completion(nil)
        }
        
        task.resume()
    }
    
    // Utlity Methods
    func matches(for regex: String, in text: String) -> [String] {
        
        do {
            let regex = try NSRegularExpression(pattern: regex)
            let nsString = text as NSString
            let results = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))
            var matches: [String] = []
            // TODO: This currently returns the entire match, this needs to be modified to return only the captured groups
            // look more into this https://code.tutsplus.com/tutorials/swift-and-regular-expressions-swift--cms-26626
            for match in results {
                for n in 1..<match.numberOfRanges {
                    let range = match.rangeAt(n)
                    let r = text.index(text.startIndex, offsetBy: range.location) ..< text.index(text.startIndex, offsetBy: range.location+range.length)
                    matches.append(text.substring(with: r))
                }
            }
            
            
            
            return matches
        } catch let error {
            print("invalid regex: \(error.localizedDescription)")
            return []
        }
    }
    
}
