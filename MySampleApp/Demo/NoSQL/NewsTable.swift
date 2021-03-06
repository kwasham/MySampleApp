//
//  NewsTable.swift
//  MySampleApp
//
//
// Copyright 2017 Amazon.com, Inc. or its affiliates (Amazon). All Rights Reserved.
//
// Code generated by AWS Mobile Hub. Amazon gives unlimited permission to 
// copy, distribute and modify it.
//
// Source code generated from template: aws-my-sample-app-ios-swift v0.19
//

import Foundation
import UIKit
import AWSDynamoDB
import AWSAuthCore

class NewsTable: NSObject, Table {
    
    var tableName: String
    var partitionKeyName: String
    var partitionKeyType: String
    var sortKeyName: String?
    var sortKeyType: String?
    var model: AWSDynamoDBObjectModel
    var indexes: [Index]
    var orderedAttributeKeys: [String] {
        return produceOrderedAttributeKeys(model)
    }
    var tableDisplayName: String {

        return "News"
    }
    
    override init() {

        model = News()
        
        tableName = model.classForCoder.dynamoDBTableName()
        partitionKeyName = model.classForCoder.hashKeyAttribute()
        partitionKeyType = "String"
        indexes = [

            NewsPrimaryIndex(),

            NewsCategories(),
        ]
        if let sortKeyNamePossible = model.classForCoder.rangeKeyAttribute?() {
            sortKeyName = sortKeyNamePossible
            sortKeyType = "String"
        }
        super.init()
    }
    
    /**
     * Converts the attribute name from data object format to table format.
     *
     * - parameter dataObjectAttributeName: data object attribute name
     * - returns: table attribute name
     */

    func tableAttributeName(_ dataObjectAttributeName: String) -> String {
        return News.jsonKeyPathsByPropertyKey()[dataObjectAttributeName] as! String
    }
    
    func getItemDescription() -> String {
        let hashKeyValue = AWSIdentityManager.default().identityId!
        let rangeKeyValue = "demo-articleId-500000"
        return "Find Item with userId = \(hashKeyValue) and articleId = \(rangeKeyValue)."
    }
    
    func getItemWithCompletionHandler(_ completionHandler: @escaping (_ response: AWSDynamoDBObjectModel?, _ error: NSError?) -> Void) {
        let objectMapper = AWSDynamoDBObjectMapper.default()
        objectMapper.load(News.self, hashKey: AWSIdentityManager.default().identityId!, rangeKey: "demo-articleId-500000") { (response: AWSDynamoDBObjectModel?, error: Error?) in
            DispatchQueue.main.async(execute: {
                completionHandler(response, error as NSError?)
            })
        }
    }
    
    func scanDescription() -> String {
        return "Show all items in the table."
    }
    
    func scanWithCompletionHandler(_ completionHandler: @escaping (_ response: AWSDynamoDBPaginatedOutput?, _ error: NSError?) -> Void) {
        let objectMapper = AWSDynamoDBObjectMapper.default()
        let scanExpression = AWSDynamoDBScanExpression()
        scanExpression.limit = 5

        objectMapper.scan(News.self, expression: scanExpression) { (response: AWSDynamoDBPaginatedOutput?, error: Error?) in
            DispatchQueue.main.async(execute: {
                completionHandler(response, error as NSError?)
            })
        }
    }
    
    func scanWithFilterDescription() -> String {
        let scanFilterValue = "demo-author-500000"
        return "Find all items with author < \(scanFilterValue)."
    }
    
    func scanWithFilterWithCompletionHandler(_ completionHandler: @escaping (_ response: AWSDynamoDBPaginatedOutput?, _ error: NSError?) -> Void) {
        let objectMapper = AWSDynamoDBObjectMapper.default()
        let scanExpression = AWSDynamoDBScanExpression()
        
        scanExpression.filterExpression = "#author < :author"
        scanExpression.expressionAttributeNames = ["#author": "author" ,]
        scanExpression.expressionAttributeValues = [":author": "demo-author-500000" ,]

        objectMapper.scan(News.self, expression: scanExpression) { (response: AWSDynamoDBPaginatedOutput?, error: Error?) in
            DispatchQueue.main.async(execute: {
                completionHandler(response, error as? NSError)
            })
        }
    }
    
    func insertSampleDataWithCompletionHandler(_ completionHandler: @escaping (_ errors: [NSError]?) -> Void) {
        let objectMapper = AWSDynamoDBObjectMapper.default()
        var errors: [NSError] = []
        let group: DispatchGroup = DispatchGroup()
        let numberOfObjects = 20
        

        let itemForGet: News! = News()
        
        itemForGet._userId = AWSIdentityManager.default().identityId!
        itemForGet._articleId = "demo-articleId-500000"
        itemForGet._author = NoSQLSampleDataGenerator.randomSampleStringWithAttributeName("author")
        itemForGet._category = NoSQLSampleDataGenerator.randomPartitionSampleStringWithAttributeName("category")
        itemForGet._content = NoSQLSampleDataGenerator.randomSampleStringWithAttributeName("content")
        itemForGet._creationDate = NoSQLSampleDataGenerator.randomSampleNumber()
        itemForGet._keywords = NoSQLSampleDataGenerator.randomSampleStringSet()
        itemForGet._title = NoSQLSampleDataGenerator.randomSampleStringWithAttributeName("title")
        
        
        group.enter()
        

        objectMapper.save(itemForGet, completionHandler: {(error: Error?) -> Void in
            if let error = error as? NSError {
                DispatchQueue.main.async(execute: {
                    errors.append(error)
                })
            }
            group.leave()
        })
        
        for _ in 1..<numberOfObjects {

            let item: News = News()
            item._userId = AWSIdentityManager.default().identityId!
            item._articleId = NoSQLSampleDataGenerator.randomSampleStringWithAttributeName("articleId")
            item._author = NoSQLSampleDataGenerator.randomSampleStringWithAttributeName("author")
            item._category = NoSQLSampleDataGenerator.randomPartitionSampleStringWithAttributeName("category")
            item._content = NoSQLSampleDataGenerator.randomSampleStringWithAttributeName("content")
            item._creationDate = NoSQLSampleDataGenerator.randomSampleNumber()
            item._keywords = NoSQLSampleDataGenerator.randomSampleStringSet()
            item._title = NoSQLSampleDataGenerator.randomSampleStringWithAttributeName("title")
            
            group.enter()
            
            objectMapper.save(item, completionHandler: {(error: Error?) -> Void in
                if error != nil {
                    DispatchQueue.main.async(execute: {
                        errors.append(error! as NSError)
                    })
                }
                group.leave()
            })
        }
        
        group.notify(queue: DispatchQueue.main, execute: {
            if errors.count > 0 {
                completionHandler(errors)
            }
            else {
                completionHandler(nil)
            }
        })
    }
    
    func removeSampleDataWithCompletionHandler(_ completionHandler: @escaping ([NSError]?) -> Void) {
        let objectMapper = AWSDynamoDBObjectMapper.default()
        let queryExpression = AWSDynamoDBQueryExpression()
        queryExpression.keyConditionExpression = "#userId = :userId"
        queryExpression.expressionAttributeNames = ["#userId": "userId"]
        queryExpression.expressionAttributeValues = [":userId": AWSIdentityManager.default().identityId!,]

        objectMapper.query(News.self, expression: queryExpression) { (response: AWSDynamoDBPaginatedOutput?, error: Error?) in
            if let error = error as? NSError {
                DispatchQueue.main.async(execute: {
                    completionHandler([error]);
                    })
            } else {
                var errors: [NSError] = []
                let group: DispatchGroup = DispatchGroup()
                for item in response!.items {
                    group.enter()
                    objectMapper.remove(item, completionHandler: {(error: Error?) in
                        if let error = error as? NSError {
                            DispatchQueue.main.async(execute: {
                                errors.append(error)
                            })
                        }
                        group.leave()
                    })
                }
                group.notify(queue: DispatchQueue.main, execute: {
                    if errors.count > 0 {
                        completionHandler(errors)
                    }
                    else {
                        completionHandler(nil)
                    }
                })
            }
        }
    }
    
    func updateItem(_ item: AWSDynamoDBObjectModel, completionHandler: @escaping (_ error: NSError?) -> Void) {
        let objectMapper = AWSDynamoDBObjectMapper.default()
        

        let itemToUpdate: News = item as! News
        
        itemToUpdate._author = NoSQLSampleDataGenerator.randomSampleStringWithAttributeName("author")
        itemToUpdate._category = NoSQLSampleDataGenerator.randomPartitionSampleStringWithAttributeName("category")
        itemToUpdate._content = NoSQLSampleDataGenerator.randomSampleStringWithAttributeName("content")
        itemToUpdate._creationDate = NoSQLSampleDataGenerator.randomSampleNumber()
        itemToUpdate._keywords = NoSQLSampleDataGenerator.randomSampleStringSet()
        itemToUpdate._title = NoSQLSampleDataGenerator.randomSampleStringWithAttributeName("title")
        
        objectMapper.save(itemToUpdate, completionHandler: {(error: Error?) in
            DispatchQueue.main.async(execute: {
                completionHandler(error as? NSError)
            })
        })
    }
    
    func removeItem(_ item: AWSDynamoDBObjectModel, completionHandler: @escaping (_ error: NSError?) -> Void) {
        let objectMapper = AWSDynamoDBObjectMapper.default()
        
        objectMapper.remove(item, completionHandler: {(error: Error?) in
            DispatchQueue.main.async(execute: {
                completionHandler(error as? NSError)
            })
        })
    }
}

class NewsPrimaryIndex: NSObject, Index {
    
    var indexName: String? {
        return nil
    }
    
    func supportedOperations() -> [String] {
        return [
            QueryWithPartitionKey,
            QueryWithPartitionKeyAndFilter,
            QueryWithPartitionKeyAndSortKey,
            QueryWithPartitionKeyAndSortKeyAndFilter,
        ]
    }
    
    func queryWithPartitionKeyDescription() -> String {
        let partitionKeyValue = AWSIdentityManager.default().identityId!
        return "Find all items with userId = \(partitionKeyValue)."
    }
    
    func queryWithPartitionKeyWithCompletionHandler(_ completionHandler: @escaping (_ response: AWSDynamoDBPaginatedOutput?, _ error: NSError?) -> Void) {
        let objectMapper = AWSDynamoDBObjectMapper.default()
        let queryExpression = AWSDynamoDBQueryExpression()
        
        queryExpression.keyConditionExpression = "#userId = :userId"
        queryExpression.expressionAttributeNames = ["#userId": "userId",]
        queryExpression.expressionAttributeValues = [":userId": AWSIdentityManager.default().identityId!,]

        objectMapper.query(News.self, expression: queryExpression) { (response: AWSDynamoDBPaginatedOutput?, error: Error?) in
            DispatchQueue.main.async(execute: {
                completionHandler(response, error as? NSError)
            })
        }
    }
    
    func queryWithPartitionKeyAndFilterDescription() -> String {
        let partitionKeyValue = AWSIdentityManager.default().identityId!
        let filterAttributeValue = "demo-author-500000"
        return "Find all items with userId = \(partitionKeyValue) and author > \(filterAttributeValue)."
    }
    
    func queryWithPartitionKeyAndFilterWithCompletionHandler(_ completionHandler: @escaping (_ response: AWSDynamoDBPaginatedOutput?, _ error: NSError?) -> Void) {
        let objectMapper = AWSDynamoDBObjectMapper.default()
        let queryExpression = AWSDynamoDBQueryExpression()
        
        queryExpression.keyConditionExpression = "#userId = :userId"
        queryExpression.filterExpression = "#author > :author"
        queryExpression.expressionAttributeNames = [
            "#userId": "userId",
            "#author": "author",
        ]
        queryExpression.expressionAttributeValues = [
            ":userId": AWSIdentityManager.default().identityId!,
            ":author": "demo-author-500000",
        ]
        

        objectMapper.query(News.self, expression: queryExpression, completionHandler: {(response: AWSDynamoDBPaginatedOutput?, error: Error?) in
            DispatchQueue.main.async(execute: {
                completionHandler(response, error as? NSError)
            })
        })
    }
    
    func queryWithPartitionKeyAndSortKeyDescription() -> String {
        let partitionKeyValue = AWSIdentityManager.default().identityId!
        let sortKeyValue = "demo-articleId-500000"
        return "Find all items with userId = \(partitionKeyValue) and articleId < \(sortKeyValue)."
    }
    
    func queryWithPartitionKeyAndSortKeyWithCompletionHandler(_ completionHandler: @escaping (_ response: AWSDynamoDBPaginatedOutput?, _ error: NSError?) -> Void) {
        let objectMapper = AWSDynamoDBObjectMapper.default()
        let queryExpression = AWSDynamoDBQueryExpression()
        
        queryExpression.keyConditionExpression = "#userId = :userId AND #articleId < :articleId"
        queryExpression.expressionAttributeNames = [
            "#userId": "userId",
            "#articleId": "articleId",
        ]
        queryExpression.expressionAttributeValues = [
            ":userId": AWSIdentityManager.default().identityId!,
            ":articleId": "demo-articleId-500000",
        ]
        

        objectMapper.query(News.self, expression: queryExpression, completionHandler: {(response: AWSDynamoDBPaginatedOutput?, error: Error?) -> Void in
            DispatchQueue.main.async(execute: {
                completionHandler(response, error as? NSError)
            })
        })
    }
    
    func queryWithPartitionKeyAndSortKeyAndFilterDescription() -> String {
        let partitionKeyValue = AWSIdentityManager.default().identityId!
        let sortKeyValue = "demo-articleId-500000"
        let filterValue = "demo-author-500000"
        return "Find all items with userId = \(partitionKeyValue), articleId < \(sortKeyValue), and author > \(filterValue)."
    }
    
    func queryWithPartitionKeyAndSortKeyAndFilterWithCompletionHandler(_ completionHandler: @escaping (_ response: AWSDynamoDBPaginatedOutput?, _ error: NSError?) -> Void) {
        let objectMapper = AWSDynamoDBObjectMapper.default()
        let queryExpression = AWSDynamoDBQueryExpression()
        
        queryExpression.keyConditionExpression = "#userId = :userId AND #articleId < :articleId"
        queryExpression.filterExpression = "#author > :author"
        queryExpression.expressionAttributeNames = [
            "#userId": "userId",
            "#articleId": "articleId",
            "#author": "author",
        ]
        queryExpression.expressionAttributeValues = [
            ":userId": AWSIdentityManager.default().identityId!,
            ":articleId": "demo-articleId-500000",
            ":author": "demo-author-500000",
        ]
        

        objectMapper.query(News.self, expression: queryExpression, completionHandler: {(response: AWSDynamoDBPaginatedOutput?, error: Error?) in
            DispatchQueue.main.async(execute: {
                completionHandler(response, error as? NSError)
            })
        })
    }
}

class NewsCategories: NSObject, Index {
    
    var indexName: String? {

        return "Categories"
    }
    
    func supportedOperations() -> [String] {
        return [
            QueryWithPartitionKey,
            QueryWithPartitionKeyAndFilter,
            QueryWithPartitionKeyAndSortKey,
            QueryWithPartitionKeyAndSortKeyAndFilter,
        ]
    }
    
    func queryWithPartitionKeyDescription() -> String {
        let partitionKeyValue = "demo-category-3"
        return "Find all items with category = \(partitionKeyValue)."
    }
    
    func queryWithPartitionKeyWithCompletionHandler(_ completionHandler: @escaping (_ response: AWSDynamoDBPaginatedOutput?, _ error: NSError?) -> Void) {
        let objectMapper = AWSDynamoDBObjectMapper.default()
        let queryExpression = AWSDynamoDBQueryExpression()
        

        queryExpression.indexName = "Categories"
        queryExpression.keyConditionExpression = "#category = :category"
        queryExpression.expressionAttributeNames = ["#category": "category",]
        queryExpression.expressionAttributeValues = [":category": "demo-category-3",]

        objectMapper.query(News.self, expression: queryExpression) { (response: AWSDynamoDBPaginatedOutput?, error: Error?) in
            DispatchQueue.main.async(execute: {
                completionHandler(response, error as? NSError)
            })
        }
    }
    
    func queryWithPartitionKeyAndFilterDescription() -> String {
        let partitionKeyValue = "demo-category-3"
        let filterAttributeValue = "demo-articleId-500000"
        return "Find all items with category = \(partitionKeyValue) and articleId > \(filterAttributeValue)."
    }
    
    func queryWithPartitionKeyAndFilterWithCompletionHandler(_ completionHandler: @escaping (_ response: AWSDynamoDBPaginatedOutput?, _ error: NSError?) -> Void) {
        let objectMapper = AWSDynamoDBObjectMapper.default()
        let queryExpression = AWSDynamoDBQueryExpression()
        

        queryExpression.indexName = "Categories"
        queryExpression.keyConditionExpression = "#category = :category"
        queryExpression.filterExpression = "#articleId > :articleId"
        queryExpression.expressionAttributeNames = [
            "#category": "category",
            "#articleId": "articleId",
        ]
        queryExpression.expressionAttributeValues = [
            ":category": "demo-category-3",
            ":articleId": "demo-articleId-500000",
        ]
        

        objectMapper.query(News.self, expression: queryExpression, completionHandler: {(response: AWSDynamoDBPaginatedOutput?, error: Error?) in
            DispatchQueue.main.async(execute: {
                completionHandler(response, error as? NSError)
            })
        })
    }
    
    func queryWithPartitionKeyAndSortKeyDescription() -> String {
        let partitionKeyValue = "demo-category-3"
        let sortKeyValue = 1111500000
        return "Find all items with category = \(partitionKeyValue) and creationDate < \(sortKeyValue)."
    }
    
    func queryWithPartitionKeyAndSortKeyWithCompletionHandler(_ completionHandler: @escaping (_ response: AWSDynamoDBPaginatedOutput?, _ error: NSError?) -> Void) {
        let objectMapper = AWSDynamoDBObjectMapper.default()
        let queryExpression = AWSDynamoDBQueryExpression()
        

        queryExpression.indexName = "Categories"
        queryExpression.keyConditionExpression = "#category = :category AND #creationDate < :creationDate"
        queryExpression.expressionAttributeNames = [
            "#category": "category",
            "#creationDate": "creationDate",
        ]
        queryExpression.expressionAttributeValues = [
            ":category": "demo-category-3",
            ":creationDate": 1111500000,
        ]
        

        objectMapper.query(News.self, expression: queryExpression, completionHandler: {(response: AWSDynamoDBPaginatedOutput?, error: Error?) -> Void in
            DispatchQueue.main.async(execute: {
                completionHandler(response, error as? NSError)
            })
        })
    }
    
    func queryWithPartitionKeyAndSortKeyAndFilterDescription() -> String {
        let partitionKeyValue = "demo-category-3"
        let sortKeyValue = 1111500000
        let filterValue = "demo-articleId-500000"
        return "Find all items with category = \(partitionKeyValue), creationDate < \(sortKeyValue), and articleId > \(filterValue)."
    }
    
    func queryWithPartitionKeyAndSortKeyAndFilterWithCompletionHandler(_ completionHandler: @escaping (_ response: AWSDynamoDBPaginatedOutput?, _ error: NSError?) -> Void) {
        let objectMapper = AWSDynamoDBObjectMapper.default()
        let queryExpression = AWSDynamoDBQueryExpression()
        

        queryExpression.indexName = "Categories"
        queryExpression.keyConditionExpression = "#category = :category AND #creationDate < :creationDate"
        queryExpression.filterExpression = "#articleId > :articleId"
        queryExpression.expressionAttributeNames = [
            "#category": "category",
            "#creationDate": "creationDate",
            "#articleId": "articleId",
        ]
        queryExpression.expressionAttributeValues = [
            ":category": "demo-category-3",
            ":creationDate": 1111500000,
            ":articleId": "demo-articleId-500000",
        ]
        

        objectMapper.query(News.self, expression: queryExpression, completionHandler: {(response: AWSDynamoDBPaginatedOutput?, error: Error?) in
            DispatchQueue.main.async(execute: {
                completionHandler(response, error as? NSError)
            })
        })
    }
}
