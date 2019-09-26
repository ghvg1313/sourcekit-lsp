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

import SKSupport
import SKCore
import TSCBasic
import LanguageServerProtocol
import LanguageServerProtocolJSONRPC
import Foundation

/// A thin wrapper over a connection to a clangd server providing build setting handling.
final class ClangLanguageServerShim: LanguageServer {

  let clangd: Connection

  var capabilities: ServerCapabilities? = nil

  let buildSystem: BuildSystem

  let clang: AbsolutePath?

  /// Creates a language server for the given client using the sourcekitd dylib at the specified path.
  public init(client: Connection, clangd: Connection, buildSystem: BuildSystem,
              clang: AbsolutePath?) throws {
    self.clangd = clangd
    self.buildSystem = buildSystem
    self.clang = clang
    super.init(client: client)
  }

  public override func _registerBuiltinHandlers() {
    _register(ClangLanguageServerShim.initialize)
    _register(ClangLanguageServerShim.didChangeConfiguration)
    _register(ClangLanguageServerShim.openDocument)
    _register(ClangLanguageServerShim.foldingRange)
  }

  public override func _handleUnknown<R>(_ req: Request<R>) {
    if req.clientID == ObjectIdentifier(clangd) {
      forwardRequest(req, to: client)
    } else {
      forwardRequest(req, to: clangd)
    }
  }

  public override func _handleUnknown<N>(_ note: Notification<N>) {
    if note.clientID == ObjectIdentifier(clangd) {
      client.send(note.params)
    } else {
      clangd.send(note.params)
    }
  }

  /// Forwards a request to the given connection, taking care of replying to the original request
  /// and cancellation, while providing a callback with the response for additional processing.
  ///
  /// Immediately after `handler` returns, this passes the result to the original reply handler by
  /// calling `request.reply(result)`.
  ///
  /// The cancellation token from the original request is automatically linked to the forwarded
  /// request such that cancelling the original request will cancel the forwarded request.
  ///
  /// - Parameters:
  ///   - request: The request to forward.
  ///   - to: Where to forward the request (e.g. self.clangd).
  ///   - handler: An optional closure that will be called with the result of the request.
  func forwardRequest<R>(
    _ request: Request<R>,
    to: Connection,
    _ handler: ((LSPResult<R.Response>) -> Void)? = nil)
  {
    let id = to.send(request.params, queue: queue) { result in
      handler?(result)
      request.reply(result)
    }
    request.cancellationToken.addCancellationHandler {
      to.send(CancelRequest(id: id))
    }
  }
}

// MARK: - Request and notification handling

extension ClangLanguageServerShim {

  func initialize(_ req: Request<InitializeRequest>) {
    forwardRequest(req, to: clangd) { result in
      self.capabilities = result.success?.capabilities
    }
  }

  // MARK: - Workspace

  func didChangeConfiguration(_ note: Notification<DidChangeConfiguration>) {
    switch note.params.settings {
    case .clangd:
      break
    case .documentUpdated(let settings):
      updateDocumentSettings(url: settings.url, language: settings.language)
    case .client(_), .unknown:
      break
    }
  }

  // MARK: - Text synchronization

  func openDocument(_ note: Notification<DidOpenTextDocument>) {
    let textDocument = note.params.textDocument
    updateDocumentSettings(url: textDocument.url, language: textDocument.language)
    clangd.send(note.params)
  }

  private func updateDocumentSettings(url: URL, language: Language) {
    let settings = buildSystem.settings(for: url, language)

    logAsync(level: settings == nil ? .warning : .debug) { _ in
      let settingsStr = settings == nil ? "nil" : settings!.compilerArguments.description
      return "settings for \(url): \(settingsStr)"
    }

    if let settings = settings {
      clangd.send(DidChangeConfiguration(settings: .clangd(
        ClangWorkspaceSettings(
          compilationDatabaseChanges: [url.path: ClangCompileCommand(settings, clang: clang)]))))
    }
  }

  func foldingRange(_ req: Request<FoldingRangeRequest>) {
    if capabilities?.foldingRangeProvider == true {
      forwardRequest(req, to: clangd)
    } else {
      req.reply(.success(nil))
    }
  }
}

func makeJSONRPCClangServer(client: MessageHandler, toolchain: Toolchain, buildSettings: BuildSystem?) throws -> Connection {

  guard let clangd = toolchain.clangd else {
    preconditionFailure("missing clang from toolchain \(toolchain.identifier)")
  }

  let clientToServer: Pipe = Pipe()
  let serverToClient: Pipe = Pipe()

  let connection = JSONRPCConection(
    protocol: MessageRegistry.lspProtocol,
    inFD: serverToClient.fileHandleForReading.fileDescriptor,
    outFD: clientToServer.fileHandleForWriting.fileDescriptor
  )

  let connectionToShim = LocalConnection()
  let connectionToClient = LocalConnection()

  let shim = try ClangLanguageServerShim(
    client: connectionToClient,
    clangd: connection,
    buildSystem: buildSettings ?? BuildSystemList(),
    clang: toolchain.clang)

  connectionToShim.start(handler: shim)
  connectionToClient.start(handler: client)
  connection.start(receiveHandler: shim)

  let process = Foundation.Process()

  if #available(OSX 10.13, *) {
    process.executableURL = clangd.asURL
  } else {
    process.launchPath = clangd.pathString
  }

  process.arguments = [
    "-compile_args_from=lsp", // Provide compiler args programmatically.
  ]
  process.standardOutput = serverToClient
  process.standardInput = clientToServer
  process.terminationHandler = { process in
    log("clangd exited: \(process.terminationReason) \(process.terminationStatus)")
    connection.close()
  }

  if #available(OSX 10.13, *) {
    try process.run()
  } else {
    process.launch()
  }

  return connectionToShim
}

extension ClangCompileCommand {
  init(_ settings: FileBuildSettings, clang: AbsolutePath?) {
    // Clang expects the first argument to be the program name, like argv.
    self.init(
      compilationCommand: [clang?.pathString ?? "clang"] + settings.compilerArguments,
      workingDirectory: settings.workingDirectory ?? "")
  }
}
