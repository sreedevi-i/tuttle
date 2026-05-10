import SwiftUI

struct ProjectsView: View {
    @State private var viewModel = BusinessViewModel()
    @State private var selectedProject: ProjectModel?
    @State private var statusFilter: EntityStatus = .all
    @State private var searchText = ""

    private var filtered: [ProjectModel] {
        viewModel.projects.filter { p in
            (statusFilter == .all || p.status == statusFilter)
            && (searchText.isEmpty
                || p.title.localizedCaseInsensitiveContains(searchText)
                || p.clientName.localizedCaseInsensitiveContains(searchText)
                || p.tag.localizedCaseInsensitiveContains(searchText))
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
                            Button(project.isCompleted ? "Mark Active" : "Mark Completed") {
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
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 12) {
                        InitialsAvatar(
                            text: String(project.title.prefix(2)).uppercased(),
                            color: project.status.color,
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
                                StatusBadge(status: project.status)
                            }
                        }
                    }

                    Divider()

                    DetailSection(title: "Details") {
                        DetailRow(label: "Client", value: project.clientName)
                        DetailRow(label: "Contract", value: project.contractTitle)
                        DetailRow(label: "Period", value: project.dateRange)
                    }

                    if !project.description.isEmpty {
                        DetailSection(title: "Description") {
                            Text(project.description)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }

                    DetailSection(title: "Activity") {
                        HStack(spacing: 20) {
                            StatPill(label: "Invoices", value: "\(project.numInvoices)", icon: "doc.text")
                            StatPill(label: "Timesheets", value: "\(project.numTimesheets)", icon: "clock")
                        }
                    }
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
    let project: ProjectModel

    var body: some View {
        HStack(spacing: 12) {
            InitialsAvatar(
                text: String(project.title.prefix(2)).uppercased(),
                color: project.status.color,
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
                Text(project.clientName.isEmpty ? "No client" : project.clientName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            StatusBadge(status: project.status)
        }
        .padding(.vertical, 4)
    }
}

extension ProjectModel: Hashable {
    static func == (lhs: ProjectModel, rhs: ProjectModel) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
