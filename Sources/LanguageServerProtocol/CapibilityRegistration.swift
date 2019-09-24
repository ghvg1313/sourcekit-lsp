//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2018 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

/// Notification from the server to register for a new capability on the client side.
///
/// - Parameters:
///   - registrations: List of capibilities the server wish to register for.
public struct CapibilityRegistration: RequestType, Hashable {
  public typealias Response = VoidResponse
  
  public static let method: String = "client/registerCapability"
  
  public let registrations: [Registration]
  
  public init(registrations: [Registration]) {
    self.registrations = registrations
  }
}

/// Notification from the server to register for a new capability on the client side.
public struct Registration: Hashable, Codable {
  /// The id used to register the request. The id can be used to deregister the request again.
  public let id: String
  
  /// The method / capability to register for.
  public let method: String
  
  /// Options necessary for the registration.
  public let registerOptions: LSPAny?
  
  public init<T>(requestType: T.Type, registerOptions: LSPAny? = nil) where T: RequestType {
    self.id = requestType.method
    self.method = requestType.method
    self.registerOptions = registerOptions
  }
  
  public init<T>(requestType: T.Type, registerOptions: LSPAny? = nil) where T: NotificationType {
    self.id = requestType.method
    self.method = requestType.method
    self.registerOptions = registerOptions
  }
}
