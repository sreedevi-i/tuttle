import SwiftUI

struct InvoicingView: View {
    @State private var viewModel = InvoicingViewModel()
    @State private var selectedInvoice: Entity?
    @State private var statusFilter: InvoiceStatus = .all
    @State private var searchText = ""

    private var filtered: [Entity] {
        viewModel.invoices.filter { inv in
            (statusFilter == .all || inv.invoiceStatus == statusFilter)
            && (searchText.isEmpty
                || inv.str("number").localizedCaseInsensitiveContains(searchText)
                || inv.str("client_name").localizedCaseInsensitiveContains(searchText)
                || inv.str("project_title").localizedCaseInsensitiveContains(searchText))
        }
    }

    private var totalFiltered: Double {
        filtered.reduce(0) { $0 + $1.num("total_value") }
    }

    var body: some View {
        HStack(spacing: 0) {
            invoiceList
            Divider()
            detailPane
                .frame(minWidth: 320, maxWidth: 420)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Invoicing")
        .searchable(text: $searchText, prompt: "Search invoices…")
        .onAppear { viewModel.loadInvoices() }
        .refreshable { viewModel.loadInvoices() }
    }

    // MARK: - List

    private var invoiceList: some View {
        VStack(spacing: 0) {
            statusFilterBar
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

            Divider()

            if viewModel.isLoading && viewModel.invoices.isEmpty {
                ProgressView("Loading invoices…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filtered.isEmpty {
                if searchText.isEmpty && statusFilter != .all {
                    ContentUnavailableView(
                        "No \(statusFilter.rawValue) Invoices",
                        systemImage: statusFilter.icon,
                        description: Text("No invoices match this filter.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ContentUnavailableView.search(text: searchText)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                List(filtered, selection: $selectedInvoice) { invoice in
                    InvoiceRow(invoice: invoice)
                        .tag(invoice)
                        .contextMenu {
                            statusContextMenu(for: invoice)
                            Divider()
                            Button("Delete", role: .destructive) {
                                viewModel.deleteInvoice(invoice.id)
                                if selectedInvoice?.id == invoice.id {
                                    selectedInvoice = nil
                                }
                            }
                        }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Filter

    private var statusFilterBar: some View {
        HStack(spacing: 6) {
            ForEach(InvoiceStatus.allCases, id: \.rawValue) { status in
                StatusFilterChip(
                    label: status.rawValue,
                    icon: status.icon,
                    isActive: statusFilter == status,
                    color: status == .all ? .accentColor : status.color
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        statusFilter = status
                    }
                }
            }
            Spacer()
            Text("\(filtered.count) invoices")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func statusContextMenu(for invoice: Entity) -> some View {
        if !invoice.bool("cancelled") {
            Button(invoice.bool("sent") ? "Mark as Not Sent" : "Mark as Sent") {
                viewModel.toggleSent(invoice.id)
            }
            Button(invoice.bool("paid") ? "Mark as Unpaid" : "Mark as Paid") {
                viewModel.togglePaid(invoice.id)
            }
        }
        Button(invoice.bool("cancelled") ? "Restore Invoice" : "Cancel Invoice") {
            viewModel.toggleCancelled(invoice.id)
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailPane: some View {
        if let invoice = selectedInvoice {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    invoiceHeader(invoice)
                    Divider()
                    invoiceAmounts(invoice)
                    invoiceItems(invoice)
                    invoiceDetails(invoice)
                    invoiceActions(invoice)
                }
                .padding(20)
            }
            .frame(maxHeight: .infinity)
        } else {
            ContentUnavailableView(
                "No Selection",
                systemImage: "doc.text",
                description: Text("Select an invoice to view details.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Detail Subviews

    private func invoiceHeader(_ invoice: Entity) -> some View {
        let status = invoice.invoiceStatus
        return HStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.title2)
                .foregroundStyle(status.color)
                .frame(width: 48, height: 48)
                .background(status.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(invoice.str("number").isEmpty ? "Draft" : invoice.number)
                    .font(.title2)
                    .fontWeight(.bold)
                HStack(spacing: 6) {
                    Text(invoice.str("client_name").isEmpty ? "No client" : invoice.str("client_name"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    InvoiceStatusBadge(status: status)
                }
            }
            Spacer()
        }
    }

    private func invoiceAmounts(_ invoice: Entity) -> some View {
        let status = invoice.invoiceStatus
        return HStack(spacing: 12) {
            AmountCard(label: "Subtotal", value: invoice.str("sum_formatted"), color: .secondary)
            AmountCard(label: "VAT", value: invoice.str("vat_total_formatted"), color: .orange)
            AmountCard(label: "Total", value: invoice.str("total_formatted"), color: status.color, isProminent: true)
        }
    }

    @ViewBuilder
    private func invoiceItems(_ invoice: Entity) -> some View {
        let items = invoice.list("items")
        if !items.isEmpty {
            DetailSection(title: "Line Items") {
                VStack(spacing: 0) {
                    ForEach(items) { item in
                        InvoiceItemRow(item: item)
                        if item.id != items.last?.id {
                            Divider().padding(.vertical, 4)
                        }
                    }
                }
            }
        }
    }

    private func invoiceDetails(_ invoice: Entity) -> some View {
        let dateStr = invoice.str("date")
        let dueDateStr = invoice.optStr("due_date")
        return DetailSection(title: "Details") {
            DetailRow(label: "Date", value: Entity.formatDateStr(dateStr), icon: "calendar")
            if let due = dueDateStr, !due.isEmpty {
                DetailRow(label: "Due", value: Entity.formatDateStr(due), icon: "clock")
            }
            DetailRow(label: "Project", value: invoice.str("project_title"), icon: "folder")
            DetailRow(label: "Contract", value: invoice.str("contract_title"), icon: "signature")
            DetailRow(label: "Currency", value: invoice.str("currency"), icon: "banknote")
        }
    }

    private func invoiceActions(_ invoice: Entity) -> some View {
        DetailSection(title: "Actions") {
            HStack(spacing: 10) {
                if !invoice.bool("cancelled") {
                    ActionButton(
                        label: invoice.bool("sent") ? "Unsend" : "Mark Sent",
                        icon: "paperplane",
                        color: .blue,
                        isActive: invoice.bool("sent")
                    ) {
                        viewModel.toggleSent(invoice.id)
                    }
                    ActionButton(
                        label: invoice.bool("paid") ? "Unpay" : "Mark Paid",
                        icon: "checkmark.circle",
                        color: .green,
                        isActive: invoice.bool("paid")
                    ) {
                        viewModel.togglePaid(invoice.id)
                    }
                }
                ActionButton(
                    label: invoice.bool("cancelled") ? "Restore" : "Cancel",
                    icon: invoice.bool("cancelled") ? "arrow.uturn.left" : "xmark.circle",
                    color: .orange,
                    isActive: invoice.bool("cancelled")
                ) {
                    viewModel.toggleCancelled(invoice.id)
                }
            }
        }
    }
}

// MARK: - Invoice Row

struct InvoiceRow: View {
    let invoice: Entity

    var body: some View {
        let status = invoice.invoiceStatus
        HStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.body)
                .foregroundStyle(status.color)
                .frame(width: 34, height: 34)
                .background(status.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(invoice.str("number").isEmpty ? "Draft" : invoice.number)
                        .font(.body)
                        .fontWeight(.medium)
                    Text(Entity.formatDateStr(invoice.str("date")))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                HStack(spacing: 4) {
                    Text(invoice.str("client_name").isEmpty ? "No client" : invoice.str("client_name"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !invoice.str("project_title").isEmpty {
                        Text("·")
                            .foregroundStyle(.quaternary)
                        Text(invoice.str("project_title"))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(invoice.str("total_formatted"))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                InvoiceStatusBadge(status: status)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Invoice Status Badge

struct InvoiceStatusBadge: View {
    let status: InvoiceStatus

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(.system(size: 8))
            Text(status.rawValue)
                .font(.caption2)
                .fontWeight(.semibold)
        }
        .foregroundStyle(status.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(status.color.opacity(0.1), in: Capsule())
    }
}

// MARK: - Amount Card

struct AmountCard: View {
    let label: String
    let value: String
    let color: Color
    var isProminent: Bool = false

    var body: some View {
        VStack(spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.tertiary)
                .tracking(0.6)
            Text(value)
                .font(isProminent ? .title3 : .subheadline)
                .fontWeight(isProminent ? .bold : .medium)
                .monospacedDigit()
                .foregroundStyle(isProminent ? color : .primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isProminent ? color.opacity(0.3) : .clear, lineWidth: 1)
        )
    }
}

// MARK: - Invoice Item Row

struct InvoiceItemRow: View {
    let item: Entity

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.description)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text(item.str("subtotal_formatted"))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }
            HStack(spacing: 12) {
                let unit = item.str("unit").isEmpty ? "hour" : item.str("unit")
                Label(String(format: "%.1f %@", item.num("quantity"), unit), systemImage: "number")
                Label(item.str("unit_price_formatted") + "/" + unit, systemImage: "banknote")
                Label(item.vatPercent + " VAT", systemImage: "percent")
                Spacer()
                let itemDateRange = item.dateRange
                if !itemDateRange.isEmpty {
                    Text(itemDateRange)
                        .foregroundStyle(.tertiary)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Action Button

struct ActionButton: View {
    let label: String
    let icon: String
    let color: Color
    var isActive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: isActive ? icon + ".fill" : icon)
                    .font(.title3)
                Text(label)
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .foregroundStyle(isActive ? .white : color)
            .background(
                isActive ? AnyShapeStyle(color) : AnyShapeStyle(color.opacity(0.1)),
                in: RoundedRectangle(cornerRadius: 8)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Entity date formatting helper

extension Entity {
    static func formatDateStr(_ iso: String) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        guard let d = fmt.date(from: iso) else { return iso }
        fmt.dateFormat = "MMM d, yyyy"
        return fmt.string(from: d)
    }
}
