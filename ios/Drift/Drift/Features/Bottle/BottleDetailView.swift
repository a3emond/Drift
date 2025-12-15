//
//  BottleDetailView.swift
//  Drift
//
//  Created by alexandre emond on 2025-12-14.
//


//
//  BottleDetailView.swift
//  Drift
//

import SwiftUI

struct BottleDetailView: View {

    // ------------------------------------------------------
    // MARK: - State
    // ------------------------------------------------------

    @StateObject private var vm: BottleDetailViewModel

    // ------------------------------------------------------
    // MARK: - Init
    // ------------------------------------------------------

    init(
        bottleId: String,
        logger: Logging
    ) {
        _vm = StateObject(
            wrappedValue: BottleDetailViewModel(
                bottleId: bottleId,
                logger: logger
            )
        )
    }

    // ------------------------------------------------------
    // MARK: - Body
    // ------------------------------------------------------

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Bottle")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") {
                            vm.dismiss()
                        }
                    }
                }
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            vm.start()
        }
    }

    @ViewBuilder
    private var content: some View {
        if vm.isLoading {
            ProgressView()
                .padding()
        } else if let error = vm.errorMessage {
            Text(error)
                .foregroundColor(.secondary)
                .padding()
        } else {
            VStack(spacing: 16) {

                // --------------------------------------------------
                // Bottle Preview
                // --------------------------------------------------

                Text("Bottle ID")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(vm.bottleId)
                    .font(.footnote)
                    .textSelection(.enabled)

                Divider()

                // --------------------------------------------------
                // Placeholder Sections
                // --------------------------------------------------

                Text("Bottle content will appear here.")
                    .foregroundColor(.secondary)

                // NOTE:
                // This is where:
                // - text content
                // - images
                // - audio playback
                // - conditions (locked, time window, distance)
                // will be rendered.

                Spacer()
            }
            .padding()
        }
    }
}
