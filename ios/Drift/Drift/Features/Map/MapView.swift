import SwiftUI
import MapKit

struct MapView: View {

    // ------------------------------------------------------
    // MARK: - Environment
    // ------------------------------------------------------

    @EnvironmentObject private var env: AppEnvironment

    // ------------------------------------------------------
    // MARK: - State
    // ------------------------------------------------------

    @StateObject private var vm: MapViewModel
    private let logger: Logging

    // Camera drives the Map rendering
    @State private var cameraPosition: MapCameraPosition = .automatic

    // Region drives your visibility math (always available, no optional)
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 60, longitudeDelta: 60)
    )

    @State private var hasCenteredOnUser = false
    @State private var didFinishInitialLoad = false

    // ------------------------------------------------------
    // MARK: - Init
    // ------------------------------------------------------

    init(env: AppEnvironment) {
        self.logger = env.logger
        _vm = StateObject(
            wrappedValue: MapViewModel(
                authService: env.auth,
                locationService: env.location,
                bottleService: env.bottles,
                logger: env.logger
            )
        )
    }

    // ------------------------------------------------------
    // MARK: - Derived State
    // ------------------------------------------------------

    private var presentationMode: MapPresentationMode {
        MapPresentationModeResolver.mode(for: region)
    }

    private var visibleAnnotations: [MapAnnotationItem] {
        vm.filteredAnnotations.filter {
            MapRegionMath.contains(
                latitude: $0.latitude,
                longitude: $0.longitude,
                in: region
            )
        }
    }

    private var clusters: [MapClusterItem] {
        MapClustering.clusterItems(
            items: visibleAnnotations,
            region: region
        )
    }

    // ------------------------------------------------------
    // MARK: - Body
    // ------------------------------------------------------

    var body: some View {
        ZStack {

            mapView

            if !didFinishInitialLoad {
                ProgressView()
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
            }

            if didFinishInitialLoad && visibleAnnotations.isEmpty {
                Text("No bottles nearby. Try moving around or creating one by long-pressing on the map.")
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
            }
        }
        .ignoresSafeArea()
        .safeAreaInset(edge: .top) {
            MapFilterBar(
                active: vm.activeFilter,
                onSelect: { vm.setFilter($0) }
            )
            .padding(.horizontal)
            .padding(.top, 8)
            .background(.ultraThinMaterial)
        }
        .onAppear {
            vm.start()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                didFinishInitialLoad = true
            }
        }
        .onChange(of: vm.shouldCenterOnUser) { shouldCenter in
            guard shouldCenter,
                  !hasCenteredOnUser,
                  let location = vm.userLocation
            else { return }

            let target = MKCoordinateRegion(
                center: CLLocationCoordinate2D(
                    latitude: location.latitude,
                    longitude: location.longitude
                ),
                span: MKCoordinateSpan(
                    latitudeDelta: 0.12,
                    longitudeDelta: 0.12
                )
            )

            // Update both:
            region = target
            cameraPosition = .region(target)

            hasCenteredOnUser = true
        }
        .onDisappear {
            vm.stop()
        }

        // --------------------------------------------------
        // MARK: - Sheets
        // --------------------------------------------------

        .sheet(item: $vm.selectedBottle) { selection in
            BottleDetailView(
                bottleId: selection.id,
                distanceKm: selection.distanceKm,
                distanceCategory: selection.distanceCategory,
                bottleService: env.bottles,
                authService: env.auth,
                chatService: env.chat,
                storage: env.storage,
                logger: env.logger
            )
        }
        .sheet(item: $vm.newBottleDraft) { draft in
            NewBottleSheetContainer(
                draft: draft,
                bottleService: env.bottles,
                storage: env.storage,
                media: env.mediaDraft,
                logger: env.logger
            )
        }
    }

    // ------------------------------------------------------
    // MARK: - Map
    // ------------------------------------------------------

    private var mapView: some View {
        Map(position: $cameraPosition, interactionModes: .all) {

            if presentationMode == .individual {
                ForEach(visibleAnnotations) { bottle in
                    Annotation(
                        "",
                        coordinate: CLLocationCoordinate2D(
                            latitude: bottle.latitude,
                            longitude: bottle.longitude
                        ),
                        anchor: .bottom
                    ) {
                        BottleAnnotationView(item: bottle) {
                            vm.didSelectBottle(id: bottle.id)
                        }
                    }
                }
            }

            if presentationMode == .clustered {
                ForEach(clusters) { cluster in
                    Annotation(
                        "",
                        coordinate: CLLocationCoordinate2D(
                            latitude: cluster.latitude,
                            longitude: cluster.longitude
                        ),
                        anchor: .bottom
                    ) {
                        ClusterPillView(count: cluster.count) {
                            zoomIntoCluster(cluster)
                        }
                    }
                }
            }
        }
        // This is the key: keep `region` updated while zooming/panning
        .onMapCameraChange(frequency: .continuous) { context in
            region = context.region
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.6)
                .onEnded { _ in
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    vm.beginBottleCreation(at: region.center)
                }
        )
    }

    // ------------------------------------------------------
    // MARK: - Helpers
    // ------------------------------------------------------

    private func zoomIntoCluster(_ cluster: MapClusterItem) {
        let target = MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: cluster.latitude,
                longitude: cluster.longitude
            ),
            span: MKCoordinateSpan(
                latitudeDelta: 0.25,
                longitudeDelta: 0.25
            )
        )

        region = target
        cameraPosition = .region(target)
    }
}
