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
/// The `settings` field of a `workspace/didChangeConfiguration`.
/// This is a strict implemention of language server protocl, which represents the payload sent from client.
/// The object defination here must match the registered sections in client extension.
public struct ConfigurationSettings: Hashable {
  public let buildServerConfigurations: BuildServerConfigurations
  
  public init(builderServerConfigurations: BuildServerConfigurations) {
    self.buildServerConfigurations = builderServerConfigurations
  }
}

public struct BuildServerConfigurations: Codable, Hashable {
  public let scheme: Scheme?
  public let destination: Destination?
  
  public init(scheme: Scheme?, destination: Destination?) {
    self.scheme = scheme
    self.destination = destination
  }
}

extension ConfigurationSettings: Decodable {
  private enum CodingKeys: String, CodingKey {
      case sourcekitLSP = "sourcekit-lsp"
      case buildServer = "buildServer"
  }
  
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let configuration = try container.nestedContainer(keyedBy: CodingKeys.self, forKey: CodingKeys.sourcekitLSP)
    if let buildServerConfig = try? configuration.decode(BuildServerConfigurations.self, forKey: .buildServer) {
      buildServerConfigurations = buildServerConfig
    } else {
      throw MessageDecodingError.invalidRequest("could not decode malformed build server config")
    }
  }
}
