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

import LanguageServerProtocol
import BuildServerProtocol

extension SourceKitServer {

  public func onSchemeChange(buildScheme: BuildScheme, workspace: Workspace) {
    guard workspace.explicitIndexMode else {
      return
    }
    collectTransitiveDependencies(
      buildScheme: buildScheme,
      workspace: workspace) { targets in
        self.limitIndexVisibility(targets: targets, workspace: workspace)
    }
  }
  
  func collectTransitiveDependencies(
    buildScheme: BuildScheme,
    workspace: Workspace,
    callback: @escaping ([BuildTargetIdentifier]) -> Void
  ) {
    workspace.buildSystemManager.buildTargets { targetsResponse in
      guard case let .success(targets) = targetsResponse else {
        callback([])
        return
      }
      let targetMap = targets.reduce(into: [BuildTargetIdentifier: BuildTarget]()) {
        $0[$1.id] = $1
      }
      var topLevelTargets = buildScheme.targets
      var transitiveDeps = Set<BuildTargetIdentifier>()
      while !topLevelTargets.isEmpty {
        let targetID = topLevelTargets.removeLast()
        if !transitiveDeps.contains(targetID), let target = targetMap[targetID] {
          topLevelTargets.insert(contentsOf: target.dependencies, at: 0)
        }
        transitiveDeps.insert(targetID)
      }
      callback(Array(transitiveDeps))
    }
  }
  
  func limitIndexVisibility(targets: [BuildTargetIdentifier], workspace: Workspace) {
    workspace.buildSystemManager.buildTargetOutputPaths(targets: targets) { response in
    switch response {
    case .success(let items):
      let currentOutputs = self.schemeOutputs
      let newOutputs = Set(items.flatMap {$0.outputPaths})
      self.schemeOutputs = newOutputs
      let outputsToRemove = currentOutputs.subtracting(newOutputs).map {$0.pseudoPath}
      let outputsToAdd = newOutputs.subtracting(currentOutputs).map {$0.pseudoPath}
      workspace.index?.removeUnitOutFilePaths(outputsToRemove, waitForProcessing: false)
      workspace.index?.addUnitOutFilePaths(outputsToAdd, waitForProcessing: false)
    case .failure(_):
      break
    }}
  }
}
