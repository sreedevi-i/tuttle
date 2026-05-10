import Foundation
import SwiftUI

// MARK: - Entity (generic wrapper for Python model data)

@dynamicMemberLookup
struct Entity: Identifiable, Hashable {
    let data: [String: Any]

    var id: Int { data["id"] as? Int ?? UUID().hashValue }

    static func == (lhs: Entity, rhs: Entity) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    subscript(dynamicMember key: String) -> String {
        str(key)
    }

    func str(_ key: String) -> String {
        guard let val = data[key] else { return "" }
        if let s = val as? String { return s }
        if let n = val as? Int { return String(n) }
        if let d = val as? Double { return String(d) }
        if let b = val as? Bool { return b ? "true" : "false" }
        return String(describing: val)
    }

    func num(_ key: String) -> Double {
        guard let val = data[key] else { return 0 }
        if let d = val as? Double { return d }
        if let i = val as? Int { return Double(i) }
        if let s = val as? String { return Double(s) ?? 0 }
        return 0
    }

    func int(_ key: String) -> Int {
        guard let val = data[key] else { return 0 }
        if let i = val as? Int { return i }
        if let d = val as? Double { return Int(d) }
        if let s = val as? String { return Int(s) ?? 0 }
        return 0
    }

    func bool(_ key: String) -> Bool {
        guard let val = data[key] else { return false }
        if let b = val as? Bool { return b }
        if let i = val as? Int { return i != 0 }
        return false
    }

    func date(_ key: String) -> Date? {
        data[key] as? Date
    }

    func entity(_ key: String) -> Entity? {
        guard let d = data[key] as? [String: Any] else { return nil }
        return Entity(data: d)
    }

    func list(_ key: String) -> [Entity] {
        guard let arr = data[key] as? [[String: Any]] else { return [] }
        return arr.map { Entity(data: $0) }
    }

    func has(_ key: String) -> Bool {
        data[key] != nil
    }

    func optStr(_ key: String) -> String? {
        guard let val = data[key] else { return nil }
        if let s = val as? String { return s }
        return nil
    }

    func optInt(_ key: String) -> Int? {
        guard let val = data[key] else { return nil }
        if let i = val as? Int { return i }
        if let d = val as? Double { return Int(d) }
        return nil
    }

    func optNum(_ key: String) -> Double? {
        guard let val = data[key] else { return nil }
        if let d = val as? Double { return d }
        if let i = val as? Int { return Double(i) }
        return nil
    }
}

// MARK: - Entity Display Extensions

extension Entity {
    var fullName: String {
        [str("first_name"), str("last_name")].filter { !$0.isEmpty }.joined(separator: " ")
    }

    var displayName: String {
        let name = fullName
        if !name.isEmpty { return name }
        let company = str("company")
        if !company.isEmpty { return company }
        return "—"
    }

    var initials: String {
        let parts = [str("first_name"), str("last_name")].filter { !$0.isEmpty }
        if parts.isEmpty {
            let name = str("name")
            if !name.isEmpty {
                let words = name.split(separator: " ")
                return words.prefix(2).map { String($0.prefix(1)).uppercased() }.joined()
            }
            return "?"
        }
        return parts.map { String($0.prefix(1)).uppercased() }.joined()
    }

    var location: String {
        [str("city"), str("country")].filter { !$0.isEmpty }.joined(separator: ", ")
    }

    var dateRange: String {
        let start = str("start_date")
        let end = optStr("end_date")
        if let end, !end.isEmpty {
            return "\(Self.formatDate(start)) – \(Self.formatDate(end))"
        }
        if !start.isEmpty {
            return "From \(Self.formatDate(start))"
        }
        return ""
    }

    var entityStatus: EntityStatus {
        EntityStatus(rawValue: str("status")) ?? .all
    }

    var invoiceStatus: InvoiceStatus {
        InvoiceStatus(rawValue: str("status").capitalized) ?? .draft
    }

    var vatPercent: String {
        String(format: "%.0f%%", num("VAT_rate") * 100)
    }

    var monthKey: String {
        guard let d = date("_date") else { return "" }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM"
        return fmt.string(from: d)
    }

    var monthLabel: String {
        guard let d = date("_date") else { return "" }
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM yyyy"
        return fmt.string(from: d)
    }

    private static func formatDate(_ iso: String) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        guard let d = fmt.date(from: iso) else { return iso }
        fmt.dateFormat = "MMM d, yyyy"
        return fmt.string(from: d)
    }
}

// MARK: - Monthly Chart Data (view-specific, not a Python model)

struct MonthlyDataPoint: Identifiable {
    let id = UUID()
    let month: String
    let label: String
    let value: Double
}

// MARK: - Entity Status

enum EntityStatus: String {
    case active = "Active"
    case upcoming = "Upcoming"
    case completed = "Completed"
    case all = "All"

    var color: Color {
        switch self {
        case .active: .green
        case .upcoming: .blue
        case .completed: .secondary
        case .all: .primary
        }
    }

    var icon: String {
        switch self {
        case .active: "circle.fill"
        case .upcoming: "clock"
        case .completed: "checkmark.circle.fill"
        case .all: "list.bullet"
        }
    }
}

// MARK: - Invoice Status

enum InvoiceStatus: String, CaseIterable {
    case all = "All"
    case draft = "Draft"
    case sent = "Sent"
    case paid = "Paid"
    case overdue = "Overdue"
    case cancelled = "Cancelled"

    var color: Color {
        switch self {
        case .all: .primary
        case .draft: .secondary
        case .sent: .blue
        case .paid: .green
        case .overdue: .red
        case .cancelled: .orange
        }
    }

    var icon: String {
        switch self {
        case .all: "list.bullet"
        case .draft: "doc"
        case .sent: "paperplane"
        case .paid: "checkmark.circle.fill"
        case .overdue: "exclamationmark.triangle"
        case .cancelled: "xmark.circle"
        }
    }
}

// MARK: - Timeline Category

enum TimelineCategory: String, CaseIterable, Identifiable {
    case all = "all"
    case invoice = "invoice"
    case contract = "contract"
    case project = "project"
    case goal = "goal"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: "All"
        case .invoice: "Invoices"
        case .contract: "Contracts"
        case .project: "Projects"
        case .goal: "Goals"
        }
    }

    var systemImage: String {
        switch self {
        case .all: "list.bullet"
        case .invoice: "doc.text"
        case .contract: "signature"
        case .project: "folder"
        case .goal: "flag"
        }
    }
}

// MARK: - Sidebar

enum SidebarItem: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case timeline = "Timeline"
    case taxReserves = "Tax & Reserves"
    case salary = "Salary"
    case projects = "Projects"
    case contracts = "Contracts"
    case clients = "Clients"
    case contacts = "Contacts"
    case timeTracking = "Time Tracking"
    case invoicing = "Invoicing"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .dashboard: "square.grid.2x2"
        case .timeline: "calendar.day.timeline.left"
        case .taxReserves: "chart.pie"
        case .salary: "banknote"
        case .projects: "folder"
        case .contracts: "signature"
        case .clients: "building.2"
        case .contacts: "person.2"
        case .timeTracking: "clock"
        case .invoicing: "doc.text"
        }
    }

    enum Section: String, CaseIterable {
        case insights = "Insights"
        case business = "My Business"
        case workflows = "Workflows"
    }

    var section: Section {
        switch self {
        case .dashboard, .timeline, .taxReserves, .salary: .insights
        case .projects, .contracts, .clients, .contacts: .business
        case .timeTracking, .invoicing: .workflows
        }
    }

    static func grouped() -> [(Section, [SidebarItem])] {
        Section.allCases.map { section in
            (section, SidebarItem.allCases.filter { $0.section == section })
        }
    }
}
