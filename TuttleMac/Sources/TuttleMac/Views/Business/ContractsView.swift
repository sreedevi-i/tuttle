import SwiftUI

struct ContractsView: View {
    @State private var viewModel = BusinessViewModel()
    @State private var selectedContract: ContractModel?
    @State private var statusFilter: EntityStatus = .all
    @State private var searchText = ""

    private var filtered: [ContractModel] {
        viewModel.contracts.filter { c in
            (statusFilter == .all || c.status == statusFilter)
            && (searchText.isEmpty
                || c.title.localizedCaseInsensitiveContains(searchText)
                || c.clientName.localizedCaseInsensitiveContains(searchText))
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            contractList
            Divider()
            detailPane
                .frame(minWidth: 280, maxWidth: 380)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Contracts")
        .searchable(text: $searchText, prompt: "Search contracts…")
        .onAppear { viewModel.loadAll() }
        .refreshable { viewModel.loadAll() }
    }

    // MARK: - List

    private var contractList: some View {
        VStack(spacing: 0) {
            statusFilterBar
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

            Divider()

            if viewModel.isLoading && viewModel.contracts.isEmpty {
                ProgressView("Loading contracts…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filtered.isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filtered, selection: $selectedContract) { contract in
                    ContractRow(contract: contract)
                        .tag(contract)
                        .contextMenu {
                            Button(contract.isCompleted ? "Mark Active" : "Mark Completed") {
                                viewModel.toggleContractCompleted(contract.id)
                            }
                            Divider()
                            Button("Delete", role: .destructive) {
                                viewModel.deleteContract(contract.id)
                                if selectedContract?.id == contract.id {
                                    selectedContract = nil
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
            ForEach([EntityStatus.all, .active, .upcoming, .completed], id: \.rawValue) { status in
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
            Text("\(filtered.count) contracts")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailPane: some View {
        if let contract = selectedContract {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 12) {
                        Image(systemName: "signature")
                            .font(.title2)
                            .foregroundStyle(contract.status.color)
                            .frame(width: 48, height: 48)
                            .background(contract.status.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(contract.title)
                                .font(.title2)
                                .fontWeight(.bold)
                            HStack(spacing: 6) {
                                Text(contract.clientName)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                StatusBadge(status: contract.status)
                            }
                        }
                    }

                    Divider()

                    DetailSection(title: "Terms") {
                        DetailRow(label: "Rate", value: "\(contract.rateFormatted) / \(contract.unit)")
                        if let vol = contract.volume {
                            DetailRow(label: "Volume", value: "\(vol) \(contract.unit)s")
                        }
                        DetailRow(label: "Billing", value: contract.billingCycle)
                        DetailRow(label: "VAT", value: String(format: "%.0f%%", contract.vatRate * 100))
                        DetailRow(label: "Currency", value: contract.currency)
                    }

                    DetailSection(title: "Period") {
                        DetailRow(label: "Duration", value: contract.dateRange)
                    }

                    DetailSection(title: "Related") {
                        HStack(spacing: 20) {
                            StatPill(label: "Projects", value: "\(contract.numProjects)", icon: "folder")
                            StatPill(label: "Invoices", value: "\(contract.numInvoices)", icon: "doc.text")
                        }
                    }
                }
                .padding(20)
            }
            .frame(maxHeight: .infinity)
        } else {
            ContentUnavailableView(
                "No Selection",
                systemImage: "signature",
                description: Text("Select a contract to view details.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Contract Row

struct ContractRow: View {
    let contract: ContractModel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "signature")
                .font(.body)
                .foregroundStyle(contract.status.color)
                .frame(width: 34, height: 34)
                .background(contract.status.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 2) {
                Text(contract.title)
                    .font(.body)
                    .fontWeight(.medium)
                HStack(spacing: 4) {
                    Text(contract.clientName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.quaternary)
                    Text(contract.rateFormatted + "/\(contract.unit)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            StatusBadge(status: contract.status)
        }
        .padding(.vertical, 4)
    }
}

extension ContractModel: Hashable {
    static func == (lhs: ContractModel, rhs: ContractModel) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
