import SwiftUI

struct AppSidebarView: View {
    @Binding var selection: AppRoute

    var body: some View {
        List(selection: $selection) {
            Section("EchoKeys") {
                ForEach(AppRoute.productRoutes) { route in
                    Label(route.title, systemImage: route.systemImage)
                        .tag(route)
                }
            }

            Section("Dev Lab") {
                ForEach(AppRoute.devRoutes) { route in
                    Label(route.title, systemImage: route.systemImage)
                        .tag(route)
                }
            }
        }
        .navigationTitle("EchoKeys")
        .listStyle(.sidebar)
    }
}
