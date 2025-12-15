//
//  BottleAnnotationView.swift
//  Drift
//
//  Map pin rendering for individual bottles.
//  This file is intentionally self-contained and UI-only.
//

import SwiftUI

// ----------------------------------------------------------
// MARK: - View Model
// ----------------------------------------------------------

/// UI-only view model responsible for deriving presentation state
/// from a MapAnnotationItem. No business logic, no side effects.
final class BottleAnnotationViewModel: ObservableObject {

    // ------------------------------------------------------
    // MARK: - Input
    // ------------------------------------------------------

    let item: MapAnnotationItem

    // ------------------------------------------------------
    // MARK: - Derived Presentation State
    // ------------------------------------------------------

    enum PinStyle {
        case locked
        case active
        case expiringSoon
        case expired
        case premium
        case specialEvent
    }

    var pinStyle: PinStyle {
        if item.status.dead {
            return .expired
        }

        if item.status.locked {
            return .locked
        }

        if let expiresAt = item.expiresAt {
            let remaining = expiresAt - Date().timeIntervalSince1970
            if remaining > 0 && remaining < 3600 {
                return .expiringSoon
            }
        }

        // NOTE:
        // Premium / specialEvent are placeholders for future rules
        // (e.g. paid bottles, featured content, events).
        return .active
    }

    init(item: MapAnnotationItem) {
        self.item = item
    }
}

// ----------------------------------------------------------
// MARK: - Bottle Annotation View
// ----------------------------------------------------------

struct BottleAnnotationView: View {

    // ------------------------------------------------------
    // MARK: - State
    // ------------------------------------------------------

    @StateObject private var vm: BottleAnnotationViewModel
    let onTap: () -> Void

    // ------------------------------------------------------
    // MARK: - Init
    // ------------------------------------------------------

    init(
        item: MapAnnotationItem,
        onTap: @escaping () -> Void
    ) {
        _vm = StateObject(wrappedValue: BottleAnnotationViewModel(item: item))
        self.onTap = onTap
    }

    // ------------------------------------------------------
    // MARK: - Body
    // ------------------------------------------------------

    var body: some View {
        Button(action: onTap) {
            pinBody
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    // ------------------------------------------------------
    // MARK: - Pin Rendering
    // ------------------------------------------------------

    @ViewBuilder
    private var pinBody: some View {
        switch vm.pinStyle {

        case .locked:
            Image("pin_bottle_locked")
                .pinBaseStyle()

        case .active:
            Image("pin_bottle_active")
                .pinBaseStyle()

        case .expiringSoon:
            ZStack {
                Image("pin_bottle_active")
                    .pinBaseStyle()

                // NOTE:
                // Subtle visual hint that this bottle expires soon.
                // Could later be replaced with a ring countdown animation.
                Circle()
                    .stroke(Color.orange, lineWidth: 2)
                    .frame(width: 34, height: 34)
            }

        case .expired:
            Image("pin_bottle_expired")
                .pinBaseStyle()
                .opacity(0.6)

        case .premium:
            Image("pin_bottle_premium")
                .pinBaseStyle()

        case .specialEvent:
            Image("pin_bottle_event")
                .pinBaseStyle()
        }
    }

    // ------------------------------------------------------
    // MARK: - Accessibility
    // ------------------------------------------------------

    private var accessibilityLabel: Text {
        switch vm.pinStyle {
        case .locked:
            return Text("Locked bottle")
        case .active:
            return Text("Bottle")
        case .expiringSoon:
            return Text("Bottle expiring soon")
        case .expired:
            return Text("Expired bottle")
        case .premium:
            return Text("Premium bottle")
        case .specialEvent:
            return Text("Special event bottle")
        }
    }
}

// ----------------------------------------------------------
// MARK: - Pin Styling Helpers
// ----------------------------------------------------------

private extension Image {

    /// Shared base styling for all bottle pin images.
    /// Keeps pins visually consistent and lightweight.
    func pinBaseStyle() -> some View {
        self
            .resizable()
            .frame(width: 160, height: 160)
            .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)

        // NOTE:
        // Avoid heavy effects here (blur, large shadows, gradients).
        // MapKit renders many pins simultaneously.
    }
}
