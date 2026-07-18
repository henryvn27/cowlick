import Foundation

enum ProjectNameResolver {
  static func resolve(workingDirectory: String, fileManager: FileManager = .default) -> String {
    let expanded = NSString(string: workingDirectory).expandingTildeInPath
    var candidate = URL(fileURLWithPath: expanded, isDirectory: true).standardizedFileURL
    let root = URL(fileURLWithPath: "/", isDirectory: true)

    while candidate.path != root.path {
      if fileManager.fileExists(atPath: candidate.appendingPathComponent(".git").path) {
        let name = candidate.lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { return name }
      }
      candidate.deleteLastPathComponent()
    }

    let directoryName = URL(fileURLWithPath: expanded, isDirectory: true).standardizedFileURL
      .lastPathComponent
      .trimmingCharacters(in: .whitespacesAndNewlines)
    return directoryName.isEmpty || directoryName == "/" ? "Codex" : directoryName
  }
}
