import SwiftUI

// MARK: - Project Column

enum ProjectColumn: String, CaseIterable, BoardColumn {
    case lead = "Lead"
    case offer = "Offer"
    case upcoming = "Upcoming"
    case active = "Active"
    case completed = "Completed"

    var color: Color {
        switch self {
        case .lead: .purple
        case .offer: .orange
        case .upcoming: .blue
        case .active: .green
        case .completed: .secondary
        }
    }

    var icon: String {
        switch self {
        case .lead: "lightbulb"
        case .offer: "envelope.open"
        case .upcoming: "clock"
        case .active: "circle.fill"
        case .completed: "checkmark.circle.fill"
        }
    }

    static func defaultColumn(for project: Entity) -> ProjectColumn {
        switch project.entityStatus {
        case .active: .active
        case .upcoming: .upcoming
        case .completed: .completed
        case .all: .active
        }
    }
}

// MARK: - Project Card Content

struct ProjectCardContent: View {
    let project: Entity

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(project.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                Spacer()
                if !project.str("tag").isEmpty {
                    Text(project.tag)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
                }
            }

            if !project.str("client_name").isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "building.2")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(project.str("client_name"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !project.str("contract_title").isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "signature")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(project.str("contract_title"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            HStack(spacing: 12) {
                if !project.dateRange.isEmpty {
                    HStack(spacing: 3) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                        Text(project.dateRange)
                            .font(.caption2)
                    }
                    .foregroundStyle(.tertiary)
                }

                Spacer()

                HStack(spacing: 8) {
                    if project.int("num_invoices") > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "doc.text")
                                .font(.caption2)
                            Text("\(project.int("num_invoices"))")
                                .font(.caption2)
                        }
                        .foregroundStyle(.tertiary)
                    }
                    if project.int("num_timesheets") > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "clock")
                                .font(.caption2)
                            Text("\(project.int("num_timesheets"))")
                                .font(.caption2)
                        }
                        .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }
}
