//
//  StringEx.swift
//  Reexplore
//
//  Created by Toni Kaufmann on 01.07.20.
//  Copyright © 2020 n3xd software studios ag. All rights reserved.
//
import Foundation

extension String
{
    var localized: String
    {
        get {
            return NSLocalizedString(self, tableName: "UserInterface", bundle: Bundle.main, value: self, comment: "")
        }
    }
    
    func pad(string : String, toSize: Int) -> String
    {
      var padded = string
      for _ in 0..<(toSize - string.count) {
        padded = "0" + padded
      }
        return padded
    }
    
    func convertToValidFileName() -> String
    {
         let invalidFileNameCharactersRegex = "[^a-zA-Z0-9_]+"
         let fullRange = startIndex..<endIndex
         let validName = replacingOccurrences(of: invalidFileNameCharactersRegex,
                                            with: "-",
                                         options: .regularExpression,
                                           range: fullRange)
         return validName
     }
}
