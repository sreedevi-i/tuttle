import SwiftUI

struct ContentView: View {
    @State private var selectedItem: SidebarItem? = .dashboard

    var body: some View {
        NavigationSplitView {
            Sidebar(selection: $selectedItem)
                .frame(minWidth: 180)
        } detail: {
            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch selectedItem {
        case .dashboard:
            DashboardView()
        case .timeline:
            TimelineView()
        case .projects:
            ProjectsView()
        case .contracts:
            ContractsView()
        case .clients:
            ClientsView()
        case .contacts:
            ContactsView()
        case .invoicing:
            InvoicingView()
        case .none:
            ContentUnavailableView(
                "Select an Item",
                systemImage: "sidebar.left",
                description: Text("Choose a section from the sidebar.")
            )
        default:
            ContentUnavailableView(
                selectedItem?.rawValue ?? "Coming Soon",
                systemImage: selectedItem?.systemImage ?? "hammer",
                description: Text("This section is not yet implemented.")
            )
        }
    }
}
