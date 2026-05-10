import Foundation
import SwiftUI
import PythonKit

// MARK: - KPI Summary

struct KPISummary {
    let totalRevenueYTD: Double
    let totalRevenueYTDFormatted: String
    let outstandingAmount: Double
    let outstandingAmountFormatted: String
    let overdueAmount: Double
    let overdueAmountFormatted: String
    let effectiveHourlyRate: Double?
    let effectiveHourlyRateFormatted: String
    let utilizationRate: Double?
    let utilizationRateFormatted: String
    let activeProjects: Int
    let activeContracts: Int
    let unpaidInvoices: Int
    let vatReserve: Double
    let vatReserveFormatted: String
    let incomeTaxReserve: Double
    let incomeTaxReserveFormatted: String
    let spendableIncome: Double
    let spendableIncomeFormatted: String
    let taxCurrency: String

    static func from(_ d: PythonObject) -> KPISummary {
        KPISummary(
            totalRevenueYTD: PythonBridge.double(d, key: "total_revenue_ytd"),
            totalRevenueYTDFormatted: PythonBridge.string(d, key: "total_revenue_ytd_fmt"),
            outstandingAmount: PythonBridge.double(d, key: "outstanding_amount"),
            outstandingAmountFormatted: PythonBridge.string(d, key: "outstanding_amount_fmt"),
            overdueAmount: PythonBridge.double(d, key: "overdue_amount"),
            overdueAmountFormatted: PythonBridge.string(d, key: "overdue_amount_fmt"),
            effectiveHourlyRate: {
                let v = d["effective_hourly_rate"]
                return v == Python.None ? nil : Double(v)
            }(),
            effectiveHourlyRateFormatted: PythonBridge.string(d, key: "effective_hourly_rate_fmt"),
            utilizationRate: {
                let v = d["utilization_rate"]
                return v == Python.None ? nil : Double(v)
            }(),
            utilizationRateFormatted: PythonBridge.string(d, key: "utilization_rate_fmt"),
            activeProjects: PythonBridge.int(d, key: "active_projects"),
            activeContracts: PythonBridge.int(d, key: "active_contracts"),
            unpaidInvoices: PythonBridge.int(d, key: "unpaid_invoices"),
            vatReserve: PythonBridge.double(d, key: "vat_reserve"),
            vatReserveFormatted: PythonBridge.string(d, key: "vat_reserve_fmt"),
            incomeTaxReserve: PythonBridge.double(d, key: "income_tax_reserve"),
            incomeTaxReserveFormatted: PythonBridge.string(d, key: "income_tax_reserve_fmt"),
            spendableIncome: PythonBridge.double(d, key: "spendable_income"),
            spendableIncomeFormatted: PythonBridge.string(d, key: "spendable_income_fmt"),
            taxCurrency: PythonBridge.string(d, key: "tax_currency", fallback: "EUR")
        )
    }
}

// MARK: - Monthly Chart Data

struct MonthlyDataPoint: Identifiable {
    let id = UUID()
    let month: String
    let label: String  // short label like "05/25"
    let value: Double
}

// MARK: - Project Budget

struct ProjectBudget: Identifiable {
    let id = UUID()
    let project: String
    let hoursTracked: Double
    let hoursBudget: Double
    let progress: Double

    static func from(_ d: PythonObject) -> ProjectBudget {
        ProjectBudget(
            project: PythonBridge.string(d, key: "project", fallback: "Project"),
            hoursTracked: PythonBridge.double(d, key: "hours_tracked"),
            hoursBudget: PythonBridge.double(d, key: "hours_budget"),
            progress: PythonBridge.double(d, key: "progress")
        )
    }
}

// MARK: - Financial Goal

struct FinancialGoalModel: Identifiable {
    let id: Int
    let title: String
    let targetAmount: Double
    let targetAmountFormatted: String
    let targetDate: String
    let targetDateFormatted: String
    let isReached: Bool
    let progress: Double
    let ytdRevenueFormatted: String

    static func from(_ d: PythonObject) -> FinancialGoalModel {
        FinancialGoalModel(
            id: PythonBridge.int(d, key: "id"),
            title: PythonBridge.string(d, key: "title"),
            targetAmount: PythonBridge.double(d, key: "target_amount"),
            targetAmountFormatted: PythonBridge.string(d, key: "target_amount_fmt"),
            targetDate: PythonBridge.string(d, key: "target_date"),
            targetDateFormatted: PythonBridge.string(d, key: "target_date_fmt"),
            isReached: PythonBridge.bool(d, key: "is_reached"),
            progress: PythonBridge.double(d, key: "progress"),
            ytdRevenueFormatted: PythonBridge.string(d, key: "ytd_revenue_fmt")
        )
    }
}

// MARK: - Timeline Event

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

struct TimelineEvent: Identifiable {
    let id = UUID()
    let date: Date
    let dateFormatted: String
    let title: String
    let description: String
    let category: TimelineCategory
    let status: String
    let isFuture: Bool
    let entityId: Int?

    var monthKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }

    var monthLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    static func from(_ d: PythonObject) -> TimelineEvent? {
        let dateStr = PythonBridge.string(d, key: "date")
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateStr) else { return nil }

        let catStr = PythonBridge.string(d, key: "category")
        let category = TimelineCategory(rawValue: catStr) ?? .invoice

        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "MMM d, yyyy"

        return TimelineEvent(
            date: date,
            dateFormatted: displayFormatter.string(from: date),
            title: PythonBridge.string(d, key: "title"),
            description: PythonBridge.string(d, key: "description", fallback: ""),
            category: category,
            status: PythonBridge.string(d, key: "status", fallback: "default"),
            isFuture: PythonBridge.bool(d, key: "is_future"),
            entityId: {
                let v = d["entity_id"]
                return v == Python.None ? nil : Int(v)
            }()
        )
    }
}

// MARK: - Contact

struct ContactModel: Identifiable {
    let id: Int
    let firstName: String
    let lastName: String
    let company: String
    let email: String
    let city: String
    let country: String

    var fullName: String {
        [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ")
    }

    var displayName: String {
        let name = fullName
        if !name.isEmpty { return name }
        if !company.isEmpty { return company }
        return "—"
    }

    var location: String {
        [city, country].filter { !$0.isEmpty }.joined(separator: ", ")
    }

    var initials: String {
        let parts = [firstName, lastName].filter { !$0.isEmpty }
        if parts.isEmpty { return "?" }
        return parts.map { String($0.prefix(1)).uppercased() }.joined()
    }

    static func from(_ d: PythonObject) -> ContactModel {
        ContactModel(
            id: PythonBridge.int(d, key: "id"),
            firstName: PythonBridge.string(d, key: "first_name", fallback: ""),
            lastName: PythonBridge.string(d, key: "last_name", fallback: ""),
            company: PythonBridge.string(d, key: "company", fallback: ""),
            email: PythonBridge.string(d, key: "email", fallback: ""),
            city: PythonBridge.string(d, key: "city", fallback: ""),
            country: PythonBridge.string(d, key: "country", fallback: "")
        )
    }
}

// MARK: - Client

struct ClientModel: Identifiable {
    let id: Int
    let name: String
    let contactName: String
    let contactEmail: String
    let contactCompany: String
    let location: String
    let numContracts: Int

    var initials: String {
        let words = name.split(separator: " ")
        if words.isEmpty { return "?" }
        return words.prefix(2).map { String($0.prefix(1)).uppercased() }.joined()
    }

    static func from(_ d: PythonObject) -> ClientModel {
        let city = PythonBridge.string(d, key: "contact_city", fallback: "")
        let country = PythonBridge.string(d, key: "contact_country", fallback: "")
        let loc = [city, country].filter { !$0.isEmpty }.joined(separator: ", ")
        return ClientModel(
            id: PythonBridge.int(d, key: "id"),
            name: PythonBridge.string(d, key: "name"),
            contactName: PythonBridge.string(d, key: "contact_name", fallback: ""),
            contactEmail: PythonBridge.string(d, key: "contact_email", fallback: ""),
            contactCompany: PythonBridge.string(d, key: "contact_company", fallback: ""),
            location: loc,
            numContracts: PythonBridge.int(d, key: "num_contracts")
        )
    }
}

// MARK: - Contract

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

struct ContractModel: Identifiable {
    let id: Int
    let title: String
    let clientName: String
    let status: EntityStatus
    let startDate: String
    let endDate: String?
    let rate: Double
    let rateFormatted: String
    let currency: String
    let unit: String
    let volume: Int?
    let billingCycle: String
    let isCompleted: Bool
    let vatRate: Double
    let numProjects: Int
    let numInvoices: Int

    var dateRange: String {
        if let end = endDate {
            return "\(Self.formatDate(startDate)) – \(Self.formatDate(end))"
        }
        return "From \(Self.formatDate(startDate))"
    }

    private static func formatDate(_ iso: String) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        guard let d = fmt.date(from: iso) else { return iso }
        fmt.dateFormat = "MMM d, yyyy"
        return fmt.string(from: d)
    }

    static func from(_ d: PythonObject) -> ContractModel {
        let statusStr = PythonBridge.string(d, key: "status", fallback: "All")
        let status = EntityStatus(rawValue: statusStr) ?? .all
        let endVal = d.checking["end_date"]
        let endDate: String? = (endVal != nil && endVal != Python.None)
            ? String(endVal!) : nil
        return ContractModel(
            id: PythonBridge.int(d, key: "id"),
            title: PythonBridge.string(d, key: "title"),
            clientName: PythonBridge.string(d, key: "client_name"),
            status: status,
            startDate: PythonBridge.string(d, key: "start_date"),
            endDate: endDate,
            rate: PythonBridge.double(d, key: "rate"),
            rateFormatted: PythonBridge.string(d, key: "rate_fmt"),
            currency: PythonBridge.string(d, key: "currency", fallback: "EUR"),
            unit: PythonBridge.string(d, key: "unit", fallback: "hour"),
            volume: {
                guard let v = d.checking["volume"], v != Python.None else { return nil }
                return Int(v)
            }(),
            billingCycle: PythonBridge.string(d, key: "billing_cycle", fallback: ""),
            isCompleted: PythonBridge.bool(d, key: "is_completed"),
            vatRate: PythonBridge.double(d, key: "vat_rate"),
            numProjects: PythonBridge.int(d, key: "num_projects"),
            numInvoices: PythonBridge.int(d, key: "num_invoices")
        )
    }
}

// MARK: - Project

struct ProjectModel: Identifiable {
    let id: Int
    let title: String
    let tag: String
    let description: String
    let clientName: String
    let contractTitle: String
    let status: EntityStatus
    let startDate: String
    let endDate: String?
    let isCompleted: Bool
    let numInvoices: Int
    let numTimesheets: Int

    var dateRange: String {
        if let end = endDate {
            return "\(Self.formatDate(startDate)) – \(Self.formatDate(end))"
        }
        return "From \(Self.formatDate(startDate))"
    }

    private static func formatDate(_ iso: String) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        guard let d = fmt.date(from: iso) else { return iso }
        fmt.dateFormat = "MMM d, yyyy"
        return fmt.string(from: d)
    }

    static func from(_ d: PythonObject) -> ProjectModel {
        let statusStr = PythonBridge.string(d, key: "status", fallback: "")
        let status = EntityStatus(rawValue: statusStr) ?? .all
        let endVal = d.checking["end_date"]
        let endDate: String? = (endVal != nil && endVal != Python.None)
            ? String(endVal!) : nil
        return ProjectModel(
            id: PythonBridge.int(d, key: "id"),
            title: PythonBridge.string(d, key: "title"),
            tag: PythonBridge.string(d, key: "tag", fallback: ""),
            description: PythonBridge.string(d, key: "description", fallback: ""),
            clientName: PythonBridge.string(d, key: "client_name", fallback: ""),
            contractTitle: PythonBridge.string(d, key: "contract_title", fallback: ""),
            status: status,
            startDate: PythonBridge.string(d, key: "start_date"),
            endDate: endDate,
            isCompleted: PythonBridge.bool(d, key: "is_completed"),
            numInvoices: PythonBridge.int(d, key: "num_invoices"),
            numTimesheets: PythonBridge.int(d, key: "num_timesheets")
        )
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

// MARK: - Invoice Item

struct InvoiceItemModel: Identifiable {
    let id: Int
    let description: String
    let quantity: Double
    let unit: String
    let unitPrice: Double
    let unitPriceFormatted: String
    let vatRate: Double
    let subtotal: Double
    let subtotalFormatted: String
    let startDate: String
    let endDate: String?

    var vatPercent: String {
        String(format: "%.0f%%", vatRate * 100)
    }

    var dateRange: String {
        if let end = endDate {
            return "\(Self.fmtDate(startDate)) – \(Self.fmtDate(end))"
        }
        return Self.fmtDate(startDate)
    }

    private static func fmtDate(_ iso: String) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        guard let d = fmt.date(from: iso) else { return iso }
        fmt.dateFormat = "MMM d, yyyy"
        return fmt.string(from: d)
    }

    static func from(_ d: PythonObject) -> InvoiceItemModel {
        let endVal = d.checking["end_date"]
        let endDate: String? = (endVal != nil && endVal != Python.None)
            ? String(endVal!) : nil
        return InvoiceItemModel(
            id: PythonBridge.int(d, key: "id"),
            description: PythonBridge.string(d, key: "description"),
            quantity: PythonBridge.double(d, key: "quantity"),
            unit: PythonBridge.string(d, key: "unit", fallback: "hour"),
            unitPrice: PythonBridge.double(d, key: "unit_price"),
            unitPriceFormatted: PythonBridge.string(d, key: "unit_price_fmt"),
            vatRate: PythonBridge.double(d, key: "vat_rate"),
            subtotal: PythonBridge.double(d, key: "subtotal"),
            subtotalFormatted: PythonBridge.string(d, key: "subtotal_fmt"),
            startDate: PythonBridge.string(d, key: "start_date"),
            endDate: endDate
        )
    }
}

// MARK: - Invoice

struct InvoiceModel: Identifiable {
    let id: Int
    let number: String
    let date: String
    let clientName: String
    let projectTitle: String
    let contractTitle: String
    let currency: String
    let subtotal: Double
    let subtotalFormatted: String
    let vatTotal: Double
    let vatTotalFormatted: String
    let total: Double
    let totalFormatted: String
    let status: InvoiceStatus
    let sent: Bool
    let paid: Bool
    let cancelled: Bool
    let rendered: Bool
    let dueDate: String?
    let items: [InvoiceItemModel]

    var dateFormatted: String { Self.fmtDate(date) }

    var dueDateFormatted: String? {
        guard let d = dueDate else { return nil }
        return Self.fmtDate(d)
    }

    private static func fmtDate(_ iso: String) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        guard let d = fmt.date(from: iso) else { return iso }
        fmt.dateFormat = "MMM d, yyyy"
        return fmt.string(from: d)
    }

    static func from(_ d: PythonObject) -> InvoiceModel {
        let statusStr = PythonBridge.string(d, key: "status", fallback: "draft")
        let status = InvoiceStatus(rawValue: statusStr.capitalized) ?? .draft

        let dueDateVal = d.checking["due_date"]
        let dueDate: String? = (dueDateVal != nil && dueDateVal != Python.None)
            ? String(dueDateVal!) : nil

        var items: [InvoiceItemModel] = []
        if let itemsList = d.checking["items"], itemsList != Python.None {
            for item in itemsList {
                items.append(InvoiceItemModel.from(item))
            }
        }

        return InvoiceModel(
            id: PythonBridge.int(d, key: "id"),
            number: PythonBridge.string(d, key: "number"),
            date: PythonBridge.string(d, key: "date"),
            clientName: PythonBridge.string(d, key: "client_name"),
            projectTitle: PythonBridge.string(d, key: "project_title"),
            contractTitle: PythonBridge.string(d, key: "contract_title"),
            currency: PythonBridge.string(d, key: "currency", fallback: "EUR"),
            subtotal: PythonBridge.double(d, key: "subtotal"),
            subtotalFormatted: PythonBridge.string(d, key: "subtotal_fmt"),
            vatTotal: PythonBridge.double(d, key: "vat_total"),
            vatTotalFormatted: PythonBridge.string(d, key: "vat_total_fmt"),
            total: PythonBridge.double(d, key: "total"),
            totalFormatted: PythonBridge.string(d, key: "total_fmt"),
            status: status,
            sent: PythonBridge.bool(d, key: "sent"),
            paid: PythonBridge.bool(d, key: "paid"),
            cancelled: PythonBridge.bool(d, key: "cancelled"),
            rendered: PythonBridge.bool(d, key: "rendered"),
            dueDate: dueDate,
            items: items
        )
    }
}

extension InvoiceModel: Hashable {
    static func == (lhs: InvoiceModel, rhs: InvoiceModel) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
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
