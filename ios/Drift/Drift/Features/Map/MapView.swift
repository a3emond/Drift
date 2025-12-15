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

            if presentationMode == .individual {
                mapWithAnnotations
            }

            if presentationMode == .clustered {
                mapWithClusters
            }

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

            region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(
                    latitude: location.latitude,
                    longitude: location.longitude
                ),
                span: MKCoordinateSpan(
                    latitudeDelta: 0.12,
                    longitudeDelta: 0.12
                )
            )

            hasCenteredOnUser = true
        }
        .onDisappear {
            vm.stop()
        }
        .sheet(item: $vm.selectedBottle) { selection in
            BottleDetailView(
                bottleId: selection.id,
                logger: logger
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
    // MARK: - Map Variants
    // ------------------------------------------------------

    private var mapWithAnnotations: some View {
        Map(
            coordinateRegion: $region,
            interactionModes: .all,
            showsUserLocation: true,
            annotationItems: visibleAnnotations
        ) { bottle in
            MapAnnotation(
                coordinate: CLLocationCoordinate2D(
                    latitude: bottle.latitude,
                    longitude: bottle.longitude
                )
            ) {
                BottleAnnotationView(item: bottle) {
                    vm.didSelectBottle(id: bottle.id)
                }
            }
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.6)
                .onEnded { _ in
                    let center = region.center
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    vm.beginBottleCreation(at: center)
                }
        )
    }

    private var mapWithClusters: some View {
        Map(
            coordinateRegion: $region,
            interactionModes: .all,
            showsUserLocation: true,
            annotationItems: clusters
        ) { cluster in
            MapAnnotation(
                coordinate: CLLocationCoordinate2D(
                    latitude: cluster.latitude,
                    longitude: cluster.longitude
                )
            ) {
                ClusterPillView(count: cluster.count) {
                    region = MapRegionMath.zoomedIntoCluster(
                        current: region,
                        clusterLatitude: cluster.latitude,
                        clusterLongitude: cluster.longitude
                    )
                }
            }
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.6)
                .onEnded { _ in
                    let center = region.center
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    vm.beginBottleCreation(at: center)
                }
        )
    }
} 
