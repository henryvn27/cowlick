import AppKit
import SwiftUI

@MainActor
final class NotchPanel: NSPanel {
  var permitsKeyInteraction = false
  override var canBecomeKey: Bool { permitsKeyInteraction }
  override var canBecomeMain: Bool { false }
}

@MainActor
final class NotchPanelController {
  private let store: SessionStore
  private let panel: NotchPanel
  private var observers: [NSObjectProtocol] = []
  private var presentationUpdateScheduled = false
  private(set) var currentGeometry: ResolvedNotchGeometry?

  init(store: SessionStore) {
    self.store = store
    panel = NotchPanel(
      contentRect: CGRect(origin: .zero, size: NotchTheme.compactSize),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    configurePanel()
    panel.contentView = NSHostingView(rootView: NotchRootView(store: store))
    installObservers()
    store.presentationDidChange = { [weak self] in self?.schedulePresentationUpdate() }
  }

  func updatePresentation() {
    let contentSize: CGSize
    if store.currentApproval != nil {
      contentSize = NotchTheme.approvalSize
    } else if store.isExpanded {
      contentSize = NotchTheme.sessionListSize(sessionCount: store.sessionSummaries.count)
    } else {
      contentSize = NotchTheme.compactSize
    }

    guard store.shouldShowOverlay,
      let screen = NotchGeometryResolver.preferredScreen(store.settings.preferredDisplay),
      let geometry = NotchGeometryResolver.resolve(
        screen: screen,
        contentSize: contentSize,
        showOnNonNotch: store.settings.showOnNonNotch
      )
    else {
      panel.orderOut(nil)
      currentGeometry = nil
      return
    }

    currentGeometry = geometry
    let interactiveApproval = store.currentApproval != nil
    panel.permitsKeyInteraction = interactiveApproval
    panel.ignoresMouseEvents = false
    if interactiveApproval {
      panel.styleMask.remove(.nonactivatingPanel)
    } else {
      panel.styleMask.insert(.nonactivatingPanel)
    }

    // Do not force a hosting-view layout here. Ordering the panel performs the
    // required layout once; forcing a display first can re-enter SwiftUI text
    // layout when an approval changes the panel's key-window behavior.
    panel.setFrame(geometry.panelFrame, display: false)

    if interactiveApproval {
      NSApp.activate(ignoringOtherApps: true)
      panel.makeKeyAndOrderFront(nil)
    } else {
      panel.orderFrontRegardless()
    }
  }

  func open() {
    if store.sessionSummaries.isEmpty { store.testState(.working) }
    store.isExpanded = true
    schedulePresentationUpdate()
  }

  private func schedulePresentationUpdate() {
    guard !presentationUpdateScheduled else { return }
    presentationUpdateScheduled = true
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      self.presentationUpdateScheduled = false
      self.updatePresentation()
    }
  }

  private func configurePanel() {
    panel.identifier = NSUserInterfaceItemIdentifier("NotchRelayPanel")
    panel.backgroundColor = .clear
    panel.isOpaque = false
    panel.hasShadow = false
    panel.level = .statusBar
    panel.collectionBehavior = [
      .canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle,
    ]
    panel.hidesOnDeactivate = false
    panel.isReleasedWhenClosed = false
    panel.animationBehavior = .none
    panel.acceptsMouseMovedEvents = true
  }

  private func installObservers() {
    let center = NotificationCenter.default
    let workspaceCenter = NSWorkspace.shared.notificationCenter
    observers.append(
      center.addObserver(
        forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
      ) { [weak self] _ in
        MainActor.assumeIsolated { self?.schedulePresentationUpdate() }
      })
    observers.append(
      center.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) {
        [weak self] _ in
        MainActor.assumeIsolated { self?.schedulePresentationUpdate() }
      })
    observers.append(
      workspaceCenter.addObserver(
        forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
      ) { [weak self] _ in
        MainActor.assumeIsolated { self?.schedulePresentationUpdate() }
      })
    observers.append(
      workspaceCenter.addObserver(
        forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
      ) { [weak self] _ in
        MainActor.assumeIsolated { self?.schedulePresentationUpdate() }
      })
  }
}
