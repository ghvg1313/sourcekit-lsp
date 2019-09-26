//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2019 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
/// Represents a build and run destination, such as a simulator or device.
/// It can specify a specific device or general architecture to use for building or output.
public struct Destination: ResponseType, Hashable {
  /// UDID for this destination, either simulator or device.
  public let udid: String?

  /// Destination architecture understood by the build system, eg. x86_64.
  public let architecture: String
  
  /// Destination platform understood by the build system, eg iphoneos.
  public let platform: String
}

