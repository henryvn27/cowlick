import SwiftUI

struct SessionListView: View {
  let sessions: [AgentSession]
  let showPromptPreviews: Bool
  let openDiagnostics: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Sessions")
        .font(.system(size: 13, weight: .bold, design: .rounded))
        .foregroundStyle(.white.opacity(0.92))
      ForEach(sessions.prefix(5)) { session in
        HStack(spacing: 10) {
          statusIcon(for: session.status)
            .frame(width: 16)
          VStack(alignment: .leading, spacing: 2) {
            Text(session.projectName)
              .font(.system(size: 12.5, weight: .semibold, design: .rounded))
              .foregroundStyle(.white.opacity(0.92))
            Text(secondaryText(for: session))
              .font(.system(size: 10.5, design: .rounded))
              .foregroundStyle(.white.opacity(0.55))
              .lineLimit(1)
          }
          Spacer()
        }
        .accessibilityElement(children: .combine)
      }
      if sessions.contains(where: { session in
        if case .failed = session.status { return true }
        return false
      }) {
        Button("Open Diagnostics", action: openDiagnostics)
          .buttonStyle(.bordered)
          .controlSize(.small)
          .accessibilityHint("Open sanitized NotchRelay errors and bridge health")
      }
    }
    .padding(16)
  }

  @ViewBuilder
  private func statusIcon(for status: AgentStatus) -> some View {
    switch status {
    case .working: ProgressView().controlSize(.mini).tint(NotchTheme.accent)
    case .awaitingApproval: Image(systemName: "exclamationmark").foregroundStyle(NotchTheme.warning)
    case .completed: Image(systemName: "checkmark").foregroundStyle(NotchTheme.success)
    case .failed: Image(systemName: "xmark").foregroundStyle(NotchTheme.failure)
    case .idle: Image(systemName: "circle").foregroundStyle(.secondary)
    }
  }

  private func secondaryText(for session: AgentSession) -> String {
    if showPromptPreviews, case .working(let prompt) = session.status, let prompt, !prompt.isEmpty {
      return String(prompt.replacingOccurrences(of: "\n", with: " ").prefix(80))
    }
    switch session.status {
    case .failed(let message): return message.map { String($0.prefix(80)) } ?? "Failed"
    case .completed: return "Completed"
    default: return session.status.shortLabel
    }
  }
}
