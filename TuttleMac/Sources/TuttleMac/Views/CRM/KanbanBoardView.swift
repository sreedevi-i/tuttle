import SwiftUI

// MARK: - BoardColumn Protocol

protocol BoardColumn: RawRepresentable<String>, CaseIterable, Identifiable, Hashable, Sendable
where AllCases: RandomAccessCollection {
    var color: Color { get }
    var icon: String { get }
}

extension BoardColumn {
    var id: String { rawValue }
}

// MARK: - Draggable Entity ID (Transferable)

struct DraggableEntityID: Codable, Transferable {
    let entityId: Int

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
    }
}

// MARK: - Stage Store

/// Persists entity-to-column assignments in UserDefaults, namespaced by a key prefix.
/// Entities without an explicit assignment fall back to a `defaultColumn` closure.
@Observable
final class StageStore<C: BoardColumn> {
    private let storageKey: String
    private let defaultColumn: (Entity) -> C
    private(set) var stages: [Int: String] = [:]

    init(key: String, defaultColumn: @escaping (Entity) -> C) {
        self.storageKey = "tuttle.board.\(key)"
        self.defaultColumn = defaultColumn
        if let dict = UserDefaults.standard.dictionary(forKey: storageKey) as? [String: String] {
            stages = dict.reduce(into: [:]) { result, pair in
                if let id = Int(pair.key) { result[id] = pair.value }
            }
        }
    }

    func column(for entity: Entity) -> C {
        if let raw = stages[entity.id], let col = C(rawValue: raw) {
            return col
        }
        return defaultColumn(entity)
    }

    func setColumn(_ column: C, for entityId: Int) {
        stages[entityId] = column.rawValue
        persist()
    }

    func removeEntity(_ entityId: Int) {
        stages.removeValue(forKey: entityId)
        persist()
    }

    private func persist() {
        let dict = stages.reduce(into: [String: String]()) { $0[String($1.key)] = $1.value }
        UserDefaults.standard.set(dict, forKey: storageKey)
    }
}

// MARK: - Generic Kanban Board View

struct KanbanBoardView<C: BoardColumn, CardContent: View>: View {
    let entities: [Entity]
    let stageStore: StageStore<C>
    let searchText: String
    let onMove: (Int, C) -> Void
    let onTap: (Entity) -> Void
    let onDelete: (Entity) -> Void
    @ViewBuilder let cardContent: (Entity, C) -> CardContent

    private func entities(for column: C) -> [Entity] {
        entities.filter { stageStore.column(for: $0) == column }
    }

    var body: some View {
        VStack(spacing: 0) {
            boardHeader
            Divider()
            boardColumns
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Header

    private var boardHeader: some View {
        HStack(spacing: 16) {
            ForEach(Array(C.allCases), id: \.id) { column in
                let count = entities(for: column).count
                HStack(spacing: 6) {
                    Image(systemName: column.icon)
                        .foregroundStyle(column.color)
                        .font(.caption)
                    Text(column.rawValue)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("\(count)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(column.color.opacity(0.7), in: Capsule())
                }
            }
            Spacer()
            Text("\(entities.count) total")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Columns

    private var boardColumns: some View {
        HStack(alignment: .top, spacing: 0) {
            let allColumns = Array(C.allCases)
            ForEach(allColumns, id: \.id) { column in
                KanbanColumnView(
                    column: column,
                    entities: entities(for: column),
                    onDrop: { entityId in onMove(entityId, column) },
                    onTap: onTap,
                    onDelete: onDelete,
                    allColumns: allColumns,
                    cardContent: cardContent
                )

                if column != allColumns.last {
                    Divider()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Generic Kanban Column

struct KanbanColumnView<C: BoardColumn, CardContent: View>: View {
    let column: C
    let entities: [Entity]
    let onDrop: (Int) -> Void
    let onTap: (Entity) -> Void
    let onDelete: (Entity) -> Void
    let allColumns: [C]
    @ViewBuilder let cardContent: (Entity, C) -> CardContent

    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            columnHeader
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 8)

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(entities) { entity in
                        KanbanCardWrapper(
                            entity: entity,
                            column: column,
                            allColumns: allColumns,
                            onTap: { onTap(entity) },
                            onDelete: { onDelete(entity) }
                        ) {
                            cardContent(entity, column)
                        }
                        .draggable(DraggableEntityID(entityId: entity.id))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(isTargeted ? column.color.opacity(0.06) : Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .strokeBorder(
                    isTargeted ? column.color.opacity(0.3) : .clear,
                    lineWidth: 2
                )
        )
        .dropDestination(for: DraggableEntityID.self) { items, _ in
            guard let item = items.first else { return false }
            onDrop(item.entityId)
            return true
        } isTargeted: { targeted in
            isTargeted = targeted
        }
    }

    private var columnHeader: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(column.color)
                .frame(width: 8, height: 8)
            Text(column.rawValue.uppercased())
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
                .tracking(1)
            Spacer()
        }
    }
}

// MARK: - Card Wrapper (hover, context menu, chrome)

struct KanbanCardWrapper<C: BoardColumn, Content: View>: View {
    let entity: Entity
    let column: C
    let allColumns: [C]
    let onTap: () -> Void
    let onDelete: () -> Void
    @ViewBuilder let content: Content

    @State private var isHovered = false

    var body: some View {
        content
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(.background)
                    .shadow(
                        color: .black.opacity(isHovered ? 0.12 : 0.06),
                        radius: isHovered ? 6 : 3,
                        y: isHovered ? 2 : 1
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        column.color.opacity(isHovered ? 0.3 : 0.1),
                        lineWidth: 1
                    )
            )
            .contentShape(Rectangle())
            .onHover { isHovered = $0 }
            .onTapGesture(perform: onTap)
            .contextMenu {
                ForEach(allColumns.filter { $0 != column }, id: \.id) { col in
                    Button("Move to \(col.rawValue)") {
                        NotificationCenter.default.post(
                            name: .kanbanMove,
                            object: nil,
                            userInfo: ["entityId": entity.id, "column": col.rawValue]
                        )
                    }
                }
                Divider()
                Button("Delete", role: .destructive) {
                    onDelete()
                }
            }
            .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
}

// MARK: - Column Badge

struct ColumnBadge<C: BoardColumn>: View {
    let column: C

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: column.icon)
                .font(.caption2)
            Text(column.rawValue)
                .font(.caption2)
                .fontWeight(.semibold)
        }
        .foregroundStyle(column.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(column.color.opacity(0.1), in: Capsule())
    }
}

// MARK: - Shared Notification

extension Notification.Name {
    static let kanbanMove = Notification.Name("tuttle.kanbanMove")
}
