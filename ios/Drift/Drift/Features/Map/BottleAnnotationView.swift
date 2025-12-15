import SwiftUI

// ----------------------------------------------------------
// MARK: - View Model
// ----------------------------------------------------------

final class BottleAnnotationViewModel: ObservableObject {

    let item: MapAnnotationItem

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

    @StateObject private var vm: BottleAnnotationViewModel
    let onTap: () -> Void

    init(
        item: MapAnnotationItem,
        onTap: @escaping () -> Void
    ) {
        _vm = StateObject(wrappedValue: BottleAnnotationViewModel(item: item))
        self.onTap = onTap
    }

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
            Text("Locked bottle")
        case .active:
            Text("Bottle")
        case .expiringSoon:
            Text("Bottle expiring soon")
        case .expired:
            Text("Expired bottle")
        case .premium:
            Text("Premium bottle")
        case .specialEvent:
            Text("Special event bottle")
        }
    }
}

// ----------------------------------------------------------
// MARK: - Pin Styling Helpers
// ----------------------------------------------------------

private extension Image {

    func pinBaseStyle() -> some View {
        self
            .resizable()
            .frame(width: 160, height: 160)
            .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)
    }
}
