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
    let transitiveDependenciesCallback: ([BuildTargetIdentifier]) -> Void = {
      self.limitIndexVisibility(targets: $0, workspace: workspace)
    }
    collectTransitiveDependencies(
      buildScheme: buildScheme,
      workspace: workspace,
      callback: transitiveDependenciesCallback
    )
  }
  
  func collectTransitiveDependencies(
    buildScheme: BuildScheme,
    workspace: Workspace,
    callback: @escaping ([BuildTargetIdentifier]) -> Void
  ) {
    workspace.buildSystemManager.buildTargets { targetsResponse in
      guard case let .success(targets) = targetsResponse else {
        // TODO: Response error handling
        callback([])
        return
      }
      let targetMap = targets.reduce(into: [BuildTargetIdentifier: BuildTarget]()) {
        $0[$1.id] = $1
      }
      var topLevelTargets = buildScheme.targets
      var transitiveDeps = Set<BuildTargetIdentifier>()
      while !topLevelTargets.isEmpty {
        let targetID = topLevelTargets.popLast()!
        // TODO: Error handling if selected target is not presented in the map
        if let target = targetMap[targetID] {
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
      let unitOutputsToRemove = self.schemeOutputs.values.flatMap {$0}
      workspace.index?.removeUnitOutFilePaths(unitOutputsToRemove, waitForProcessing: false)
      self.schemeOutputs.removeAll()
      var unitOutputsToAdd: [String] = []
      items.forEach { item in
        item.outputPaths.forEach { outputPathURI in
          if outputPathURI.pseudoPath.hasSuffix(".o") {
            unitOutputsToAdd.append(outputPathURI.pseudoPath)
            self.schemeOutputs[item.target] = self.schemeOutputs[item.target, default:[]] + [outputPathURI.pseudoPath]
          }
        }
      }
      workspace.index?.addUnitOutFilePaths(unitOutputsToAdd, waitForProcessing: false)
    case .failure(_):
      break
    }}
  }
}
