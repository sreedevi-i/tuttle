import SwiftUI

struct Sidebar: View {
    @Binding var selection: SidebarItem?

    var body: some View {
        List(selection: $selection) {
            ForEach(SidebarItem.grouped(), id: \.0) { section, items in
                Section(section.rawValue) {
                    ForEach(items) { item in
                        Label(item.rawValue, systemImage: item.systemImage)
                            .tag(item)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Tuttle")
    }
}
