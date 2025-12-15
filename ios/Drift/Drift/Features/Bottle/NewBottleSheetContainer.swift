import SwiftUI

struct NewBottleSheetContainer: View {

    @StateObject private var vm: NewBottleSheetViewModel
    @Environment(\.dismiss) private var dismiss

    // --------------------------------------------------
    // MARK: - Init
    // --------------------------------------------------

    init(
        draft: NewBottleDraft,
        bottleService: BottleServiceProtocol,
        storage: StorageService,
        media: MediaDraftServiceProtocol,
        logger: Logging
    ) {
        let now = Date().timeIntervalSince1970

        let initial = BottleDraft(
            createdAt: now,
            location: BottleLocation(
                lat: draft.latitude,
                lng: draft.longitude
            ),
            text: nil,
            imageLocalURL: nil,
            audioLocalURL: nil,
            password: nil,
            timeWindow: TimeWindow(start: nil, end: nil),
            weather: WeatherCondition(type: nil, threshold: nil),
            exactLocation: false,
            distanceMin: nil,
            distanceMax: nil,
            unlockAtTime: nil,
            oneShot: false,
            chatEnabled: true
        )

        _vm = StateObject(
            wrappedValue: NewBottleSheetViewModel(
                initialDraft: initial,
                bottleService: bottleService,
                storage: storage,
                media: media,
                logger: logger
            )
        )
    }

    // --------------------------------------------------
    // MARK: - Body
    // --------------------------------------------------

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        if canGoBack {
                            Button("Back") {
                                vm.goBack()
                            }
                        }
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Close") {
                            dismiss()
                        }
                        .disabled(vm.isBusy)
                    }
                }
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled(vm.isBusy)
    }

    // --------------------------------------------------
    // MARK: - Content Router
    // --------------------------------------------------

    @ViewBuilder
    private var content: some View {
        switch vm.step {

        case .locationConfirm:
            LocationConfirmStep(
                latitude: vm.draft.location.lat,
                longitude: vm.draft.location.lng,
                onNext: vm.advance
            )

        case .content:
            ContentStep(
                text: Binding(
                    get: { vm.draft.text ?? "" },
                    set: { vm.draft.text = $0 }
                ),
                imageURL: vm.draft.imageLocalURL,
                audioURL: vm.draft.audioLocalURL,
                isRecording: vm.isRecordingAudio,
                onAddPhotoFromCamera: { image in
                    vm.addPhotoFromCamera(image)
                },
                onAddPhotoFromLibraryData: { data in
                    vm.addPhotoFromLibraryData(data)
                },
                onRemovePhoto: {
                    vm.removePhoto()
                },
                onStartRecording: {
                    vm.startAudioRecording()
                },
                onStopRecording: {
                    vm.stopAudioRecording()
                },
                onRemoveAudio: {
                    vm.removeAudio()
                },
                onNext: vm.advance
            )

        case .conditions:
            ConditionsStep(
                draft: $vm.draft,
                onNext: vm.advance
            )

        case .review:
            ReviewStep(
                draft: vm.draft,
                onSubmit: vm.advance
            )

        case .submitting:
            ProgressView("Creating bottle…")
                .padding()

        case .completed(let bottleId):
            CompletedStep(
                bottleId: bottleId,
                onDone: {
                    dismiss()
                }
            )

        case .error(let message):
            ErrorStep(
                message: message,
                onClose: {
                    dismiss()
                }
            )
        }
    }

    // --------------------------------------------------
    // MARK: - Helpers
    // --------------------------------------------------

    private var title: String {
        switch vm.step {
        case .locationConfirm: return "Confirm Location"
        case .content:         return "Bottle Content"
        case .conditions:      return "Conditions"
        case .review:          return "Review"
        case .submitting:      return "Creating"
        case .completed:       return "Done"
        case .error:           return "Error"
        }
    }

    private var canGoBack: Bool {
        switch vm.step {
        case .content, .conditions, .review:
            return true
        default:
            return false
        }
    }
}
