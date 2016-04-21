//  Copyright (c) 2015 Rob Rix. All rights reserved.

/// An enum representing either a failure with an explanatory error, or a success with a result value.
public enum Result<T>: ResultType, CustomStringConvertible, CustomDebugStringConvertible {
	case Success(T)
	case Failure(ResultErrorType)

	// MARK: Constructors

	/// Constructs a success wrapping a `value`.
	public init(value: T) {
		self = .Success(value)
	}

	/// Constructs a failure wrapping an `error`.
	public init(error: ResultErrorType) {
		self = .Failure(error)
	}

	/// Constructs a result from an Optional, failing with `Error` if `nil`.
	public init(_ value: T?, @autoclosure failWith: () -> ResultErrorType) {
		self = value.map(Result.Success) ?? .Failure(failWith())
	}

	/// Constructs a result from a function that uses `throw`, failing with `Error` if throws.
	public init(@autoclosure _ f: () throws -> T) {
		self.init(attempt: f)
	}

	/// Constructs a result from a function that uses `throw`, failing with `Error` if throws.
	public init(@noescape attempt f: () throws -> T) {
		do {
			self = .Success(try f())
		} catch {
			self = .Failure(error)
		}
	}

	// MARK: Deconstruction

	/// Returns the value from `Success` Results or `throw`s the error.
	public func dematerialize() throws -> T {
		switch self {
		case let .Success(value):
			return value
		case let .Failure(error):
			throw error
		}
	}

	/// Case analysis for Result.
	///
	/// Returns the value produced by applying `ifFailure` to `Failure` Results, or `ifSuccess` to `Success` Results.
	public func analysis<Result>(@noescape ifSuccess ifSuccess: T -> Result, @noescape ifFailure: ResultErrorType -> Result) -> Result {
		switch self {
		case let .Success(value):
			return ifSuccess(value)
		case let .Failure(value):
			return ifFailure(value)
		}
	}


	// MARK: Higher-order functions
	
	/// Returns `self.value` if this result is a .Success, or the given value otherwise. Equivalent with `??`
	public func recover(@autoclosure value: () -> T) -> T {
		return self.value ?? value()
	}
	
	/// Returns this result if it is a .Success, or the given result otherwise. Equivalent with `??`
	public func recoverWith(@autoclosure result: () -> Result<T>) -> Result<T> {
		return analysis(
			ifSuccess: { _ in self },
			ifFailure: { _ in result() })
	}

	// MARK: Errors

	/// The domain for errors constructed by Result.
	public static var errorDomain: String { return "com.antitypical.Result" }

	/// The userInfo key for source functions in errors constructed by Result.
	public static var functionKey: String { return "\(errorDomain).function" }

	/// The userInfo key for source file paths in errors constructed by Result.
	public static var fileKey: String { return "\(errorDomain).file" }

	/// The userInfo key for source file line numbers in errors constructed by Result.
	public static var lineKey: String { return "\(errorDomain).line" }

	#if os(Linux)
	private typealias UserInfoType = Any
	#else
	private typealias UserInfoType = AnyObject
	#endif

	/// Constructs an error.
	public static func error(message: String? = nil, function: String = #function, file: String = #file, line: Int = #line) -> NSError {
		var userInfo: [String: UserInfoType] = [
			functionKey: function,
			fileKey: file,
			lineKey: line,
		]

		if let message = message {
			userInfo[NSLocalizedDescriptionKey] = message
		}

		return NSError(domain: errorDomain, code: 0, userInfo: userInfo)
	}


	// MARK: CustomStringConvertible

	public var description: String {
		return analysis(
			ifSuccess: { ".Success(\($0))" },
			ifFailure: { ".Failure(\($0))" })
	}


	// MARK: CustomDebugStringConvertible

	public var debugDescription: String {
		return description
	}
}


/// Returns `true` if `left` and `right` are both `Success`es and their values are equal, or if `left` and `right` are both `Failure`s and their errors are equal.
public func == <T: Equatable> (left: Result<T>, right: Result<T>) -> Bool {
	if let left = left.value, right = right.value {
		return left == right
	}
	return false
}

/// Returns `true` if `left` and `right` represent different cases, or if they represent the same case but different values.
public func != <T: Equatable> (left: Result<T>, right: Result<T>) -> Bool {
	return !(left == right)
}


/// Returns the value of `left` if it is a `Success`, or `right` otherwise. Short-circuits.
public func ?? <T> (left: Result<T>, @autoclosure right: () -> T) -> T {
	return left.recover(right())
}

/// Returns `left` if it is a `Success`es, or `right` otherwise. Short-circuits.
public func ?? <T> (left: Result<T>, @autoclosure right: () -> Result<T>) -> Result<T> {
	return left.recoverWith(right())
}

// MARK: - Derive result from failable closure

public func materialize<T>(@noescape f: () throws -> T) -> Result<T> {
	return materialize(try f())
}

public func materialize<T>(@autoclosure f: () throws -> T) -> Result<T> {
	do {
		return .Success(try f())
	} catch let error as NSError {
		return .Failure(error)
	}
}

// MARK: - Cocoa API conveniences

#if !os(Linux)

/// Constructs a Result with the result of calling `try` with an error pointer.
///
/// This is convenient for wrapping Cocoa API which returns an object or `nil` + an error, by reference. e.g.:
///
///     Result.try { NSData(contentsOfURL: URL, options: .DataReadingMapped, error: $0) }
public func `try`<T>(function: String = #function, file: String = #file, line: Int = #line, `try`: NSErrorPointer -> T?) -> Result<T> {
	var error: NSError?
	return `try`(&error).map(Result.Success) ?? .Failure(error ?? Result<T>.error(function: function, file: file, line: line))
}

/// Constructs a Result with the result of calling `try` with an error pointer.
///
/// This is convenient for wrapping Cocoa API which returns a `Bool` + an error, by reference. e.g.:
///
///     Result.try { NSFileManager.defaultManager().removeItemAtURL(URL, error: $0) }
public func `try`(function: String = #function, file: String = #file, line: Int = #line, `try`: NSErrorPointer -> Bool) -> Result<()> {
	var error: NSError?
	return `try`(&error) ?
		.Success(())
	:	.Failure(error ?? Result<()>.error(function: function, file: file, line: line))
}

#endif

// MARK: - Operators

infix operator >>- {
	// Left-associativity so that chaining works like you’d expect, and for consistency with Haskell, Runes, swiftz, etc.
	associativity left

	// Higher precedence than function application, but lower than function composition.
	precedence 100
}

/// Returns the result of applying `transform` to `Success`es’ values, or re-wrapping `Failure`’s errors.
///
/// This is a synonym for `flatMap`.
public func >>- <T, U> (result: Result<T>, @noescape transform: T -> Result<U>) -> Result<U> {
	return result.flatMap(transform)
}


// MARK: - ErrorTypeConvertible conformance

#if !os(Linux)
	
	public extension ErrorTypeConvertible where Self : NSError {
		public func force<T>() -> T {
			return self as! T
		}
	}
	
	extension NSError: ErrorTypeConvertible {
		public static func errorFromErrorType(error: ResultErrorType) -> Self {
			let e = error as NSError
			return e.force()
		}
	}

#endif

// MARK: -

/// An “error” that is impossible to construct.
///
/// This can be used to describe `Result`s where failures will never
/// be generated. For example, `Result<Int, NoError>` describes a result that
/// contains an `Int`eger and is guaranteed never to be a `Failure`.
public enum NoError: ResultErrorType { }

import Foundation
