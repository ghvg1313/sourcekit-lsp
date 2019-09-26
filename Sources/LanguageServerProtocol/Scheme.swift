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
public struct Scheme: ResponseType, Hashable {
  /// Unique identifier for this scheme.
  public let identifier: String

  /// Build configuration to use (e.g. "debug" or "release").
  public let configuration: String?
  
  /// Targets in the given scheme.
  public let targets: [String?]
}

