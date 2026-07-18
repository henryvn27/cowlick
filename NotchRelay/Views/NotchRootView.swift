import SwiftUI

struct NotchRootView: View {
  let store: SessionStore
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    Group {
      if store.currentApproval != nil || store.isExpanded {
        ExpandedIslandView(store: store)
      } else if let session = store.displaySession {
        CollapsedIslandView(session: session, activeCount: store.activeSessionCount) {
          if case .completed = session.status {
            store.dismissCompletion(sessionID: session.id)
          } else {
            store.toggleExpanded()
          }
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(NotchTheme.island, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .stroke(NotchTheme.hairline, lineWidth: 0.75)
    }
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    .animation(
      reduceMotion || store.settings.reducedAnimation
        ? nil : .spring(response: 0.34, dampingFraction: 0.86),
      value: store.isExpanded
    )
    .onExitCommand { store.collapse() }
    .preferredColorScheme(.dark)
  }
}
