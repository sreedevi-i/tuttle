import Foundation
import PythonKit

/// Manages the embedded Python interpreter. Exposes tuttle intents directly.
/// All Python calls happen on a single dedicated thread to satisfy CPython's GIL.
final class PythonBridge {
    static let shared = PythonBridge()

    // Intents -- Swift calls these directly, no intermediary
    private(set) var contacts: PythonObject!
    private(set) var clients: PythonObject!
    private(set) var contracts: PythonObject!
    private(set) var projects: PythonObject!
    private(set) var dashboard: PythonObject!
    private(set) var timeline: PythonObject!
    private(set) var invoicingDS: PythonObject!  // InvoicingDataSource for reads
    private(set) var invoicing: PythonObject!    // InvoicingIntent for mutations
    private(set) var demo: PythonObject!
    private(set) var fmtCurrency: PythonObject!

    private var _runLoop: CFRunLoop!
    private let _thread: Thread

    private init() {
        let readySem = DispatchSemaphore(value: 0)
        let initSem = DispatchSemaphore(value: 0)

        var capturedRunLoop: CFRunLoop!

        _thread = Thread {
            capturedRunLoop = CFRunLoopGetCurrent()
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

        CFRunLoopPerformBlock(_runLoop, CFRunLoopMode.defaultMode.rawValue) { [self] in
            let projectRoot = PythonBridge.findProjectRoot()
            PythonBridge.configurePythonEnvironment(projectRoot: projectRoot)
            let sys = Python.import("sys")
            sys.path.insert(0, projectRoot)

            self.contacts = Python.import("tuttle.app.contacts.intent").ContactsIntent()
            self.clients = Python.import("tuttle.app.clients.intent").ClientsIntent()
            self.contracts = Python.import("tuttle.app.contracts.intent").ContractsIntent()
            self.projects = Python.import("tuttle.app.projects.intent").ProjectsIntent()
            self.dashboard = Python.import("tuttle.app.dashboard.intent").DashboardIntent()
            self.timeline = Python.import("tuttle.app.timeline.intent").TimelineIntent()
            self.invoicingDS = Python.import("tuttle.app.invoicing.data_source").InvoicingDataSource()
            self.invoicing = Python.import("tuttle.app.invoicing.intent").InvoicingIntent(client_storage: Python.None)
            self.demo = Python.import("tuttle.demo")
            self.fmtCurrency = Python.import("tuttle.app.core.formatting").fmt_currency

            initSem.signal()
        }
        CFRunLoopWakeUp(_runLoop)
        initSem.wait()
    }

    /// Execute `work` on the dedicated Python thread, deliver result on main thread.
    /// The closure MUST convert all PythonObjects to Swift types before returning.
    func run<T>(_ work: @escaping () -> T, completion: @escaping (T) -> Void) {
        CFRunLoopPerformBlock(_runLoop, CFRunLoopMode.defaultMode.rawValue) {
            let result = work()
            DispatchQueue.main.async {
                completion(result)
            }
        }
        CFRunLoopWakeUp(_runLoop)
    }

    /// Reinstall demo data, then re-create all intents.
    func installDemoData(nProjects: Int = 4, completion: @escaping (Bool) -> Void) {
        run({
            let pathlib = Python.import("pathlib")
            let dbPath = pathlib.Path.home() / ".tuttle" / "tuttle.db"
            if Bool(dbPath.exists())! { dbPath.unlink() }
            let migrations = Python.import("tuttle.migrations.run")
            migrations.run_migrations("sqlite:///\(dbPath)")
            PythonBridge.shared.demo.install_demo_data(
                n_projects: nProjects,
                db_path: String(dbPath)!,
                on_cache_timetracking_dataframe: Python.None
            )
            // Re-create intents so they pick up the new DB
            PythonBridge.shared.contacts = Python.import("tuttle.app.contacts.intent").ContactsIntent()
            PythonBridge.shared.clients = Python.import("tuttle.app.clients.intent").ClientsIntent()
            PythonBridge.shared.contracts = Python.import("tuttle.app.contracts.intent").ContractsIntent()
            PythonBridge.shared.projects = Python.import("tuttle.app.projects.intent").ProjectsIntent()
            PythonBridge.shared.dashboard = Python.import("tuttle.app.dashboard.intent").DashboardIntent()
            PythonBridge.shared.timeline = Python.import("tuttle.app.timeline.intent").TimelineIntent()
            PythonBridge.shared.invoicingDS = Python.import("tuttle.app.invoicing.data_source").InvoicingDataSource()
            PythonBridge.shared.invoicing = Python.import("tuttle.app.invoicing.intent").InvoicingIntent(client_storage: Python.None)
            return true
        }, completion: completion)
    }

    // MARK: - Python Environment Configuration (unchanged)

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

// MARK: - Python → Swift Conversion

extension PythonBridge {
    /// Check IntentResult success
    static func isOk(_ result: PythonObject) -> Bool {
        Bool(result.was_intent_successful) ?? false
    }

    /// Format a Python numeric value with tuttle's fmt_currency
    static func fmtCurrencyStr(_ amount: PythonObject, _ currency: String) -> String {
        String(PythonBridge.shared.fmtCurrency(amount, currency)) ?? "—"
    }

    /// Recursively convert a Python value to a Swift-native value.
    /// Handles: None, bool, int, float, Decimal, str, date/datetime, Enum, list, dict.
    static func toSwift(_ val: PythonObject) -> Any? {
        if val == Python.None { return nil }

        let typeName = String(Python.type(val).__name__) ?? ""

        switch typeName {
        case "bool":
            return Bool(val) ?? false
        case "int":
            return Int(val) ?? 0
        case "float":
            return Double(val) ?? 0.0
        case "str":
            return String(val) ?? ""
        case "Decimal":
            return Double(Python.float(val)) ?? 0.0
        case "date", "datetime":
            return String(val.isoformat()) ?? ""
        case "list", "tuple":
            var arr: [Any] = []
            for item in val {
                if let v = toSwift(item) { arr.append(v) }
            }
            return arr
        case "dict", "OrderedDict":
            return toSwiftDict(val)
        default:
            // Enum types have a .value attribute
            if let v = val.checking.value {
                return String(v) ?? String(val)
            }
            return String(val)
        }
    }

    /// Convert a Python dict to [String: Any]
    static func toSwiftDict(_ pyDict: PythonObject) -> [String: Any] {
        var result: [String: Any] = [:]
        guard let items = Dictionary<String, PythonObject>(pyDict) else { return result }
        for (key, val) in items {
            if let swiftVal = toSwift(val) {
                result[key] = swiftVal
            }
        }
        return result
    }

    /// Convert a Python model object to an Entity using model_dump().
    /// The `extras` closure can inject additional computed fields.
    static func toEntity(
        _ obj: PythonObject,
        extras: ((PythonObject, inout [String: Any]) -> Void)? = nil
    ) -> Entity {
        let pyDict = obj.model_dump()
        var dict = toSwiftDict(pyDict)
        extras?(obj, &dict)
        return Entity(data: dict)
    }

    /// Convert a Python list of model objects to [Entity].
    static func toEntityList(
        _ pyList: PythonObject,
        extras: ((PythonObject, inout [String: Any]) -> Void)? = nil
    ) -> [Entity] {
        if pyList == Python.None { return [] }
        var out: [Entity] = []
        for obj in pyList {
            out.append(toEntity(obj, extras: extras))
        }
        return out
    }

    /// Convert a Python list of plain dicts to [Entity].
    static func dictListToEntities(_ pyList: PythonObject) -> [Entity] {
        if pyList == Python.None { return [] }
        var out: [Entity] = []
        for item in pyList {
            out.append(Entity(data: toSwiftDict(item)))
        }
        return out
    }
}
