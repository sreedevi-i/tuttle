import Foundation
import PythonKit

@Observable
final class TimelineViewModel {
    var events: [TimelineEvent] = []
    var activeFilter: TimelineCategory = .all
    var searchQuery: String = ""
    var isLoading = false
    var errorMessage: String?

    var filteredEvents: [TimelineEvent] {
        var result = events
        if activeFilter != .all {
            result = result.filter { $0.category == activeFilter }
        }
        if !searchQuery.isEmpty {
            let q = searchQuery.lowercased()
            result = result.filter {
                $0.title.lowercased().contains(q)
                || $0.description.lowercased().contains(q)
            }
        }
        return result
    }

    /// Events grouped by month, preserving the descending date order.
    var groupedEvents: [(key: String, label: String, events: [TimelineEvent])] {
        let filtered = filteredEvents
        var groups: [(key: String, label: String, events: [TimelineEvent])] = []
        var currentKey = ""
        var currentEvents: [TimelineEvent] = []
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

        PythonBridge.shared.run({ bridge -> [TimelineEvent] in
            let result = bridge.get_timeline_events()
            var parsed: [TimelineEvent] = []
            if PythonBridge.bool(result, key: "ok") {
                for item in result["events"] {
                    if let event = TimelineEvent.from(item) {
                        parsed.append(event)
                    }
                }
            }
            return parsed
        }, completion: { [self] parsed in
            self.events = parsed
            self.isLoading = false
        })
    }
}
