//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2020 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import BuildServerProtocol
import LanguageServerProtocol
import LSPTestSupport
import SKCore
import SKTestSupport
import SourceKitLSP
import TSCBasic
import XCTest

final class SchemeChangeTests: XCTestCase {
  
  /// Connection and lifetime management for the service.
  var testServer: TestSourceKitServer! = nil

  /// The primary interface to make requests to the SourceKitServer.
  var sk: TestClient! = nil

  /// The server's workspace data. Accessing this is unsafe if the server does so concurrently.
  var workspace: Workspace! = nil

  /// The build system that we use to verify SourceKitServer behavior.
  var buildSystem: TestBuildSystem! = nil
  
  override func setUp() {
    testServer = TestSourceKitServer()
    buildSystem = TestBuildSystem()

    let server = testServer.server!
    workspace = Workspace(
      rootUri: nil,
      clientCapabilities: ClientCapabilities(),
      toolchainRegistry: ToolchainRegistry.shared,
      buildSetup: TestSourceKitServer.serverOptions.buildSetup,
      underlyingBuildSystem: buildSystem,
      index: nil,
      indexDelegate: nil,
      explicitIndexMode: true)

    server.workspace = workspace
    workspace.buildSystemManager.delegate = server

    sk = testServer.client
    _ = try! sk.sendSync(InitializeRequest(
        processId: nil,
        rootPath: nil,
        rootURI: nil,
        initializationOptions: nil,
        capabilities: ClientCapabilities(workspace: nil, textDocument: nil),
        trace: .off,
        workspaceFolders: nil))
  }
  
  override func tearDown() {
    buildSystem = nil
    workspace = nil
    sk = nil
    testServer = nil
  }
  
  func testSchemeChanged() {
    let targetGraph = mockBuildTargetGraph(targetStringRepr: [
         "target://a:a": [],
         "target://b:b": ["target://a:a"],
         "target://c:c": ["target://b:b"],
         "target://d:d": [],
       ])
       
    buildSystem.targets = targetGraph
     
    let targetOutputResponse: (([BuildTargetIdentifier]) -> [OutputsItem]) = { (targets: [BuildTargetIdentifier]) in
      return targets.compactMap { (targetIdentifier: BuildTargetIdentifier) in
        let outputFile = URI(string: "file:///" + targetIdentifier.uri.stringValue.split(separator: ":").last! + ".swift")
        return OutputsItem(target: targetIdentifier, outputPaths: [outputFile])
      }
    }
    buildSystem.targetOutputs = targetOutputResponse
    
    sk.allowUnexpectedNotification = false
    
    let targetURI = DocumentURI(string: "target://c:c")
    let newBuildScheme = BuildScheme(targets: [BuildTargetIdentifier(uri: targetURI)])
    let schemeChange: WorkspaceSettingsChange = .scheme(newBuildScheme)
    
    sk.send(DidChangeConfigurationNotification(settings: schemeChange))
    
    // Unfortunately there's no callback for scheme change notification from sourcekit server, waiting here for the result
    let expectation = self.expectation(description: "Waiting for scheme change notification handling")
    let result = XCTWaiter.wait(for: [expectation], timeout: 1)
    if result == .timedOut {
      XCTAssertEqual(testServer.server?.schemeOutputs, Set([
        URI(string: "file:///a.swift"),
        URI(string: "file:///b.swift"),
        URI(string: "file:///c.swift"),
      ]))
    } else {
      fatalError("Interrupted while waiting for scheme change notification")
    }
  }
  
  private func mockBuildTargetGraph(targetStringRepr: [String: [String]]) -> [BuildTarget] {
    return targetStringRepr.reduce(into: [BuildTarget]()) {
      $0.append(mockBuildTarget(targetID: $1.key, depsID: $1.value))
    }
  }
  
  private func mockBuildTarget(targetID: String, depsID: [String]) -> BuildTarget {
    return BuildTarget(
      id: BuildTargetIdentifier(uri: DocumentURI(string: targetID)),
      displayName: nil,
      baseDirectory: nil,
      tags: [],
      capabilities: BuildTargetCapabilities(canCompile: false, canTest: false, canRun: false),
      languageIds: [],
      dependencies: depsID.map {BuildTargetIdentifier(uri: DocumentURI(string: $0))}
    )
  }
}
