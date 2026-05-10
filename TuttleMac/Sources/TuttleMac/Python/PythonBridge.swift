import Foundation
import PythonKit

/// Manages the embedded Python interpreter and provides access to the tuttle bridge module.
/// All Python calls happen on a single dedicated thread to satisfy CPython's GIL requirements.
final class PythonBridge {
    static let shared = PythonBridge()

    private var _bridge: PythonObject!
    private var _runLoop: CFRunLoop!
    private let _thread: Thread

    private init() {
        let readySem = DispatchSemaphore(value: 0)
        let initSem = DispatchSemaphore(value: 0)

        var capturedRunLoop: CFRunLoop!

        _thread = Thread {
            capturedRunLoop = CFRunLoopGetCurrent()
            // A run loop needs at least one source to stay alive
            let keepAlive = NSMachPort()
            RunLoop.current.add(keepAlive, forMode: .default)
            readySem.signal()
            CFRunLoopRun()
        }
        _thread.qualityOfService = .userInitiated
        _thread.name = "dev.tuttle.python"
        _thread.start()

        readySem.wait()
        _runLoop = capturedRunLoop

        // Initialize Python on the dedicated thread
        var bridge: PythonObject!
        CFRunLoopPerformBlock(_runLoop, CFRunLoopMode.defaultMode.rawValue) {
            let projectRoot = PythonBridge.findProjectRoot()
            PythonBridge.configurePythonEnvironment(projectRoot: projectRoot)
            let sys = Python.import("sys")
            sys.path.insert(0, projectRoot)
            bridge = Python.import("tuttle.bridge").TuttleBridge()
            initSem.signal()
        }
        CFRunLoopWakeUp(_runLoop)
        initSem.wait()
        _bridge = bridge
    }

    /// Execute `work` on the dedicated Python thread, then deliver the result on the main thread.
    /// The `work` closure MUST convert all PythonObjects to Swift types before returning --
    /// the returned value must not contain any PythonObject references.
    func run<T>(_ work: @escaping (PythonObject) -> T, completion: @escaping (T) -> Void) {
        let bridge = _bridge!
        CFRunLoopPerformBlock(_runLoop, CFRunLoopMode.defaultMode.rawValue) {
            let result = work(bridge)
            DispatchQueue.main.async {
                completion(result)
            }
        }
        CFRunLoopWakeUp(_runLoop)
    }

    // MARK: - Python Environment Configuration

    private static func configurePythonEnvironment(projectRoot: String) {
        let venvPath = projectRoot + "/.venv"
        let fm = FileManager.default

        let cfgPath = venvPath + "/pyvenv.cfg"
        var pythonVersion = "3.13"
        if let cfgContents = try? String(contentsOfFile: cfgPath, encoding: .utf8) {
            for line in cfgContents.components(separatedBy: .newlines) {
                let parts = line.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
                if parts.count == 2 && parts[0] == "version" {
                    let components = parts[1].split(separator: ".")
                    if components.count >= 2 {
                        pythonVersion = "\(components[0]).\(components[1])"
                    }
                }
            }
        }

        let venvPython = venvPath + "/bin/python"
        var basePythonHome: String?
        if let resolved = try? fm.destinationOfSymbolicLink(atPath: venvPython) {
            let resolvedURL = URL(fileURLWithPath: resolved)
            basePythonHome = resolvedURL
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .path
        }

        if let home = basePythonHome {
            let candidates = [
                "\(home)/lib/libpython\(pythonVersion).dylib",
                "\(home)/lib/libpython\(pythonVersion)m.dylib",
            ]
            for candidate in candidates {
                if fm.fileExists(atPath: candidate) {
                    setenv("PYTHON_LIBRARY", candidate, 1)
                    break
                }
            }
        }

        setenv("PYTHONHOME", venvPath, 1)

        var paths = [projectRoot]
        let sitePackages = "\(venvPath)/lib/python\(pythonVersion)/site-packages"
        if fm.fileExists(atPath: sitePackages) {
            paths.append(sitePackages)
        }
        if let home = basePythonHome {
            paths.append("\(home)/lib/python\(pythonVersion)")
            paths.append("\(home)/lib/python\(pythonVersion)/lib-dynload")
        }
        setenv("PYTHONPATH", paths.joined(separator: ":"), 1)
    }

    private static func findProjectRoot() -> String {
        let candidates = [
            URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .path,
            FileManager.default.currentDirectoryPath,
        ]

        for candidate in candidates {
            let marker = candidate + "/tuttle/__init__.py"
            if FileManager.default.fileExists(atPath: marker) {
                return candidate
            }
        }
        return FileManager.default.currentDirectoryPath
    }
}

// MARK: - Conversion Helpers

extension PythonBridge {
    static func string(_ obj: PythonObject, key: String, fallback: String = "—") -> String {
        guard let val = obj.checking[key] else { return fallback }
        if val == Python.None { return fallback }
        return String(val) ?? fallback
    }

    static func double(_ obj: PythonObject, key: String, fallback: Double = 0) -> Double {
        guard let val = obj.checking[key] else { return fallback }
        if val == Python.None { return fallback }
        return Double(val) ?? fallback
    }

    static func int(_ obj: PythonObject, key: String, fallback: Int = 0) -> Int {
        guard let val = obj.checking[key] else { return fallback }
        if val == Python.None { return fallback }
        return Int(val) ?? fallback
    }

    static func bool(_ obj: PythonObject, key: String, fallback: Bool = false) -> Bool {
        guard let val = obj.checking[key] else { return fallback }
        if val == Python.None { return fallback }
        return Bool(val) ?? fallback
    }
}
