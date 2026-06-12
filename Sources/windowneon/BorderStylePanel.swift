import AppKit
import SwiftUI

// MARK: - Editor state

final class BorderStyleEditorModel: ObservableObject {
    let appName: String
    let appIcon: NSImage?

    @Published var style: BorderStyle {
        didSet {
            // March needs a dash pattern to march.
            if style.stroke == .solid && style.motion == .march {
                style.motion = .none
                return // inner didSet already fired onLiveChange
            }
            onLiveChange?()
        }
    }
    @Published var width: CGFloat { didSet { onLiveChange?() } }
    @Published var radius: CGFloat { didSet { onLiveChange?() } }
    @Published var selectedIndex = 0
    /// Stable identities for the color dots, parallel to style.colors, so
    /// SwiftUI can animate insertions and removals instead of re-keying by index.
    @Published var colorIDs: [UUID]

    var onLiveChange: (() -> Void)?
    var onPickColor: ((Int) -> Void)?
    var onSave: (() -> Void)?
    var onCancel: (() -> Void)?

    init(appName: String, appIcon: NSImage?, style: BorderStyle, width: CGFloat, radius: CGFloat) {
        self.appName = appName
        self.appIcon = appIcon
        self.style = style
        self.width = width
        self.radius = radius
        self.colorIDs = style.colors.map { _ in UUID() }
    }

    func selectColor(_ index: Int) {
        selectedIndex = index
        onPickColor?(index)
    }

    func addColor() {
        guard style.colors.count < BorderStyle.maxColors else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            style.colors.append(style.colors.last ?? .systemBlue)
            colorIDs.append(UUID())
            selectedIndex = style.colors.count - 1
        }
        onPickColor?(selectedIndex)
    }

    func removeColor(at index: Int) {
        guard style.colors.count > 1, style.colors.indices.contains(index) else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            style.colors.remove(at: index)
            colorIDs.remove(at: index)
            selectedIndex = min(selectedIndex, style.colors.count - 1)
        }
    }

    /// Called when the shared NSColorPanel changes.
    func updateColor(_ color: NSColor, at index: Int) {
        guard style.colors.indices.contains(index) else { return }
        style.colors[index] = color
    }
}

// MARK: - Panel window

final class BorderStylePanel: NSPanel, NSWindowDelegate {
    let model: BorderStyleEditorModel
    private var didCommit = false

    init(model: BorderStyleEditorModel) {
        self.model = model

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 420),
            styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )

        isFloatingPanel = true
        level = .floating
        title = "Border style — \(model.appName)"
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true
        isMovableByWindowBackground = true
        isReleasedWhenClosed = false
        isOpaque = false
        backgroundColor = .clear
        delegate = self

        let hosting = NSHostingView(rootView: BorderStyleEditor(model: model))
        contentView = hosting
        setContentSize(hosting.fittingSize)
    }

    /// Mark the panel as saved so closing doesn't trigger the cancel path.
    func commit() {
        didCommit = true
    }

    func windowWillClose(_ notification: Notification) {
        // Closed via the red X — treat as cancel.
        if !didCommit { model.onCancel?() }
    }
}

// MARK: - Editor view

struct BorderStyleEditor: View {
    @ObservedObject var model: BorderStyleEditorModel
    @State private var hoveredColorIndex: Int?

    private static let strokeNames: [(BorderStyle.Stroke, String)] =
        [(.solid, "Solid"), (.dashed, "Dashed"), (.dotted, "Dotted")]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            StylePreview(style: model.style, lineWidth: min(model.width, 7))
                .frame(height: 30)
            colorsSection
            labeledRow("Style") { strokePicker }
            labeledRow("Motion") { motionPicker }
            glowSpeedRow
            Divider()
            sliderRow("Width", value: $model.width, in: 1...10, step: 1, format: { "\(Int($0)) pt" })
            sliderRow("Radius", value: $model.radius, in: 0...40, step: 1, format: { "\(Int($0)) pt" })
            footer
        }
        .padding(.top, 32)
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .frame(width: 360)
        .background(VisualEffectBackground().ignoresSafeArea())
    }

    private var header: some View {
        HStack(spacing: 8) {
            if let icon = model.appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 22, height: 22)
            }
            Text(model.appName)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
            Spacer()
        }
    }

    // MARK: Colors

    private var colorsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Colors")
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(Array(zip(model.colorIDs, model.style.colors.indices)), id: \.0) { _, i in
                    colorDot(at: i)
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                }
                if model.style.colors.count < BorderStyle.maxColors {
                    addDot
                        .transition(.opacity)
                }
                Spacer()
            }
            .frame(height: 38)
        }
    }

    private func colorDot(at index: Int) -> some View {
        // The badge lives inside this fixed container, so the hover region is
        // one continuous shape — moving from the dot to the badge never
        // crosses a gap that would dismiss it.
        ZStack(alignment: .bottomLeading) {
            Circle()
                .fill(Color(nsColor: model.style.colors[index]))
                .frame(width: 26, height: 26)
                .overlay(Circle().strokeBorder(Color.primary.opacity(0.15)))
                .background(
                    Circle()
                        .stroke(Color.accentColor, lineWidth: 2)
                        .padding(-4)
                        .opacity(model.selectedIndex == index ? 1 : 0)
                )
                .contentShape(Circle())
                .onTapGesture { model.selectColor(index) }
        }
        .frame(width: 36, height: 36, alignment: .bottomLeading)
        .overlay(alignment: .topTrailing) {
            if hoveredColorIndex == index && model.style.colors.count > 1 {
                removeBadge(at: index)
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                if hovering {
                    hoveredColorIndex = index
                } else if hoveredColorIndex == index {
                    hoveredColorIndex = nil
                }
            }
        }
    }

    private func removeBadge(at index: Int) -> some View {
        Button {
            hoveredColorIndex = nil
            model.removeColor(at: index)
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 15, weight: .semibold))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .gray)
                .frame(width: 20, height: 20)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .transition(.opacity.combined(with: .scale(scale: 0.6)))
    }

    private var addDot: some View {
        Button {
            model.addColor()
        } label: {
            Circle()
                .strokeBorder(style: StrokeStyle(lineWidth: 1.2, dash: [3, 2.5]))
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 26)
                .overlay(
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                )
        }
        .buttonStyle(.plain)
        .help("Add a color")
    }

    // MARK: Pickers

    private var strokePicker: some View {
        Picker("", selection: $model.style.stroke) {
            ForEach(Self.strokeNames, id: \.0) { stroke, name in
                Text(name).tag(stroke)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    private var motionPicker: some View {
        // March only shows up once there are dashes to march.
        let motions: [BorderStyle.Motion] = model.style.stroke == .solid
            ? [.none, .pulse, .spin]
            : [.none, .pulse, .spin, .march]
        return Picker("", selection: $model.style.motion) {
            ForEach(motions, id: \.self) { motion in
                Text(motion == .none ? "None" : motion.rawValue.capitalized).tag(motion)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    private var glowSpeedRow: some View {
        HStack(spacing: 10) {
            Toggle(isOn: $model.style.glow) {
                Text("Glow").font(.system(size: 11, design: .rounded))
            }
            .toggleStyle(.switch)
            .controlSize(.mini)
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "tortoise.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                Slider(value: $model.style.speed, in: 0.25...3)
                    .controlSize(.small)
                    .frame(width: 130)
                Image(systemName: "hare.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            .disabled(model.style.motion == .none)
            .opacity(model.style.motion == .none ? 0.4 : 1)
        }
    }

    // MARK: Rows & footer

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(.secondary)
    }

    private func labeledRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 10) {
            sectionLabel(label)
                .frame(width: 48, alignment: .leading)
            content()
        }
    }

    private func sliderRow(
        _ label: String,
        value: Binding<CGFloat>,
        in range: ClosedRange<CGFloat>,
        step: CGFloat,
        format: @escaping (CGFloat) -> String
    ) -> some View {
        HStack(spacing: 10) {
            sectionLabel(label)
                .frame(width: 48, alignment: .leading)
            Slider(value: value, in: range, step: step)
                .controlSize(.small)
            Text(format(value.wrappedValue))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 38, alignment: .trailing)
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("Cancel") { model.onCancel?() }
                .keyboardShortcut(.cancelAction)
            Button("Save") { model.onSave?() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        }
        .padding(.top, 2)
    }
}

// MARK: - Live preview strip

private final class StylePreviewStripView: NSView {
    private let renderer = BorderStyleRenderer()
    private var style = BorderStyle(colors: [.systemBlue])
    private var lineWidth: CGFloat = 5

    override init(frame: NSRect) {
        super.init(frame: frame)
        layer = CALayer()
        wantsLayer = true
        renderer.attach(to: layer!)
    }

    required init?(coder: NSCoder) { fatalError() }

    func apply(style: BorderStyle, lineWidth: CGFloat) {
        self.style = style
        self.lineWidth = lineWidth
        refresh()
    }

    override func layout() {
        super.layout()
        refresh()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        refresh()
    }

    private func refresh() {
        let inset = lineWidth / 2
        let rect = bounds.insetBy(dx: inset, dy: inset)
        guard rect.width > 0, rect.height > 0 else { return }
        let radius = min(rect.height / 2, rect.width / 2)
        let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
        renderer.render(
            style: style,
            path: path,
            lineWidth: lineWidth,
            bounds: bounds,
            scale: window?.backingScaleFactor ?? 2
        )
    }
}

struct StylePreview: NSViewRepresentable {
    let style: BorderStyle
    var lineWidth: CGFloat = 5

    func makeNSView(context: Context) -> NSView {
        StylePreviewStripView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? StylePreviewStripView)?.apply(style: style, lineWidth: lineWidth)
    }
}

// MARK: - Window material

private struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
