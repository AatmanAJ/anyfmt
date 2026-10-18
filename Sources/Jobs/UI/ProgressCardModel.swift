import AppKit
import Combine
import Foundation

/// Live state of one progress card. The presenter writes `state` from queue
/// records; the SwiftUI view reads it and calls the action closures.
@MainActor
final class ProgressCardModel: ObservableObject, Identifiable {
    enum Subject: Equatable {
        case job(UUID)
        case batch(UUID)
        case summary
    }

    let id = UUID()
    let subject: Subject

    @Published var state: ProgressCardState
    /// Drives the appear/disappear animation.
    @Published var isShown = false
    @Published var isHovered = false
    @Published var didCopyDetails = false
    @Published var icons: [ProgressIconImage] = []

    var onCancel: () -> Void = {}
    var onClose: () -> Void = {}
    var onRetry: () -> Void = {}
    var onCopyDetails: () -> Void = {}
    var onReveal: () -> Void = {}

    init(subject: Subject, state: ProgressCardState) {
        self.subject = subject
        self.state = state
    }

    /// The queue id this card controls (job or batch).
    var subjectID: UUID? {
        switch subject {
        case .job(let id), .batch(let id): id
        case .summary: nil
        }
    }
}
