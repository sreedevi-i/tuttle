import SwiftUI

struct ClientsView: View {
    @State private var viewModel = BusinessViewModel()
    @State private var selectedClient: ClientModel?
    @State private var searchText = ""

    private var filtered: [ClientModel] {
        if searchText.isEmpty { return viewModel.clients }
        return viewModel.clients.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
            || $0.contactName.localizedCaseInsensitiveContains(searchText)
            || $0.location.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            clientList
            Divider()
            detailPane
                .frame(minWidth: 280, maxWidth: 380)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Clients")
        .searchable(text: $searchText, prompt: "Search clients…")
        .onAppear { viewModel.loadAll() }
        .refreshable { viewModel.loadAll() }
    }

    // MARK: - List

    private var clientList: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Text("\(filtered.count) clients")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            if viewModel.isLoading && viewModel.clients.isEmpty {
                ProgressView("Loading clients…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filtered.isEmpty {
                Group {
                    if searchText.isEmpty {
                        ContentUnavailableView(
                            "No Clients",
                            systemImage: "building.2",
                            description: Text("Add your first client to get started.")
                        )
                    } else {
                        ContentUnavailableView.search(text: searchText)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filtered, selection: $selectedClient) { client in
                    ClientRow(client: client)
                        .tag(client)
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                viewModel.deleteClient(client.id)
                                if selectedClient?.id == client.id {
                                    selectedClient = nil
                                }
                            }
                        }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailPane: some View {
        if let client = selectedClient {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 12) {
                        InitialsAvatar(text: client.initials, color: .blue, size: 52)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(client.name)
                                .font(.title2)
                                .fontWeight(.bold)
                            if !client.location.isEmpty {
                                Label(client.location, systemImage: "mappin")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Divider()

                    DetailSection(title: "Contact") {
                        DetailRow(label: "Name", value: client.contactName, icon: "person")
                        DetailRow(label: "Email", value: client.contactEmail, icon: "envelope")
                        if !client.contactCompany.isEmpty {
                            DetailRow(label: "Company", value: client.contactCompany, icon: "building.2")
                        }
                    }

                    DetailSection(title: "Business") {
                        HStack(spacing: 20) {
                            StatPill(label: "Contracts", value: "\(client.numContracts)", icon: "signature")
                        }
                    }
                }
                .padding(20)
            }
            .frame(maxHeight: .infinity)
        } else {
            ContentUnavailableView(
                "No Selection",
                systemImage: "building.2",
                description: Text("Select a client to view details.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Client Row

struct ClientRow: View {
    let client: ClientModel

    var body: some View {
        HStack(spacing: 12) {
            InitialsAvatar(text: client.initials, color: .blue, size: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(client.name)
                    .font(.body)
                    .fontWeight(.medium)
                HStack(spacing: 4) {
                    if !client.contactName.isEmpty {
                        Text(client.contactName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if !client.location.isEmpty {
                        Text("·")
                            .foregroundStyle(.quaternary)
                        Text(client.location)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            if client.numContracts > 0 {
                Text("\(client.numContracts)")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }
        }
        .padding(.vertical, 4)
    }
}

extension ClientModel: Hashable {
    static func == (lhs: ClientModel, rhs: ClientModel) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
