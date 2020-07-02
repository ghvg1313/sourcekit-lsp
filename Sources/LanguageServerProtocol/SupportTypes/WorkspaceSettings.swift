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
///
/// This is typed as `Any` in the protocol, and this enum contains the formats we support.
public enum WorkspaceSettingsChange: Codable, Hashable {

  case clangd(ClangWorkspaceSettings)
  case scheme(BuildScheme)
  case unknown(LSPAny)

  public init(from decoder: Decoder) throws {
    // FIXME: doing trial deserialization only works if we have at least one non-optional unique
    // key, which we don't yet.  For now, assume that if we add another kind of workspace settings
    // it will rectify this issue.
    if let scheme = try? BuildScheme(from: decoder) {
      self = .scheme(scheme)
    } else if let settings = try? ClangWorkspaceSettings(from: decoder) {
      self = .clangd(settings)
    } else {
      let settings = try LSPAny(from: decoder)
      self = .unknown(settings)
    }
  }

  public func encode(to encoder: Encoder) throws {
    switch self {
    case .clangd(let settings):
      try settings.encode(to: encoder)
    case .scheme(let scheme):
      try scheme.encode(to: encoder)
    case .unknown(let settings):
      try settings.encode(to: encoder)
    }
  }
}

/// Workspace settings for clangd, represented by a compilation database.
///
/// Clangd will accept *either* a path to a compilation database on disk, or the contents of a
/// compilation database to be managed in-memory, but they cannot be mixed.
public struct ClangWorkspaceSettings: Codable, Hashable {

  /// The path to a json compilation database.
  public var compilationDatabasePath: String?

  /// Mapping from file name to compilation command.
  public var compilationDatabaseChanges: [String: ClangCompileCommand]?

  public init(
    compilationDatabasePath: String? = nil,
    compilationDatabaseChanges: [String: ClangCompileCommand]? = nil
  ) {
    self.compilationDatabasePath = compilationDatabasePath
    self.compilationDatabaseChanges = compilationDatabaseChanges
  }
}

/// A single compile command for use in a clangd workspace settings.
public struct ClangCompileCommand: Codable, Hashable {

  /// The command (executable + compiler arguments).
  public var compilationCommand: [String]

  /// The directory to perform the compilation in.
  public var workingDirectory: String

  public init(compilationCommand: [String], workingDirectory: String) {
    self.compilationCommand = compilationCommand
    self.workingDirectory = workingDirectory
  }
}

/// Workspace's build scheme, represented by a list of target identifiers
public struct BuildScheme: Codable, Hashable {
  private enum CodingKeys: String, CodingKey {
    case sourcekit_lsp = "sourcekit-lsp"
    case scheme
  }

  /// all targets included in the scheme
  public var targets: [BuildTargetIdentifier]

  public init(targets: [BuildTargetIdentifier]) {
    self.targets = targets
  }
  
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    guard let langExtesnionDict = try? container.nestedContainer(keyedBy: CodingKeys.self, forKey: .sourcekit_lsp) else {
        let context = DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected Build scheme from configuration change notification")
        throw DecodingError.dataCorrupted(context)
    }
    let targetIDs = try langExtesnionDict.decode([String].self, forKey: .scheme)
    self.targets = targetIDs.map {BuildTargetIdentifier(uri: DocumentURI(string: $0))}
  }
  
  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    var langExtesnion = container.nestedContainer(keyedBy: CodingKeys.self, forKey: .sourcekit_lsp)
    let targetIDs = self.targets.map {$0.uri.stringValue}
    try langExtesnion.encode(targetIDs, forKey: .scheme)
  }
}

public struct BuildTargetIdentifier: Codable, Hashable {
  public var uri: DocumentURI

  public init(uri: DocumentURI) {
    self.uri = uri
  }
  
   public init(from decoder: Decoder) throws {
     let uri = DocumentURI(string: try decoder.singleValueContainer().decode(String.self))
     self.init(uri: uri)
   }

   public func encode(to encoder: Encoder) throws {
    try self.uri.encode(to: encoder)
   }
}

