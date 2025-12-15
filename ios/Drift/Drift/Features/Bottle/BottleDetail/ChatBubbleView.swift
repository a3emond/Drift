import SwiftUI

struct ChatBubbleView: View {

    let item: ChatBubbleItem

    var body: some View {
        HStack(alignment: .top, spacing: 8) {

            if item.isMine {
                Spacer(minLength: 28)
            } else {
                avatar
            }

            VStack(alignment: item.isMine ? .trailing : .leading, spacing: 4) {

                if item.isFirstInGroup {
                    header
                }

                bubble
            }
            .frame(maxWidth: .infinity, alignment: item.isMine ? .trailing : .leading)

            if item.isMine {
                avatar.opacity(0)
            } else {
                Spacer(minLength: 0)
            }
        }
        .padding(.vertical, 2)
    }

    // --------------------------------------------------
    // MARK: - Header
    // --------------------------------------------------

    private var header: some View {
        HStack(spacing: 6) {
            Text(item.distanceLabel)
            Text("•")
            Text(
                Date(timeIntervalSince1970: item.timestamp)
                    .formatted(date: .omitted, time: .shortened)
            )
        }
        .font(.caption2)
        .foregroundColor(.secondary)
    }

    // --------------------------------------------------
    // MARK: - Bubble
    // --------------------------------------------------

    @ViewBuilder
    private var bubble: some View {
        if let text = item.text {
            Text(text)
                .bubbleStyle(isMine: item.isMine)
        } else if item.imagePath != nil {
            Text("[image]")
                .bubbleStyle(isMine: item.isMine)
        } else if item.audioPath != nil {
            Text("[audio]")
                .bubbleStyle(isMine: item.isMine)
        }
    }

    // --------------------------------------------------
    // MARK: - Avatar
    // --------------------------------------------------

    private var avatar: some View {
        Circle()
            .fill(avatarColor(for: item.distanceLabel))
            .frame(width: 28, height: 28)
    }

    private func avatarColor(for seed: String) -> Color {
        let hash = abs(seed.hashValue)
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink]
        return colors[hash % colors.count]
    }
}

// --------------------------------------------------
// MARK: - Bubble Style
// --------------------------------------------------

private extension View {
    func bubbleStyle(isMine: Bool) -> some View {
        self
            .padding(10)
            .background(isMine ? Color.accentColor.opacity(0.85)
                               : Color.secondary.opacity(0.15))
            .foregroundColor(isMine ? .white : .primary)
            .cornerRadius(12)
            .frame(maxWidth: 280, alignment: isMine ? .trailing : .leading)
    }
}
