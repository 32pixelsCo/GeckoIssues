import AppKit
import SwiftUI

/// A two-pane horizontal split view with stable, content-independent column widths.
///
/// Uses `NSSplitView` under the hood so the leading pane keeps its width
/// regardless of what content is displayed in either pane.
struct StableSplitView<Leading: View, Trailing: View>: NSViewControllerRepresentable {
    var leadingMinWidth: CGFloat
    var leadingIdealWidth: CGFloat
    var leadingMaxWidth: CGFloat
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    func makeNSViewController(context: Context) -> StableSplitController<Leading, Trailing> {
        let controller = StableSplitController<Leading, Trailing>()
        controller.leadingMinWidth = leadingMinWidth
        controller.leadingMaxWidth = leadingMaxWidth
        controller.leadingIdealWidth = leadingIdealWidth
        controller.setup(leading: leading, trailing: trailing)
        return controller
    }

    func updateNSViewController(_ controller: StableSplitController<Leading, Trailing>, context: Context) {
        controller.updateLeading(leading)
        controller.updateTrailing(trailing)
    }
}

// MARK: - Controller

@MainActor
final class StableSplitController<Leading: View, Trailing: View>: NSSplitViewController {
    var leadingMinWidth: CGFloat = 200
    var leadingMaxWidth: CGFloat = 400
    var leadingIdealWidth: CGFloat = 250

    private var leadingWrapper: HostingWrapperController?
    private var trailingWrapper: HostingWrapperController?
    private var didSetInitialPosition = false

    func setup(leading: Leading, trailing: Trailing) {
        let lWrapper = HostingWrapperController(rootView: AnyView(leading))
        let lItem = NSSplitViewItem(viewController: lWrapper)
        lItem.minimumThickness = leadingMinWidth
        lItem.maximumThickness = leadingMaxWidth
        lItem.canCollapse = false
        lItem.holdingPriority = .init(251)

        let tWrapper = HostingWrapperController(rootView: AnyView(trailing))
        let tItem = NSSplitViewItem(viewController: tWrapper)
        tItem.minimumThickness = 300
        tItem.canCollapse = false
        tItem.holdingPriority = .init(250)

        addSplitViewItem(lItem)
        addSplitViewItem(tItem)

        leadingWrapper = lWrapper
        trailingWrapper = tWrapper
    }

    func updateLeading(_ view: Leading) {
        leadingWrapper?.updateRootView(AnyView(view))
    }

    func updateTrailing(_ view: Trailing) {
        trailingWrapper?.updateRootView(AnyView(view))
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        if !didSetInitialPosition, view.bounds.width > 0 {
            didSetInitialPosition = true
            splitView.setPosition(leadingIdealWidth, ofDividerAt: 0)
        }
    }
}

// MARK: - Hosting Wrapper

/// Wraps an `NSHostingController` inside a plain `NSViewController`, pinning the
/// hosting view to all edges with Auto Layout. This ensures the SwiftUI content
/// fills the entire split-view pane rather than centering at its intrinsic size.
@MainActor
private final class HostingWrapperController: NSViewController {
    private let hostingController: NSHostingController<AnyView>

    init(rootView: AnyView) {
        hostingController = NSHostingController(rootView: rootView)
        hostingController.sizingOptions = []
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        view = NSView()

        addChild(hostingController)
        let hostingView = hostingController.view
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hostingView)

        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: view.topAnchor),
            hostingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    func updateRootView(_ rootView: AnyView) {
        hostingController.rootView = rootView
    }
}
