import SwiftUI

// MARK: - Invoice Column

enum InvoiceColumn: String, CaseIterable, BoardColumn {
    case draft = "Draft"
    case sent = "Sent"
    case paid = "Paid"
    case overdue = "Overdue"
    case cancelled = "Cancelled"

    var color: Color {
        switch self {
        case .draft: .secondary
        case .sent: .blue
        case .paid: .green
        case .overdue: .red
        case .cancelled: .orange
        }
    }

    var icon: String {
        switch self {
        case .draft: "doc"
        case .sent: "paperplane"
        case .paid: "checkmark.circle.fill"
        case .overdue: "exclamationmark.triangle"
        case .cancelled: "xmark.circle"
        }
    }

    static func defaultColumn(for invoice: Entity) -> InvoiceColumn {
        switch invoice.invoiceStatus {
        case .draft: .draft
        case .sent: .sent
        case .paid: .paid
        case .overdue: .overdue
        case .cancelled: .cancelled
        case .all: .draft
        }
    }
}

// MARK: - Invoice Card Content

struct InvoiceCardContent: View {
    let invoice: Entity

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(invoice.str("number").isEmpty ? "Draft" : invoice.number)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text(invoice.str("total_formatted"))
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .monospacedDigit()
            }

            if !invoice.str("client_name").isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "building.2")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(invoice.str("client_name"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !invoice.str("project_title").isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "folder")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(invoice.str("project_title"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            HStack(spacing: 12) {
                if !invoice.str("date").isEmpty {
                    HStack(spacing: 3) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                        Text(Entity.formatDateStr(invoice.str("date")))
                            .font(.caption2)
                    }
                    .foregroundStyle(.tertiary)
                }

                Spacer()

                let itemCount = invoice.list("items").count
                if itemCount > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "list.bullet")
                            .font(.caption2)
                        Text("\(itemCount) items")
                            .font(.caption2)
                    }
                    .foregroundStyle(.tertiary)
                }
            }
        }
    }
}
