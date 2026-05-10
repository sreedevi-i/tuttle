import SwiftUI

struct ContactsView: View {
    @State private var viewModel = BusinessViewModel()
    @State private var selectedContact: Entity?
    @State private var searchText = ""
    @State private var showingForm = false
    @State private var editingEntity: Entity?

    private var filtered: [Entity] {
        if searchText.isEmpty { return viewModel.contacts }
        return viewModel.contacts.filter {
            $0.fullName.localizedCaseInsensitiveContains(searchText)
            || $0.str("company").localizedCaseInsensitiveContains(searchText)
            || $0.str("email").localizedCaseInsensitiveContains(searchText)
            || $0.location.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            contactList
            Divider()
            detailPane
                .frame(minWidth: 280, maxWidth: 380)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Contacts")
        .searchable(text: $searchText, prompt: "Search contacts…")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { editingEntity = nil; showingForm = true } label: {
                    Label("Add Contact", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingForm) {
            ContactFormSheet(viewModel: viewModel, editing: editingEntity)
        }
        .onAppear { viewModel.loadAll() }
        .refreshable { viewModel.loadAll() }
    }

    // MARK: - List

    private var contactList: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Text("\(filtered.count) contacts")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            if viewModel.isLoading && viewModel.contacts.isEmpty {
                ProgressView("Loading contacts…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filtered.isEmpty {
                Group {
                    if searchText.isEmpty {
                        ContentUnavailableView(
                            "No Contacts",
                            systemImage: "person.2",
                            description: Text("Contacts will appear here.")
                        )
                    } else {
                        ContentUnavailableView.search(text: searchText)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filtered, selection: $selectedContact) { contact in
                    ContactRow(contact: contact)
                        .tag(contact)
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                viewModel.deleteContact(contact.id)
                                if selectedContact?.id == contact.id {
                                    selectedContact = nil
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
        if let contact = selectedContact {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 12) {
                        InitialsAvatar(text: contact.initials, color: .purple, size: 52)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(contact.displayName)
                                .font(.title2)
                                .fontWeight(.bold)
                            if !contact.str("company").isEmpty {
                                Text(contact.company)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Divider()

                    DetailSection(title: "Contact Info") {
                        if !contact.str("email").isEmpty {
                            DetailRow(label: "Email", value: contact.email, icon: "envelope")
                        }
                        if !contact.location.isEmpty {
                            DetailRow(label: "Location", value: contact.location, icon: "mappin")
                        }
                    }

                    Button {
                        editingEntity = contact
                        showingForm = true
                    } label: {
                        Label("Edit Contact", systemImage: "pencil")
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
                systemImage: "person.2",
                description: Text("Select a contact to view details.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Contact Row

struct ContactRow: View {
    let contact: Entity

    var body: some View {
        HStack(spacing: 12) {
            InitialsAvatar(text: contact.initials, color: .purple, size: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(contact.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                HStack(spacing: 4) {
                    if !contact.str("company").isEmpty {
                        Text(contact.company)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if !contact.str("email").isEmpty {
                        if !contact.str("company").isEmpty {
                            Text("·").foregroundStyle(.quaternary)
                        }
                        Text(contact.email)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            if !contact.location.isEmpty {
                Text(contact.location)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}
