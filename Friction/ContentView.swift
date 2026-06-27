//
//  ContentView.swift
//  Friction
//
//  Created by Nick Davis on 6/26/26.
//

import SwiftUI
import FamilyControls
import DeviceActivity

struct ContentView: View {
    @State private var isPickerPresented = false
    @State private var selection = FamilyActivitySelection()
    @State private var isAuthorized = false

    private let activityCenter = DeviceActivityCenter()

    var body: some View {
        VStack(spacing: 24) {
            if !isAuthorized {
                Text("Friction needs permission to block apps.")
                    .multilineTextAlignment(.center)
                Button("Enable Friction") {
                    Task {
                        try? await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                        isAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
                    }
                }
                .buttonStyle(.borderedProminent)
            } else {
                Text("Friction is active.")
                    .font(.headline)
                Text("\(selection.applicationTokens.count) app(s) blocked 9am–5pm")
                    .foregroundStyle(.secondary)
                Button("Change blocked apps") {
                    isPickerPresented = true
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .familyActivityPicker(isPresented: $isPickerPresented, selection: $selection)
        .onChange(of: selection) { _, newValue in
            SharedState.saveSelection(newValue)
            startMonitoring()
        }
        .onAppear {
            isAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
        }
    }

    private func startMonitoring() {
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 9, minute: 0),
            intervalEnd: DateComponents(hour: 17, minute: 0),
            repeats: true
        )
        activityCenter.stopMonitoring([.work])
        try? activityCenter.startMonitoring(.work, during: schedule)
    }
}

#Preview {
    ContentView()
}
