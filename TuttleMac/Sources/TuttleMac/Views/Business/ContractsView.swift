import SwiftUI

struct ContractsView: View {
    @State private var viewModel = BusinessViewModel()
    @State private var selectedContract: Entity?
    @State private var statusFilter: EntityStatus = .all
    @State private var searchText = ""
    @State private var showingForm = false
    @State private var editingEntity: Entity?

    private var filtered: [Entity] {
        viewModel.contracts.filter { c in
            (statusFilter == .all || c.entityStatus == statusFilter)
            && (searchText.isEmpty
                || c.str("title").localizedCaseInsensitiveContains(searchText)
                || c.str("client_name").localizedCaseInsensitiveContains(searchText))
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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { editingEntity = nil; showingForm = true } label: {
                    Label("Add Contract", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingForm) {
            ContractFormSheet(viewModel: viewModel, editing: editingEntity)
        }
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
                            Button(contract.bool("is_completed") ? "Mark Active" : "Mark Completed") {
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
            let status = contract.entityStatus
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 12) {
                        Image(systemName: "signature")
                            .font(.title2)
                            .foregroundStyle(status.color)
                            .frame(width: 48, height: 48)
                            .background(status.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(contract.title)
                                .font(.title2)
                                .fontWeight(.bold)
                            HStack(spacing: 6) {
                                Text(contract.str("client_name"))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                StatusBadge(status: status)
                            }
                        }
                    }

                    Divider()

                    DetailSection(title: "Terms") {
                        DetailRow(label: "Rate", value: "\(contract.str("rate_formatted")) / \(contract.str("unit_value"))")
                        if let vol = contract.optInt("volume") {
                            DetailRow(label: "Volume", value: "\(vol) \(contract.str("unit_value"))s")
                        }
                        DetailRow(label: "Billing", value: contract.str("billing_cycle_value"))
                        DetailRow(label: "VAT", value: contract.vatPercent)
                        DetailRow(label: "Currency", value: contract.str("currency"))
                    }

                    DetailSection(title: "Period") {
                        DetailRow(label: "Duration", value: contract.dateRange)
                    }

                    DetailSection(title: "Related") {
                        HStack(spacing: 20) {
                            StatPill(label: "Projects", value: "\(contract.int("num_projects"))", icon: "folder")
                            StatPill(label: "Invoices", value: "\(contract.int("num_invoices"))", icon: "doc.text")
                        }
                    }

                    Button {
                        editingEntity = contract
                        showingForm = true
                    } label: {
                        Label("Edit Contract", systemImage: "pencil")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
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
    let contract: Entity

    var body: some View {
        let status = contract.entityStatus
        HStack(spacing: 12) {
            Image(systemName: "signature")
                .font(.body)
                .foregroundStyle(status.color)
                .frame(width: 34, height: 34)
                .background(status.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 2) {
                Text(contract.title)
                    .font(.body)
                    .fontWeight(.medium)
                HStack(spacing: 4) {
                    Text(contract.str("client_name"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.quaternary)
                    Text(contract.str("rate_formatted") + "/\(contract.str("unit_value"))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            StatusBadge(status: status)
        }
        .padding(.vertical, 4)
    }
}
