import SwiftUI
import PhotosUI
import UIKit
import Foundation

enum BottleCreationStep: Equatable {
    case locationConfirm
    case content
    case conditions
    case review
    case submitting
    case completed(bottleId: String)
    case error(String)
}

// --------------------------------------------------
// MARK: - Location
// --------------------------------------------------

struct LocationConfirmStep: View {

    let latitude: Double
    let longitude: Double
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Drop bottle here?")
                .font(.headline)

            Text("Lat: \(latitude)")
            Text("Lng: \(longitude)")

            Button("Confirm Location") { onNext() }
                .buttonStyle(.borderedProminent)

            Spacer()
        }
        .padding()
    }
}

// --------------------------------------------------
// MARK: - Content
// --------------------------------------------------

struct ContentStep: View {

    @Binding var text: String

    let imageURL: URL?
    let audioURL: URL?

    let isRecording: Bool

    let onAddPhotoFromCamera: (UIImage) -> Void
    let onAddPhotoFromLibraryData: (Data) -> Void

    let onRemovePhoto: () -> Void

    let onStartRecording: () -> Void
    let onStopRecording: () -> Void
    let onRemoveAudio: () -> Void

    let onNext: () -> Void

    @State private var isCameraPresented = false
    @State private var photoItem: PhotosPickerItem?

    var body: some View {
        VStack(spacing: 12) {

            Text("Write the bottle message")
                .font(.headline)

            TextEditor(text: $text)
                .frame(minHeight: 160)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(.quaternary, lineWidth: 1)
                )

            mediaSection

            Button("Next") { onNext() }
                .buttonStyle(.borderedProminent)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                          && imageURL == nil
                          && audioURL == nil)

            Spacer()
        }
        .padding()
        .sheet(isPresented: $isCameraPresented) {
            CameraImagePicker(
                onImage: { img in
                    isCameraPresented = false
                    onAddPhotoFromCamera(img)
                },
                onCancel: {
                    isCameraPresented = false
                }
            )
            .ignoresSafeArea()
        }
        .onChange(of: photoItem) { _, newItem in
            guard let newItem else { return }

            Task {
                do {
                    if let data = try await newItem.loadTransferable(type: Data.self) {
                        onAddPhotoFromLibraryData(data)
                    }
                } catch {
                    // Intentionally silent here; VM will surface errors when persisting/uploading.
                }
                photoItem = nil
            }
        }
    }

    private var mediaSection: some View {
        VStack(alignment: .leading, spacing: 12) {

            HStack(spacing: 12) {
                Button("Camera") {
                    isCameraPresented = true
                }
                .buttonStyle(.bordered)

                PhotosPicker(selection: $photoItem, matching: .images) {
                    Text("Photo Library")
                }
                .buttonStyle(.bordered)
            }

            if let imageURL {
                HStack(spacing: 12) {
                    DraftImagePreview(imageURL: imageURL)
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    Button("Remove Photo") { onRemovePhoto() }
                        .buttonStyle(.bordered)
                }
            }

            Divider()

            HStack(spacing: 12) {
                if isRecording {
                    Button("Stop Recording") { onStopRecording() }
                        .buttonStyle(.borderedProminent)
                } else {
                    Button("Record Audio") { onStartRecording() }
                        .buttonStyle(.bordered)
                }

                if audioURL != nil {
                    Button("Remove Audio") { onRemoveAudio() }
                        .buttonStyle(.bordered)
                }
            }

            if let audioURL {
                Text("Audio: \(audioURL.lastPathComponent)")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private struct DraftImagePreview: View {
    let imageURL: URL

    var body: some View {
        if let uiImage = UIImage(contentsOfFile: imageURL.path) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else {
            RoundedRectangle(cornerRadius: 10)
                .fill(.quaternary)
                .overlay(Text("No Preview").font(.caption))
        }
    }
}

// --------------------------------------------------
// MARK: - Conditions
// --------------------------------------------------

struct ConditionsStep: View {

    @Binding var draft: BottleDraft
    let onNext: () -> Void

    @State private var minDistanceText = ""
    @State private var maxDistanceText = ""
    @State private var weatherThresholdText = ""

    var body: some View {
        Form {

            Section("Access") {
                TextField(
                    "Password (optional)",
                    text: Binding(
                        get: { draft.password ?? "" },
                        set: { draft.password = $0.isEmpty ? nil : $0 }
                    )
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            }

            Section("Location Rules") {
                Toggle("Exact location required", isOn: $draft.exactLocation)

                TextField("Min distance (km)", text: $minDistanceText)
                    .keyboardType(.decimalPad)

                TextField("Max distance (km)", text: $maxDistanceText)
                    .keyboardType(.decimalPad)
            }

            Section("Time Rules") {
                TimeIntervalPickerRow(
                    title: "Unlock at time",
                    value: $draft.unlockAtTime
                )

                TimeIntervalPickerRow(
                    title: "Window start",
                    value: $draft.timeWindow.start
                )

                TimeIntervalPickerRow(
                    title: "Window end",
                    value: $draft.timeWindow.end
                )
            }

            Section("Weather") {
                TextField(
                    "Type (optional)",
                    text: Binding(
                        get: { draft.weather.type ?? "" },
                        set: { draft.weather.type = $0.isEmpty ? nil : $0 }
                    )
                )

                TextField("Threshold", text: $weatherThresholdText)
                    .keyboardType(.decimalPad)
            }

            Section("Behavior") {
                Toggle("One shot", isOn: $draft.oneShot)
                Toggle("Chat enabled", isOn: $draft.chatEnabled)
            }

            Section {
                Button("Next") { onNext() }
            }
        }
        .onAppear {
            minDistanceText = draft.distanceMin.map { String($0) } ?? ""
            maxDistanceText = draft.distanceMax.map { String($0) } ?? ""
            weatherThresholdText = draft.weather.threshold.map { String($0) } ?? ""
        }
        .onChange(of: minDistanceText) {
            draft.distanceMin = Double($0)
        }
        .onChange(of: maxDistanceText) {
            draft.distanceMax = Double($0)
        }
        .onChange(of: weatherThresholdText) {
            draft.weather.threshold = Double($0)
        }
    }
}

// --------------------------------------------------
// MARK: - Review
// --------------------------------------------------

struct ReviewStep: View {

    let draft: BottleDraft
    let onSubmit: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("Review")
                .font(.headline)

            Text("Lat: \(draft.location.lat)")
            Text("Lng: \(draft.location.lng)")

            Text((draft.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(12)

            Spacer()

            Button("Create Bottle") { onSubmit() }
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

// --------------------------------------------------
// MARK: - Completed
// --------------------------------------------------

struct CompletedStep: View {

    let bottleId: String
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Bottle created")
                .font(.headline)

            Text("id: \(bottleId)")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Button("Done") { onDone() }
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

// --------------------------------------------------
// MARK: - Error
// --------------------------------------------------

struct ErrorStep: View {

    let message: String
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Creation failed")
                .font(.headline)

            Text(message)
                .foregroundColor(.red)

            Button("Close") { onClose() }
                .buttonStyle(.bordered)
        }
        .padding()
    }
}

// --------------------------------------------------
// MARK: - Helper
// --------------------------------------------------

private struct TimeIntervalPickerRow: View {

    let title: String
    @Binding var value: TimeInterval?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(title, isOn: Binding(
                get: { value != nil },
                set: { enabled in
                    value = enabled ? Date().timeIntervalSince1970 : nil
                }
            ))

            if let value {
                DatePicker(
                    "",
                    selection: Binding(
                        get: { Date(timeIntervalSince1970: value) },
                        set: { self.value = $0.timeIntervalSince1970 }
                    ),
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.compact)
            }
        }
    }
}
