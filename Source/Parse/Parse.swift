//
//  Created by Pierluigi Cifani on 04/06/15.
//  Copyright (c) 2015 Blurred Software SL. All rights reserved.
//

import Decodable
import Deferred

private let ParseSubmoduleName = "parse"
private let ParseQueue = queueForSubmodule(ParseSubmoduleName)

public func parseDataAsync<T : Decodable>(data:NSData) -> Future<Result<T>> {
    
    let deferred = Deferred<Result<T>>()
    
    dispatch_async(ParseQueue) {
        deferred.fill(parseData(data))
    }
    
    return Future(deferred)
}


public func parseDataAsync<T : Decodable>(data:NSData) -> Future<Result<[T]>> {
    
    let deferred = Deferred<Result<[T]>>()

    dispatch_async(ParseQueue) {
        deferred.fill(parseData(data))
    }
    
    return Future(deferred)
}

public func parseData<T : Decodable>(data:NSData) -> Result<T> {

    guard let j = try? NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments) else {
        return Result(error: DataParseErrorKind.MalformedJSON)
    }
    
    return parseJSON(j)
}

public func parseData<T : Decodable>(data:NSData) -> Result<[T]> {
    
    guard let j = try? NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments) else {
        return Result(error: DataParseErrorKind.MalformedJSON)
    }
    
    return parseJSON(j)
}

public func parseJSON<T : Decodable>(j:AnyObject) -> Result<T> {
    let result : Result<T>
    do {
        let output : T = try T.decode(j)
        result = Result(output)
    } catch let error {
        
        if let typeMismatchError = error as? TypeMismatchError {
            print("*ERROR* decoding, type \(typeMismatchError.receivedType) mismatched, expected \(typeMismatchError.expectedType) type")
            result = Result(error: DataParseErrorKind.MalformedSchema)
        } else if let missingKeyError = error as? MissingKeyError {
            print("*ERROR* decoding, key \(missingKeyError.key) is missing")
            result = Result(error: DataParseErrorKind.MalformedSchema)
        } else {
            result = Result(error: DataParseErrorKind.UnknownError)
        }
    }
    
    return result
}

public func parseJSON<T : Decodable>(j:AnyObject) -> Result<[T]> {
    let result : Result<[T]>
    do {
        let output : [T] = try [T].decode(j)
        result = Result(output)
    } catch let error {
    
        if let typeMismatchError = error as? TypeMismatchError {
            print("*ERROR* decoding, type \(typeMismatchError.receivedType) mismatched, expected \(typeMismatchError.expectedType) type")
            result = Result(error: DataParseErrorKind.MalformedSchema)
        } else if let missingKeyError = error as? MissingKeyError {
            print("*ERROR* decoding, key \(missingKeyError.key) is missing")
            result = Result(error: DataParseErrorKind.MalformedSchema)
        } else {
            result = Result(error: DataParseErrorKind.UnknownError)
        }
    }
    
    return result
}

//MARK: ErrorType

public enum DataParseErrorKind: ResultErrorType {
    case MalformedJSON
    case MalformedSchema
    case UnknownError
}

//MARK: Foundation Types

extension NSDate : Decodable {
    public class func decode(j: AnyObject) throws -> Self {
        
        guard let epochTime = j as? Double else {
            throw TypeMismatchError(expectedType: String.self, receivedType: j.dynamicType, object: j)
        }
        
        return self.init(timeIntervalSince1970: epochTime)
    }
}
