//
//  FairPlayServer.swift
//  MacFairPlayer
//
//  Created by Noam Tamim on 10/06/2019.
//  Copyright © 2019 Noam Tamim. All rights reserved.
//

import Foundation
import DRMPlayerItemLoader

struct FairPlayServerResponseContainer: Codable {
    var ckc: String?
    var persistence_duration: TimeInterval?
}

enum FPSServerError: Error {
    case drmServerError(_ error: Error, _ url: URL)
}


class FairPlayServer: FairPlayLicenseProvider {
    static let sharedInstance = FairPlayServer()
    
    func requestApplicationCertificate() -> Data {
            let certificateString = "MIIFETCCA/mgAwIBAgIISWLo8KcYfPMwDQYJKoZIhvcNAQEFBQAwfzELMAkGA1UEBhMCVVMxEzARBgNVBAoMCkFwcGxlIEluYy4xJjAkBgNVBAsMHUFwcGxlIENlcnRpZmljYXRpb24gQXV0aG9yaXR5MTMwMQYDVQQDDCpBcHBsZSBLZXkgU2VydmljZXMgQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkwHhcNMTYwMjAxMTY0NTQ0WhcNMTgwMjAxMTY0NTQ0WjCBijELMAkGA1UEBhMCVVMxKDAmBgNVBAoMH1ZJQUNPTSAxOCBNRURJQSBQUklWQVRFIExJTUlURUQxEzARBgNVBAsMClE5QU5HR0w4TTYxPDA6BgNVBAMMM0ZhaXJQbGF5IFN0cmVhbWluZzogVklBQ09NIDE4IE1FRElBIFBSSVZBVEUgTElNSVRFRDCBnzANBgkqhkiG9w0BAQEFAAOBjQAwgYkCgYEA2YmfdPWM86+te7Bbt4Ic6FexXwMeL+8AmExIj8jAaNxhKbfVFnUnuXzHOajGC7XDbXxsFbPqnErqjw0BqUoZhs+WVMy+0X4AGqHk7uRpZ4RLYganel+fqitL9rz9w3p41x8JfLV+lAej+BEN7zNeqQ2IsC4BxkViu1gA6K22uGsCAwEAAaOCAgcwggIDMB0GA1UdDgQWBBQK+Gmarl2PO3jtLP6A6TZeihOL3DAMBgNVHRMBAf8EAjAAMB8GA1UdIwQYMBaAFGPkR1TLhXFZRiyDrMxEMWRnAyy+MIHiBgNVHSAEgdowgdcwgdQGCSqGSIb3Y2QFATCBxjCBwwYIKwYBBQUHAgIwgbYMgbNSZWxpYW5jZSBvbiB0aGlzIGNlcnRpZmljYXRlIGJ5IGFueSBwYXJ0eSBhc3N1bWVzIGFjY2VwdGFuY2Ugb2YgdGhlIHRoZW4gYXBwbGljYWJsZSBzdGFuZGFyZCB0ZXJtcyBhbmQgY29uZGl0aW9ucyBvZiB1c2UsIGNlcnRpZmljYXRlIHBvbGljeSBhbmQgY2VydGlmaWNhdGlvbiBwcmFjdGljZSBzdGF0ZW1lbnRzLjA1BgNVHR8ELjAsMCqgKKAmhiRodHRwOi8vY3JsLmFwcGxlLmNvbS9rZXlzZXJ2aWNlcy5jcmwwDgYDVR0PAQH/BAQDAgUgMEgGCyqGSIb3Y2QGDQEDAQH/BDYBZ2diOGN5bXpsb21vdXFqb3p0aHg5aXB6dDJ0bThrcGdqOGNwZGlsbGVhMWI1aG9saWlyaW8wPQYLKoZIhvdjZAYNAQQBAf8EKwF5aHZlYXgzaDB2Nno5dXBqcjRsNWVyNm9hMXBtam9zYXF6ZXdnZXFkaTUwDQYJKoZIhvcNAQEFBQADggEBAIaTVzuOpZhHHUMGd47XeIo08E+Wb5jgE2HPsd8P/aHwVcR+9627QkuAnebftasV/h3FElahzBXRbK52qIZ/UU9nRLCqqKwX33eS2TiaAzOoMAL9cTUmEa2SMSzzAehb7lYPC73Y4VQFttbNidHZHawGp/844ipBS7Iumas8kT8G6ZmIBIevWiggd+D5gLdqXpOFI2XsoAipuxW6NKnnlKnuX6aNReqzKO0DmQPDHO2d7pbd3wAz5zJmxDLpRQfn7iJKupoYGqBs2r45OFyM14HUWaC0+VSh2PaZKwnSS8XXo4zcT/MfEcmP0tL9NaDfsvIWnScMxHUUTNNsZIp3QXA="
            return Data(base64Encoded: certificateString)!
    }
    
    func buildLicenseURL(identifier: String) -> URL {
        return URL(string: "https://udrmv3.kaltura.com/fps/license?custom_data=eyJjYV9zeXN0ZW0iOiJPVlAiLCJ1c2VyX3Rva2VuIjoiZGpKOE1qSXlNalF3TVh6VlliX2pYYVFCUzd6VF9XZEdERW54MkpQbU5HVmNsYlVQWWhwenFCLUJJOTdod1Y5ekxGdG9hY1ZTM0J3bnV4cDBiZUhVa2x1WXd5MHp4MTRSRUxzU3VkR2s2cXVLS2FsRDJqWTcycC1CZGc9PSIsImFjY291bnRfaWQiOiIyMjIyNDAxIiwiY29udGVudF9pZCI6IjFfaTE4cmlodXYiLCJmaWxlcyI6IjFfbndvb2ZxdnIsMV8zejc1d3d4aSwxX2V4anQ1bGU4LDFfdXZiM2Z5cXMifQ%3D%3D&signature=Dhi6sWjfjWAsydjex5ExcigSIms%3D")!
    }
    
    func getLicense(spc: Data, assetId: String, url: URL, headers: [String:String], callback: @escaping (Data?, TimeInterval, Error?) -> Void) {
        var request = URLRequest(url: url)
        for (header, value) in headers {
            request.setValue(value, forHTTPHeaderField: header)
        }
        
        // If a specific content-type was requested by the adapter, use it.
        // Otherwise, the uDRM requires application/octet-stream.
        if request.value(forHTTPHeaderField: "Content-Type") == nil {
            request.addValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        }
        
        request.httpBody = spc.base64EncodedData()
        request.httpMethod = "POST"
        
        print("Sending SPC to server")
        let startTime = Date.timeIntervalSinceReferenceDate
        let dataTask = URLSession.shared.dataTask(with: request) { (data: Data?, response: URLResponse?, error: Error?) -> Void in
            
            if let error = error {
                callback(nil, 0, FPSServerError.drmServerError(error, url))
                return
            }
            
            do {
                let endTime: Double = Date.timeIntervalSinceReferenceDate
                print("Got response in \(endTime-startTime) sec")
                
                guard let data = data else {
                    callback(nil, 0, NSError(domain: "KalturaFairPlayLicenseProvider", code: 1, userInfo: nil))
                    return
                }
                
                let lic = try JSONDecoder().decode(FairPlayServerResponseContainer.self, from: data)
                print("persistence_duration: \(lic.persistence_duration)")

                callback(Data(base64Encoded: lic.ckc ?? ""), lic.persistence_duration ?? 0, nil)
                
            } catch let e {
                callback(nil, 0, e)
            }
        }
        dataTask.resume()
    }
}

