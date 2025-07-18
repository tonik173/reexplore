//
//  DownloadClient.swift
//  Reexplore
//
//  Created by Toni Kaufmann on 01.07.20.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//
import Foundation

class DownloadClient: NSObject
{
    enum DownloadClientError: Error {
        case NoData
    }
    
    typealias FailureHandler = (_ requestId: UInt, _ reason: String, _ error: Error?) -> Void
    typealias DownloadDoneHandler = (_ requestId: UInt,_ data: Data) -> Void
    
    func execute(with url: URL,
                 withId id: UInt,
                 failureHandler: @escaping FailureHandler,
                 doneHandler: @escaping DownloadDoneHandler)
    {
        let request = URLRequest(url: url)
        
        #if DEBUG
        let session = URLSession(configuration: URLSessionConfiguration.ephemeral)
        #else
        let session = URLSession(configuration: URLSessionConfiguration.default)
        #endif
         
        let task =  session.dataTask(with: request) { (data, response, error) in
            
            var statusCode = 400
            var err: Error?
            
            if let httpResponse = response as? HTTPURLResponse {
                if err != nil || httpResponse.statusCode != 200 {
                    statusCode = httpResponse.statusCode
                    err = error
                }
                else if let httpData = data {
                    let payload = NSData(data: httpData) as Data
                    doneHandler(id, payload)
                    return
                }
                else {
                    err = DownloadClientError.NoData
                }
            }
            
            let httpStatusCode = "commErr".localized + " (\(statusCode))"
            failureHandler(id, httpStatusCode, err)
        }
        task.resume()
    }
}
