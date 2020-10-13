//
//  PageStatistics.swift
//  Cumulocity Client Library
//
//  Created by John Carter on 22/04/2020.
//  Copyright © 2020 John Carter. All rights reserved.
//

import Foundation

/**
 Used when fetching assets from c8y to ensure that client is not overloaded. All services have a 'pageSize' attribute to limit the number of rows returned for any request. Each response is also provided withh an instance of this class
 to ensure that the caller can determine if there are more assets to fetch. They can retrieve the next page by calling the original function, incrementing the pageNum
 */
public struct C8yPageStatistics: Codable {
       
    /**
     The page just fetched
     */
    public let currentPage: Int
    /**
     The page size that was used, i.e. max number of rows allowed to returned
     */
    public let pageSize: Int
    
    /**
     The total number of pages that can be fetched, nil if total available results is smaller than the page size
     */
    public let totalPages: Int?
       
       enum CodingKeys : String, CodingKey {
           case currentPage
           case pageSize
           case totalPages
       }
   }
