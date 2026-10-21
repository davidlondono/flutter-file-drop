import Flutter
import MobileCoreServices
import UniformTypeIdentifiers
import UIKit

public class FlutterFileDropIosPlugin: NSObject, FlutterPlugin, FlutterStreamHandler, UIDropInteractionDelegate, DropFileHostApi {
  private let eventChannelName = "flutter_file_drop/events"
  private var eventSink: FlutterEventSink?
  private var interaction: UIDropInteraction?
  private var activeSessions: [ObjectIdentifier: String] = [:]
  private var files: [String: [String: URL]] = [:]
  private var sessionDirectories: [String: URL] = [:]
  private let fileURLTypeIdentifier = "public.file-url"
  private let folderTypeIdentifier = "public.folder"

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = FlutterFileDropIosPlugin()
    FlutterEventChannel(name: instance.eventChannelName, binaryMessenger: registrar.messenger())
      .setStreamHandler(instance)
    DropFileHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: instance)
    let interaction = UIDropInteraction(delegate: instance)
    registrar.viewController?.view.addInteraction(interaction)
    instance.interaction = interaction
  }

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  public func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
    guard eventSink != nil else { return false }
    return session.items.contains { item in
      isFileProvider(item.itemProvider) || stringType(for: item.itemProvider) != nil
    }
  }

  public func dropInteraction(_ interaction: UIDropInteraction, sessionDidEnter session: UIDropSession) {
    _ = sessionIdentifier(for: session)
    emit(type: "enter", session: session, in: interaction.view, includeValues: false)
  }

  public func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
    _ = sessionIdentifier(for: session)
    emit(type: "move", session: session, in: interaction.view, includeValues: false)
    return UIDropProposal(operation: .copy)
  }

  public func dropInteraction(_ interaction: UIDropInteraction, sessionDidExit session: UIDropSession) {
    emit(type: "leave", session: session, in: interaction.view, includeValues: false)
    activeSessions.removeValue(forKey: ObjectIdentifier(session as AnyObject))
  }

  public func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
    let sessionId = sessionIdentifier(for: session)
    guard let view = interaction.view else {
      activeSessions.removeValue(forKey: ObjectIdentifier(session as AnyObject))
      return
    }
    Task { @MainActor in
      let items = await self.loadItems(session.items, sessionId: sessionId)
      self.emit(
        type: "drop",
        sessionId: sessionId,
        location: session.location(in: view),
        items: items
      )
      self.activeSessions.removeValue(forKey: ObjectIdentifier(session as AnyObject))
    }
  }

  func readFileChunk(sessionId: String, fileHandle: String, readId: String, offset: Int64, maxBytes: Int64) async throws -> FlutterStandardTypedData? {
    guard offset >= 0, maxBytes > 0, maxBytes <= 64 * 1024,
          let url = files[sessionId]?[fileHandle] else {
      return nil
    }
    let file = try FileHandle(forReadingFrom: url)
    defer { try? file.close() }
    try file.seek(toOffset: UInt64(offset))
    let data = file.readData(ofLength: Int(maxBytes))
    guard !data.isEmpty else {
      return nil
    }
    return FlutterStandardTypedData(bytes: data)
  }

  func releaseFileReadStream(sessionId: String, fileHandle: String, readId: String) async throws {}

  func releaseSession(sessionId: String) async throws {
    files.removeValue(forKey: sessionId)
    if let directory = sessionDirectories.removeValue(forKey: sessionId) {
      try? FileManager.default.removeItem(at: directory)
    }
  }

  private func sessionIdentifier(for session: UIDropSession) -> String {
    let key = ObjectIdentifier(session as AnyObject)
    if let sessionId = activeSessions[key] { return sessionId }
    let sessionId = "ios-" + UUID().uuidString
    activeSessions[key] = sessionId
    return sessionId
  }

  private func isFileProvider(_ provider: NSItemProvider) -> Bool {
    provider.hasItemConformingToTypeIdentifier(fileURLTypeIdentifier) ||
      provider.hasItemConformingToTypeIdentifier(folderTypeIdentifier)
  }

  private func stringType(for provider: NSItemProvider) -> (identifier: String, mime: String)? {
    for identifier in provider.registeredTypeIdentifiers {
      guard let mime = preferredMIMEType(for: identifier) else { continue }
      if ["text/plain", "text/html", "text/uri-list"].contains(mime.lowercased()) {
        return (identifier, mime.lowercased())
      }
    }
    return nil
  }

  private func preferredMIMEType(for identifier: String) -> String? {
    if #available(iOS 14.0, *) {
      return UTType(identifier)?.preferredMIMEType
    } else {
      return UTTypeCopyPreferredTagWithClass(identifier as CFString, kUTTagClassMIMEType)?
        .takeRetainedValue() as String?
    }
  }

  private func metadata(for provider: NSItemProvider) -> [String: Any] {
    var item: [String: Any] = ["type": "file"]
    if let name = provider.suggestedName { item["name"] = name }
    if let mime = provider.registeredTypeIdentifiers
      .compactMap({ preferredMIMEType(for: $0)?.lowercased() })
      .first(where: { !$0.hasPrefix("text/") }) {
      item["mimeType"] = mime
    }
    if provider.hasItemConformingToTypeIdentifier(folderTypeIdentifier) {
      item["isDirectory"] = true
    }
    return item
  }

  private func emit(type: String, session: UIDropSession, in view: UIView?, includeValues: Bool) {
    guard let view else { return }
    let sessionId = sessionIdentifier(for: session)
    let items = session.items.compactMap { dragItem -> [String: Any]? in
      let provider = dragItem.itemProvider
      if isFileProvider(provider) { return metadata(for: provider) }
      guard let string = stringType(for: provider) else { return nil }
      return ["type": "string", "mimeType": string.mime]
    }
    emit(type: type, sessionId: sessionId, location: session.location(in: view), items: items)
  }

  private func emit(type: String, sessionId: String, location: CGPoint, items: [[String: Any]]) {
    eventSink?([
      "sessionId": sessionId,
      "type": type,
      "globalX": Double(location.x),
      "globalY": Double(location.y),
      "items": items,
    ])
  }

  private func loadItems(_ dragItems: [UIDragItem], sessionId: String) async -> [[String: Any]] {
    var result: [[String: Any]] = []
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("flutter_file_drop", isDirectory: true)
      .appendingPathComponent(sessionId, isDirectory: true)
    sessionDirectories[sessionId] = directory

    for (index, dragItem) in dragItems.enumerated() {
      let provider = dragItem.itemProvider
      if isFileProvider(provider) {
        var item = metadata(for: provider)
        if item["isDirectory"] as? Bool == true {
          result.append(item)
          continue
        }
        let identifier = provider.hasItemConformingToTypeIdentifier(fileURLTypeIdentifier)
          ? fileURLTypeIdentifier
          : folderTypeIdentifier
        if let url = await loadFile(provider, typeIdentifier: identifier, to: directory, name: "file-\(index)"),
           let attributes = try? FileManager.default.attributesOfItem(atPath: url.path) {
          let handle = String(index)
          files[sessionId, default: [:]][handle] = url
          item["handle"] = handle
          item["size"] = attributes[.size] as? Int
          if item["name"] == nil { item["name"] = url.lastPathComponent }
          if let date = attributes[.modificationDate] as? Date {
            item["lastModifiedMilliseconds"] = Int(date.timeIntervalSince1970 * 1000)
          }
        } else {
          item["accessDenied"] = true
        }
        result.append(item)
        continue
      }

      guard let string = stringType(for: provider) else { continue }
      var item: [String: Any] = ["type": "string", "mimeType": string.mime]
      if let data = await loadData(provider, typeIdentifier: string.identifier),
         let value = String(data: data, encoding: .utf8) {
        item["value"] = value
      } else {
        item["accessDenied"] = true
      }
      result.append(item)
    }
    return result
  }

  private func loadFile(_ provider: NSItemProvider, typeIdentifier: String, to directory: URL, name: String) async -> URL? {
    await withCheckedContinuation { continuation in
      provider.loadInPlaceFileRepresentation(forTypeIdentifier: typeIdentifier) { source, _, _ in
        guard let source else {
          continuation.resume(returning: nil)
          return
        }
        var stagedFile: URL?
        var coordinationError: NSError?
        NSFileCoordinator(filePresenter: nil).coordinate(
          readingItemAt: source,
          options: [],
          error: &coordinationError
        ) { coordinatedURL in
          do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let destination = directory.appendingPathComponent(name)
            try FileManager.default.copyItem(at: coordinatedURL, to: destination)
            stagedFile = destination
          } catch {
            stagedFile = nil
          }
        }
        continuation.resume(returning: coordinationError == nil ? stagedFile : nil)
      }
    }
  }

  private func loadData(_ provider: NSItemProvider, typeIdentifier: String) async -> Data? {
    await withCheckedContinuation { continuation in
      provider.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { data, _ in
        continuation.resume(returning: data)
      }
    }
  }
}
