import Foundation
import PythonKit

@Observable
final class TimelineViewModel {
    var events: [Entity] = []
    var activeFilter: TimelineCategory = .all
    var searchQuery: String = ""
    var isLoading = false
    var errorMessage: String?

    var filteredEvents: [Entity] {
        var result = events
        if activeFilter != .all {
            result = result.filter {
                TimelineCategory(rawValue: $0.str("category")) == activeFilter
            }
        }
        if !searchQuery.isEmpty {
            let q = searchQuery.lowercased()
            result = result.filter {
                $0.str("title").lowercased().contains(q)
                || $0.str("description").lowercased().contains(q)
            }
        }
        return result
    }

    var groupedEvents: [(key: String, label: String, events: [Entity])] {
        let filtered = filteredEvents
        var groups: [(key: String, label: String, events: [Entity])] = []
        var currentKey = ""
        var currentEvents: [Entity] = []
        var currentLabel = ""

        for event in filtered {
            let key = event.monthKey
            if key != currentKey {
                if !currentEvents.isEmpty {
                    groups.append((key: currentKey, label: currentLabel, events: currentEvents))
                }
                currentKey = key
                currentLabel = event.monthLabel
                currentEvents = [event]
            } else {
                currentEvents.append(event)
            }
        }
        if !currentEvents.isEmpty {
            groups.append((key: currentKey, label: currentLabel, events: currentEvents))
        }
        return groups
    }

    func loadEvents() {
        isLoading = true
        errorMessage = nil

        PythonBridge.shared.run({
            let result = PythonBridge.shared.timeline.get_timeline_events()
            guard PythonBridge.isOk(result) else { return [Entity]() }

            var entities: [Entity] = []
            for e in result.data {
                let dateStr = String(e.date.isoformat()) ?? ""
                let fmt = DateFormatter()
                fmt.dateFormat = "yyyy-MM-dd"
                guard let date = fmt.date(from: dateStr) else { continue }

                let displayFmt = DateFormatter()
                displayFmt.dateFormat = "MMM d, yyyy"

                let title = String(e.title) ?? ""
                let catStr = String(e.category) ?? "invoice"

                var dict: [String: Any] = [
                    "id": Int(e.entity_id) ?? entities.count,
                    "_date": date,
                    "date_formatted": displayFmt.string(from: date),
                    "title": title,
                    "description": String(e[dynamicMember: "description"]) ?? "",
                    "category": catStr,
                    "status": Self.inferStatus(title),
                    "is_future": Bool(e.is_future) ?? false,
                ]
                if e.entity_id != Python.None {
                    dict["entity_id"] = Int(e.entity_id) ?? 0
                }
                entities.append(Entity(data: dict))
            }
            return entities
        }, completion: { [self] parsed in
            self.events = parsed
            self.isLoading = false
        })
    }

    private static func inferStatus(_ title: String) -> String {
        let t = title.lowercased()
        for kw in ["cancelled", "overdue", "paid", "completed", "reached", "due"] {
            if t.contains(kw) { return kw }
        }
        return "default"
    }
}
