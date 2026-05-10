import SwiftUI

struct ProjectsView: View {
    @State private var viewModel = BusinessViewModel()
    @State private var selectedProject: Entity?
    @State private var statusFilter: EntityStatus = .all
    @State private var searchText = ""
    @State private var showingForm = false
    @State private var editingEntity: Entity?

    private var filtered: [Entity] {
        viewModel.projects.filter { p in
            (statusFilter == .all || p.entityStatus == statusFilter)
            && (searchText.isEmpty
                || p.str("title").localizedCaseInsensitiveContains(searchText)
                || p.str("client_name").localizedCaseInsensitiveContains(searchText)
                || p.str("tag").localizedCaseInsensitiveContains(searchText))
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            projectList
            Divider()
            detailPane
                .frame(minWidth: 280, maxWidth: 380)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Projects")
        .searchable(text: $searchText, prompt: "Search projects…")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { editingEntity = nil; showingForm = true } label: {
                    Label("Add Project", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingForm) {
            ProjectFormSheet(viewModel: viewModel, editing: editingEntity)
        }
        .onAppear { viewModel.loadAll() }
        .refreshable { viewModel.loadAll() }
    }

    // MARK: - List

    private var projectList: some View {
        VStack(spacing: 0) {
            statusFilterBar
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

            Divider()

            if viewModel.isLoading && viewModel.projects.isEmpty {
                ProgressView("Loading projects…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filtered.isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filtered, selection: $selectedProject) { project in
                    ProjectRow(project: project)
                        .tag(project)
                        .contextMenu {
                            Button(project.bool("is_completed") ? "Mark Active" : "Mark Completed") {
                                viewModel.toggleProjectCompleted(project.id)
                            }
                            Divider()
                            Button("Delete", role: .destructive) {
                                viewModel.deleteProject(project.id)
                                if selectedProject?.id == project.id {
                                    selectedProject = nil
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
            Text("\(filtered.count) projects")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailPane: some View {
        if let project = selectedProject {
            let status = project.entityStatus
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 12) {
                        InitialsAvatar(
                            text: String(project.str("title").prefix(2)).uppercased(),
                            color: status.color,
                            size: 48
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(project.title)
                                .font(.title2)
                                .fontWeight(.bold)
                            HStack(spacing: 6) {
                                Text(project.tag)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                StatusBadge(status: status)
                            }
                        }
                    }

                    Divider()

                    DetailSection(title: "Details") {
                        DetailRow(label: "Client", value: project.str("client_name"))
                        DetailRow(label: "Contract", value: project.str("contract_title"))
                        DetailRow(label: "Period", value: project.dateRange)
                    }

                    if !project.str("description").isEmpty {
                        DetailSection(title: "Description") {
                            Text(project.description)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }

                    DetailSection(title: "Activity") {
                        HStack(spacing: 20) {
                            StatPill(label: "Invoices", value: "\(project.int("num_invoices"))", icon: "doc.text")
                            StatPill(label: "Timesheets", value: "\(project.int("num_timesheets"))", icon: "clock")
                        }
                    }

                    Button {
                        editingEntity = project
                        showingForm = true
                    } label: {
                        Label("Edit Project", systemImage: "pencil")
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
                systemImage: "folder",
                description: Text("Select a project to view details.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Project Row

struct ProjectRow: View {
    let project: Entity

    var body: some View {
        let status = project.entityStatus
        HStack(spacing: 12) {
            InitialsAvatar(
                text: String(project.str("title").prefix(2)).uppercased(),
                color: status.color,
                size: 34
            )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(project.title)
                        .font(.body)
                        .fontWeight(.medium)
                    Text(project.tag)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 3))
                }
                Text(project.str("client_name").isEmpty ? "No client" : project.str("client_name"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            StatusBadge(status: status)
        }
        .padding(.vertical, 4)
    }
}
