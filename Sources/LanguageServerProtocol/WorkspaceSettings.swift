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
  case documentUpdated(DocumentUpdatedBuildSettings)
  case client(ConfigurationSettings)
  case unknown

  public init(from decoder: Decoder) throws {
    if let settings = try? ClangWorkspaceSettings(from: decoder) {
      self = .clangd(settings)
    } else if let settings = try? DocumentUpdatedBuildSettings(from: decoder) {
      self = .documentUpdated(settings)
    } else if let settings = try? ConfigurationSettings(from: decoder) {
      self = .client(settings)
    } else {
      self = .unknown
    }
  }

  public func encode(to encoder: Encoder) throws {
    switch self {
    case .clangd(let settings):
      try settings.encode(to: encoder)
    case .documentUpdated(let settings):
      try settings.encode(to: encoder)
    case .client(_), .unknown:
      break // Nothing to do.
    }
  }
}

/// Workspace settings for clangd, represented by a compilation database.
///
/// Clangd will accept *either* a path to a compilation database on disk, or the contents of a
/// compilation database to be managed in-memory, but they cannot be mixed.
public struct ClangWorkspaceSettings: Codable, Hashable {
  private enum CodingKeys: String, CodingKey {
      case compilationDatabasePath = "compilationDatabasePath"
      case compilationDatabaseChanges = "compilationDatabaseChanges"
  }

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
  
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    compilationDatabasePath = try? container.decode(String.self, forKey: .compilationDatabasePath)
    compilationDatabaseChanges = try? container.decode([String: ClangCompileCommand].self, forKey: .compilationDatabaseChanges)
    guard (compilationDatabasePath == nil) != (compilationDatabaseChanges == nil) else {
      throw MessageDecodingError.invalidRequest("ClangWorkspaceSettings can have one and only one valid property")
    }
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

/// Workspace settings for a document that has updated build settings.
public struct DocumentUpdatedBuildSettings: Codable, Hashable {
  /// The url of the document that has updated.
  public var url: URL

   /// The language of the document that has updated.
  public var language: Language

   public init(url: URL, language: Language) {
    self.url = url
    self.language = language
  }
}
