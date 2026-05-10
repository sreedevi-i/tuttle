import SwiftUI

struct TimelineView: View {
    @State private var viewModel = TimelineViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.events.isEmpty {
                ProgressView("Loading timeline…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.filteredEvents.isEmpty && !viewModel.events.isEmpty {
                ContentUnavailableView.search(text: viewModel.searchQuery)
            } else if viewModel.events.isEmpty {
                ContentUnavailableView(
                    "No Events Yet",
                    systemImage: "calendar.day.timeline.left",
                    description: Text("Create invoices, contracts, or projects to see them here.")
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        filterBar
                            .padding(.bottom, 16)

                        timelineContent
                    }
                    .padding(24)
                }
            }
        }
        .navigationTitle("Timeline")
        .searchable(text: $viewModel.searchQuery, prompt: "Search events…")
        .onAppear { viewModel.loadEvents() }
        .refreshable { viewModel.loadEvents() }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        HStack(spacing: 6) {
            ForEach(TimelineCategory.allCases) { category in
                FilterChip(
                    label: category.label,
                    systemImage: category.systemImage,
                    isActive: viewModel.activeFilter == category,
                    color: Self.categoryColor(category)
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.activeFilter = category
                    }
                }
            }
            Spacer()
        }
    }

    // MARK: - Timeline Content

    private var timelineContent: some View {
        let groups = viewModel.groupedEvents
        let today = Calendar.current.startOfDay(for: Date())
        var todayInserted = false

        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(groups.enumerated()), id: \.element.key) { groupIdx, group in
                MonthHeader(label: group.label)
                    .padding(.top, groupIdx > 0 ? 8 : 0)

                ForEach(Array(group.events.enumerated()), id: \.element.id) { eventIdx, event in
                    let isLast = groupIdx == groups.count - 1
                        && eventIdx == group.events.count - 1

                    if !todayInserted && !event.bool("is_future"),
                       let eventDate = event.date("_date"), eventDate <= today {
                        let _ = { todayInserted = true }()
                        TodayMarker()
                    }

                    TimelineEventCard(event: event, isLast: isLast)
                }
            }

            if !todayInserted {
                TodayMarker()
            }
        }
    }

    static func categoryColor(_ category: TimelineCategory) -> Color {
        switch category {
        case .all: .blue
        case .invoice: .blue
        case .contract: .green
        case .project: .orange
        case .goal: .purple
        }
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let label: String
    let systemImage: String
    let isActive: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(label, systemImage: systemImage)
                .font(.caption)
                .fontWeight(.semibold)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .foregroundStyle(isActive ? .white : color)
                .background(
                    isActive ? AnyShapeStyle(color) : AnyShapeStyle(.clear),
                    in: Capsule()
                )
                .overlay(
                    Capsule()
                        .strokeBorder(color, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Month Header

struct MonthHeader: View {
    let label: String

    var body: some View {
        HStack(spacing: 8) {
            spineSegment
            Text(label)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.tertiary)
                .tracking(0.4)
        }
        .frame(height: 36)
    }

    private var spineSegment: some View {
        Rectangle()
            .fill(.quaternary)
            .frame(width: 2)
            .frame(width: 36, height: 36)
    }
}

// MARK: - Today Marker

struct TodayMarker: View {
    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Rectangle()
                    .fill(.quaternary)
                    .frame(width: 2)
                Circle()
                    .fill(.red)
                    .frame(width: 10, height: 10)
            }
            .frame(width: 36, height: 32)

            Text("Today")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(.red, in: Capsule())

            VStack { Divider() }
        }
    }
}

// MARK: - Event Card

struct TimelineEventCard: View {
    let event: Entity
    var isLast: Bool = false

    private var category: TimelineCategory {
        TimelineCategory(rawValue: event.str("category")) ?? .invoice
    }

    private var dotColor: Color {
        switch event.str("status") {
        case "paid", "completed": .green
        case "overdue", "cancelled": .red
        case "due": TimelineView.categoryColor(category)
        default: TimelineView.categoryColor(category)
        }
    }

    private var categoryColor: Color {
        TimelineView.categoryColor(category)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(.quaternary)
                    .frame(width: 2, height: 14)

                ZStack {
                    Circle()
                        .fill(dotColor.opacity(0.15))
                        .frame(width: 18, height: 18)
                    Circle()
                        .fill(dotColor)
                        .frame(width: 10, height: 10)
                }

                if !isLast {
                    Rectangle()
                        .fill(.quaternary)
                        .frame(width: 2)
                        .frame(minHeight: 46)
                } else {
                    Spacer(minLength: 0)
                }
            }
            .frame(width: 36)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top) {
                    HStack(spacing: 6) {
                        Image(systemName: category.systemImage)
                            .font(.subheadline)
                            .foregroundStyle(dotColor)
                        Text(event.title)
                            .font(.body)
                            .fontWeight(.semibold)
                    }
                    Spacer()
                    Text(event.str("date_formatted"))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                if !event.str("description").isEmpty {
                    Text(event.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text(category.label)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(categoryColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(categoryColor.opacity(0.12), in: Capsule())
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
            .opacity(event.bool("is_future") ? 0.55 : 1.0)
        }
    }
}
