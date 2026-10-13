import Foundation

public protocol ExportWorkspacePort {
    var workspaceDirectory: URL? { get }
    func createCollectionDatabase() throws -> URL
    func createMediaDirectory() throws -> URL
    func stagingFile(for name: String) throws -> URL
    func atomicWrite(to destination: URL) async throws
    func cleanup()
}

public final class AppOwnedExportWorkspace: ExportWorkspacePort {
    private let fileManager: FileManager
    private let queue = DispatchQueue(label: "export.workspace", attributes: .concurrent)
    private var _workspaceDirectory: URL?
    private var isCleanedUp: Bool = false

    public var workspaceDirectory: URL? {
        get { queue.sync { _workspaceDirectory } }
    }

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        createWorkspaceIfNeeded()
    }

    private func createWorkspaceIfNeeded() {
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let workspaceName = "anki-export-\(timestamp)-\(UUID().uuidString.prefix(8))"
        
        let baseTempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("LinguaBrainExport", isDirectory: true)
        
        do {
            if !fileManager.fileExists(atPath: baseTempDir.path) {
                try fileManager.createDirectory(at: baseTempDir, withIntermediateDirectories: true)
            }
            
            let workspaceDir = baseTempDir.appendingPathComponent(workspaceName, isDirectory: true)
            try fileManager.createDirectory(at: workspaceDir, withIntermediateDirectories: true)
            
            _workspaceDirectory = workspaceDir
        } catch {
            print("Failed to create workspace: \(error)")
        }
    }

    public func createCollectionDatabase() throws -> URL {
        let workspace = queue.sync { _workspaceDirectory }
        guard let workspace else {
            throw AnkiExportError.invalidPath(path: "workspace not initialized")
        }
        return workspace.appendingPathComponent("collection.anki21", isDirectory: false)
    }

    public func createMediaDirectory() throws -> URL {
        let workspace = queue.sync { _workspaceDirectory }
        guard let workspace else {
            throw AnkiExportError.invalidPath(path: "workspace not initialized")
        }
        
        let mediaDir = workspace.appendingPathComponent("media", isDirectory: true)
        
        if !fileManager.fileExists(atPath: mediaDir.path) {
            try fileManager.createDirectory(at: mediaDir, withIntermediateDirectories: true)
        }
        
        return mediaDir
    }

    public func stagingFile(for name: String) throws -> URL {
        let workspace = queue.sync { _workspaceDirectory }
        guard let workspace else {
            throw AnkiExportError.invalidPath(path: "workspace not initialized")
        }
        return workspace.appendingPathComponent(name)
    }

    public func atomicWrite(to destination: URL) async throws {
        let workspace = queue.sync { _workspaceDirectory }
        guard let workspace else {
            throw AnkiExportError.invalidPath(path: "workspace not initialized")
        }
        
        let currentDestination = workspace.appendingPathComponent("apkg.staging")
        let finalDest = destination
        
        do {
            if fileManager.fileExists(atPath: finalDest.path) {
                try fileManager.removeItem(at: finalDest)
            }
            
            try fileManager.moveItem(at: currentDestination, to: finalDest)
        } catch {
            cleanup()
            throw AnkiExportError.zipError(message: "Failed to write atomically: \(error.localizedDescription)")
        }
    }

    public func cleanup() {
        let workspace: URL? = queue.sync(flags: .barrier) {
            guard !isCleanedUp else { return nil }
            isCleanedUp = true
            let workspace = _workspaceDirectory
            _workspaceDirectory = nil
            return workspace
        }
        if let workspace { try? fileManager.removeItem(at: workspace) }
    }

    deinit {
        // Never enqueue work that captures `self` from deinit. Swift detects
        // that as a dangling resurrection and terminates the process.
        if !isCleanedUp, let workspace = _workspaceDirectory {
            try? fileManager.removeItem(at: workspace)
        }
    }
}

public struct ExportWorkspaceHelper {
    public static func createTemporaryDirectory(named name: String = "anki-export") throws -> URL {
        let uuid = UUID().uuidString.prefix(8)
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("\(name)-\(uuid)", isDirectory: true)
        
        if !FileManager.default.fileExists(atPath: tempDir.path) {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        }
        
        return tempDir
    }

    public static func cleanupDirectory(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    public static func atomicReplace(temporary: URL, with destination: URL) throws {
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        
        try FileManager.default.moveItem(at: temporary, to: destination)
    }
}
