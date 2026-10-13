import Foundation

struct JSONRPCResponseCursor {
  private var lineStart = 0
  private var searchOffset = 0

  private(set) var decodedLineCount = 0
  private(set) var examinedLineCount = 0

  mutating func containsResponse(id: Int, in data: Data) -> Bool {
    if data.count < searchOffset {
      lineStart = 0
      searchOffset = 0
    }

    while searchOffset < data.endIndex {
      guard data[searchOffset] == 0x0A else {
        searchOffset += 1
        continue
      }

      let line = data[lineStart..<searchOffset]
      searchOffset += 1
      lineStart = searchOffset
      examinedLineCount += 1

      guard Self.couldContainJSONObject(line) else { continue }
      decodedLineCount += 1
      guard
        let object = try? JSONSerialization.jsonObject(with: Data(line)),
        let dictionary = object as? [String: Any]
      else { continue }
      if dictionary["id"] as? Int == id { return true }
    }
    return false
  }

  private static func couldContainJSONObject(_ line: Data.SubSequence) -> Bool {
    line.first(where: { !Self.isJSONWhitespace($0) }) == 0x7B
  }

  private static func isJSONWhitespace(_ byte: UInt8) -> Bool {
    byte == 0x20 || byte == 0x09 || byte == 0x0D
  }
}
