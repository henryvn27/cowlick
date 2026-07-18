import SwiftUI

struct CollapsedIslandView: View {
  let session: AgentSession
  let activeCount: Int
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 9) {
        statusSymbol
          .frame(width: 16, height: 16)
        Text(session.projectName)
          .font(.system(size: 12.5, weight: .semibold, design: .rounded))
          .foregroundStyle(.white.opacity(0.94))
          .lineLimit(1)
        if activeCount > 1 {
          Text("\(activeCount)")
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(NotchTheme.island)
            .frame(minWidth: 18, minHeight: 18)
            .background(NotchTheme.accent, in: Circle())
            .accessibilityLabel("\(activeCount) active sessions")
        }
      }
      .padding(.horizontal, 13)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(session.projectName), \(session.status.shortLabel)")
    .accessibilityHint("Expand NotchRelay")
  }

  @ViewBuilder
  private var statusSymbol: some View {
    switch session.status {
    case .working:
      ProgressView()
        .controlSize(.small)
        .tint(NotchTheme.accent)
        .accessibilityHidden(true)
    case .awaitingApproval:
      Image(systemName: "exclamationmark")
        .font(.system(size: 11, weight: .bold))
        .foregroundStyle(NotchTheme.warning)
    case .completed:
      Image(systemName: "checkmark")
        .font(.system(size: 12, weight: .bold))
        .foregroundStyle(NotchTheme.success)
    case .failed:
      Image(systemName: "xmark")
        .font(.system(size: 11, weight: .bold))
        .foregroundStyle(NotchTheme.failure)
    case .idle:
      Circle().fill(.secondary).frame(width: 6, height: 6)
    }
  }
}
