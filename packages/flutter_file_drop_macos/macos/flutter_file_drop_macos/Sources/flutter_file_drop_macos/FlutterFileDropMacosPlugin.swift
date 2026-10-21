import Cocoa
import FlutterMacOS
import UniformTypeIdentifiers

public class FlutterFileDropMacosPlugin: NSObject, FlutterPlugin, FlutterStreamHandler, DropFileHostApi {
  private var eventSink: FlutterEventSink?
  private var hostView: DropHostView?
  private var currentSessionId: String?
  private var files: [String: [String: (URL, Bool)]] = [:]

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = FlutterFileDropMacosPlugin()
    FlutterEventChannel(name: "flutter_file_drop/events", binaryMessenger: registrar.messenger)
      .setStreamHandler(instance)
    DropFileHostApiSetup.setUp(binaryMessenger: registrar.messenger, api: instance)
    if let view = registrar.view {
      let hostView = DropHostView(frame: view.bounds)
      hostView.autoresizingMask = [.width, .height]
      hostView.plugin = instance
      view.addSubview(hostView, positioned: .above, relativeTo: nil)
      instance.hostView = hostView
    }
  }

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  fileprivate func draggingEntered(_ sender: NSDraggingInfo, in view: NSView) -> NSDragOperation {
    guard eventSink != nil else { return [] }
    currentSessionId = UUID().uuidString
    emit(type: "enter", sender: sender, in: view, includeValues: false)
    return .copy
  }

  fileprivate func draggingUpdated(_ sender: NSDraggingInfo, in view: NSView) -> NSDragOperation {
    guard eventSink != nil else { return [] }
    if currentSessionId == nil { currentSessionId = UUID().uuidString }
    emit(type: "move", sender: sender, in: view, includeValues: false)
    return .copy
  }

  fileprivate func draggingExited(_ sender: NSDraggingInfo, in view: NSView) {
    guard let sessionId = currentSessionId else { return }
    emit(type: "leave", sessionId: sessionId, sender: sender, in: view, items: [])
    currentSessionId = nil
  }

  fileprivate func performDrop(_ sender: NSDraggingInfo, in view: NSView) -> Bool {
    guard eventSink != nil else { return false }
    let sessionId = currentSessionId ?? UUID().uuidString
    let items = makeItems(from: sender.draggingPasteboard, sessionId: sessionId, dropped: true)
    emit(type: "drop", sessionId: sessionId, sender: sender, in: view, items: items)
    currentSessionId = nil
    return true
  }

  func readFileChunk(sessionId: String, fileHandle: String, offset: Int64, maxBytes: Int64) async throws -> FlutterStandardTypedData? {
    guard offset >= 0, maxBytes > 0, maxBytes <= 64 * 1024,
          let url = files[sessionId]?[fileHandle]?.0 else {
      return nil
    }
    let file = try FileHandle(forReadingFrom: url)
    defer { try? file.close() }
    try file.seek(toOffset: UInt64(offset))
    guard let data = try file.read(upToCount: Int(maxBytes)), !data.isEmpty else {
      return nil
    }
    return FlutterStandardTypedData(bytes: data)
  }

  func releaseSession(sessionId: String) async throws {
    for (_, file) in files.removeValue(forKey: sessionId) ?? [:] where file.1 {
      file.0.stopAccessingSecurityScopedResource()
    }
  }

  private func emit(type: String, sender: NSDraggingInfo, in view: NSView, includeValues: Bool) {
    let sessionId = currentSessionId ?? UUID().uuidString
    let items = makeItems(from: sender.draggingPasteboard, sessionId: sessionId, dropped: includeValues)
    emit(type: type, sessionId: sessionId, sender: sender, in: view, items: items)
  }

  private func emit(type: String, sessionId: String, sender: NSDraggingInfo, in view: NSView, items: [[String: Any]]) {
    let point = view.convert(sender.draggingLocation, from: nil)
    eventSink?([
      "sessionId": sessionId,
      "type": type,
      "globalX": Double(point.x),
      "globalY": Double(view.bounds.height - point.y),
      "items": items,
    ])
  }

  private func makeItems(from pasteboard: NSPasteboard, sessionId: String, dropped: Bool) -> [[String: Any]] {
    guard let pasteboardItems = pasteboard.pasteboardItems else { return [] }
    return pasteboardItems.enumerated().map { index, pasteboardItem in
      if let url = fileURL(from: pasteboardItem) {
        var result: [String: Any] = ["type": "file"]
        result["name"] = url.lastPathComponent
        result["path"] = url.path
        let values = try? url.resourceValues(forKeys: [.contentTypeKey, .isDirectoryKey, .fileSizeKey, .contentModificationDateKey])
        let isDirectory = values?.isDirectory ?? false
        if let type = values {
          result["mimeType"] = type.contentType?.preferredMIMEType
          result["size"] = type.fileSize
          if let date = type.contentModificationDate {
            result["lastModifiedMilliseconds"] = Int(date.timeIntervalSince1970 * 1000)
          }
        }
        if isDirectory {
          result["isDirectory"] = true
        } else if dropped {
          let scoped = url.startAccessingSecurityScopedResource()
          do {
            let file = try FileHandle(forReadingFrom: url)
            try file.close()
            files[sessionId, default: [:]][String(index)] = (url, scoped)
            result["handle"] = String(index)
          } catch {
            if scoped { url.stopAccessingSecurityScopedResource() }
            result["accessDenied"] = true
          }
        }
        return result
      }

      guard let (type, mime) = stringType(in: pasteboardItem) else {
        return ["type": "string", "mimeType": "application/octet-stream", "accessDenied": true]
      }
      var result: [String: Any] = ["type": "string", "mimeType": mime]
      if dropped {
        if let value = pasteboardItem.string(forType: type) {
          result["value"] = value
        } else {
          result["accessDenied"] = true
        }
      }
      return result
    }
  }

  private func fileURL(from item: NSPasteboardItem) -> URL? {
    guard let value = item.string(forType: .fileURL), let url = URL(string: value), url.isFileURL else {
      return nil
    }
    return url
  }

  private func stringType(in item: NSPasteboardItem) -> (NSPasteboard.PasteboardType, String)? {
    if item.types.contains(.html) { return (.html, "text/html") }
    if item.types.contains(.string) { return (.string, "text/plain") }
    if item.types.contains(.URL) { return (.URL, "text/uri-list") }
    return nil
  }
}

private final class DropHostView: NSView {
  weak var plugin: FlutterFileDropMacosPlugin?

  override var isOpaque: Bool { false }

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    registerForDraggedTypes([.fileURL, .string, .html, .URL])
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    registerForDraggedTypes([.fileURL, .string, .html, .URL])
  }

  override func hitTest(_ point: NSPoint) -> NSView? {
    guard let type = NSApp.currentEvent?.type,
          [.leftMouseDragged, .rightMouseDragged, .otherMouseDragged].contains(type) else {
      return nil
    }
    return self
  }

  override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
    plugin?.draggingEntered(sender, in: self) ?? []
  }

  override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
    plugin?.draggingUpdated(sender, in: self) ?? []
  }

  override func draggingExited(_ sender: NSDraggingInfo?) {
    guard let sender else { return }
    plugin?.draggingExited(sender, in: self)
  }

  override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
    plugin?.performDrop(sender, in: self) ?? false
  }
}
