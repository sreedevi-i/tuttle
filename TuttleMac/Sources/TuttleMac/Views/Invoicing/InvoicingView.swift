import SwiftUI

struct InvoicingView: View {
    @State private var viewModel = InvoicingViewModel()
    @State private var selectedInvoice: InvoiceModel?
    @State private var statusFilter: InvoiceStatus = .all
    @State private var searchText = ""

    private var filtered: [InvoiceModel] {
        viewModel.invoices.filter { inv in
            (statusFilter == .all || inv.status == statusFilter)
            && (searchText.isEmpty
                || inv.number.localizedCaseInsensitiveContains(searchText)
                || inv.clientName.localizedCaseInsensitiveContains(searchText)
                || inv.projectTitle.localizedCaseInsensitiveContains(searchText))
        }
    }

    private var totalFiltered: Double {
        filtered.reduce(0) { $0 + $1.total }
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
    private func statusContextMenu(for invoice: InvoiceModel) -> some View {
        if !invoice.cancelled {
            Button(invoice.sent ? "Mark as Not Sent" : "Mark as Sent") {
                viewModel.toggleSent(invoice.id)
            }
            Button(invoice.paid ? "Mark as Unpaid" : "Mark as Paid") {
                viewModel.togglePaid(invoice.id)
            }
        }
        Button(invoice.cancelled ? "Restore Invoice" : "Cancel Invoice") {
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

    private func invoiceHeader(_ invoice: InvoiceModel) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.title2)
                .foregroundStyle(invoice.status.color)
                .frame(width: 48, height: 48)
                .background(invoice.status.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(invoice.number.isEmpty ? "Draft" : invoice.number)
                    .font(.title2)
                    .fontWeight(.bold)
                HStack(spacing: 6) {
                    Text(invoice.clientName.isEmpty ? "No client" : invoice.clientName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    InvoiceStatusBadge(status: invoice.status)
                }
            }
            Spacer()
        }
    }

    private func invoiceAmounts(_ invoice: InvoiceModel) -> some View {
        HStack(spacing: 12) {
            AmountCard(label: "Subtotal", value: invoice.subtotalFormatted, color: .secondary)
            AmountCard(label: "VAT", value: invoice.vatTotalFormatted, color: .orange)
            AmountCard(label: "Total", value: invoice.totalFormatted, color: invoice.status.color, isProminent: true)
        }
    }

    @ViewBuilder
    private func invoiceItems(_ invoice: InvoiceModel) -> some View {
        if !invoice.items.isEmpty {
            DetailSection(title: "Line Items") {
                VStack(spacing: 0) {
                    ForEach(invoice.items) { item in
                        InvoiceItemRow(item: item)
                        if item.id != invoice.items.last?.id {
                            Divider().padding(.vertical, 4)
                        }
                    }
                }
            }
        }
    }

    private func invoiceDetails(_ invoice: InvoiceModel) -> some View {
        DetailSection(title: "Details") {
            DetailRow(label: "Date", value: invoice.dateFormatted, icon: "calendar")
            if let due = invoice.dueDateFormatted {
                DetailRow(label: "Due", value: due, icon: "clock")
            }
            DetailRow(label: "Project", value: invoice.projectTitle, icon: "folder")
            DetailRow(label: "Contract", value: invoice.contractTitle, icon: "signature")
            DetailRow(label: "Currency", value: invoice.currency, icon: "banknote")
        }
    }

    private func invoiceActions(_ invoice: InvoiceModel) -> some View {
        DetailSection(title: "Actions") {
            HStack(spacing: 10) {
                if !invoice.cancelled {
                    ActionButton(
                        label: invoice.sent ? "Unsend" : "Mark Sent",
                        icon: "paperplane",
                        color: .blue,
                        isActive: invoice.sent
                    ) {
                        viewModel.toggleSent(invoice.id)
                    }
                    ActionButton(
                        label: invoice.paid ? "Unpay" : "Mark Paid",
                        icon: "checkmark.circle",
                        color: .green,
                        isActive: invoice.paid
                    ) {
                        viewModel.togglePaid(invoice.id)
                    }
                }
                ActionButton(
                    label: invoice.cancelled ? "Restore" : "Cancel",
                    icon: invoice.cancelled ? "arrow.uturn.left" : "xmark.circle",
                    color: .orange,
                    isActive: invoice.cancelled
                ) {
                    viewModel.toggleCancelled(invoice.id)
                }
            }
        }
    }
}

// MARK: - Invoice Row

struct InvoiceRow: View {
    let invoice: InvoiceModel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.body)
                .foregroundStyle(invoice.status.color)
                .frame(width: 34, height: 34)
                .background(invoice.status.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(invoice.number.isEmpty ? "Draft" : invoice.number)
                        .font(.body)
                        .fontWeight(.medium)
                    Text(invoice.dateFormatted)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                HStack(spacing: 4) {
                    Text(invoice.clientName.isEmpty ? "No client" : invoice.clientName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !invoice.projectTitle.isEmpty {
                        Text("·")
                            .foregroundStyle(.quaternary)
                        Text(invoice.projectTitle)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(invoice.totalFormatted)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                InvoiceStatusBadge(status: invoice.status)
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
    let item: InvoiceItemModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.description)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text(item.subtotalFormatted)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }
            HStack(spacing: 12) {
                Label(String(format: "%.1f %@", item.quantity, item.unit), systemImage: "number")
                Label(item.unitPriceFormatted + "/" + item.unit, systemImage: "banknote")
                Label(item.vatPercent + " VAT", systemImage: "percent")
                Spacer()
                if !item.dateRange.isEmpty {
                    Text(item.dateRange)
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
