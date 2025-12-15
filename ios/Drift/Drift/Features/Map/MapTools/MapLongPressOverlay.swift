import SwiftUI
import MapKit

struct MapLongPressOverlay: UIViewRepresentable {

    let onLongPress: (CLLocationCoordinate2D) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear

        let recognizer = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePress(_:))
        )
        recognizer.minimumPressDuration = 0.45
        recognizer.allowableMovement = 12

        view.addGestureRecognizer(recognizer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onLongPress: onLongPress)
    }

    final class Coordinator: NSObject {
        let onLongPress: (CLLocationCoordinate2D) -> Void

        init(onLongPress: @escaping (CLLocationCoordinate2D) -> Void) {
            self.onLongPress = onLongPress
        }

        @objc func handlePress(_ recognizer: UILongPressGestureRecognizer) {
            guard recognizer.state == .began,
                  let mapView = recognizer.view?.superview(of: MKMapView.self)
            else { return }

            let point = recognizer.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            onLongPress(coordinate)
        }
    }
}

private extension UIView {
    func superview<T: UIView>(of type: T.Type) -> T? {
        if let view = self as? T { return view }
        return superview?.superview(of: type)
    }
}
