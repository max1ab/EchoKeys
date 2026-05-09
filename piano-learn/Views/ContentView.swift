//
//  ContentView.swift
//  piano-learn
//
//  Created by r00t on 2026/4/12.
//

import SwiftUI

struct ContentView: View {
    @SceneStorage("selectedAppRoute") private var selectedRouteRawValue = AppRoute.home.rawValue
    @StateObject private var midiInputDebugController = MIDIInputDebugController()
    @StateObject private var practiceDebugController = PracticeDebugController()

    private var selectedRoute: Binding<AppRoute> {
        Binding {
            AppRoute(rawValue: selectedRouteRawValue) ?? .home
        } set: { newValue in
            selectedRouteRawValue = newValue.rawValue
        }
    }

    var body: some View {
        NavigationSplitView {
            AppSidebarView(selection: selectedRoute)
        } detail: {
            switch selectedRoute.wrappedValue {
            case .home:
                HomeView()
            case .practiceHome:
                PracticeHomeView()
            case .devMIDIInput:
                MIDIInputDebugView(controller: midiInputDebugController)
            case .devPractice:
                PracticeDebugView(controller: practiceDebugController)
            case .devConverter:
                ConverterDemoView()
            }
        }
        .frame(minWidth: 900, minHeight: 600)
    }
}

#Preview {
    ContentView()
}
