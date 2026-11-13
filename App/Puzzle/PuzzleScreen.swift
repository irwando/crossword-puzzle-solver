import CrosswordCore
import SwiftUI
import os

#if DEBUG
private let keyLog = Logger(subsystem: "com.irwando.crosswords", category: "keys")
#endif

struct PuzzleScreen: View {
    let url: URL

    @Environment(LibraryStore.self) private var library
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(SettingsKey.skipFilledSquares) private var skipFilled = true
    @AppStorage(SettingsKey.acrossCluesSide) private var acrossSide: ClueSide = .right
    @AppStorage(SettingsKey.downCluesSide) private var downSide: ClueSide = .right
    @State private var model: PuzzleViewModel
    @State private var hardwareKeyboard = HardwareKeyboardMonitor()
    @State private var keyboardPreference: Bool? = {
        #if DEBUG
        UserDefaults.standard.object(forKey: "CrosswordsShowKeyboard") != nil
            ? UserDefaults.standard.bool(forKey: "CrosswordsShowKeyboard") : nil
        #else
        nil
        #endif
    }()
    @FocusState private var gridFocused: Bool

    init(url: URL) {
        self.url = url
        _model = State(initialValue: PuzzleViewModel(url: url))
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.paper)
            .navigationTitle(model.session?.puzzle.metadata.title.nonEmpty ?? url.deletingPathExtension().lastPathComponent)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                PuzzleToolbar(model: model, showKeyboard: showKeyboardBinding)
            }
            .task {
                let url = url
                let library = library
                model.onProgressChange = { [weak library] progress in
                    library?.updateProgress(for: url, progress: progress)
                }
                await model.load(skipFilledSquares: skipFilled)
                gridFocused = true
                #if DEBUG
                // End-to-end save test: `-CrosswordsDebugType "ABC"` types into the first clue.
                if let text = UserDefaults.standard.string(forKey: "CrosswordsDebugType") {
                    model.perform(.selectClue(ClueID(.down, 3)))
                    model.perform(.type(text))
                    model.perform(.check(.word))
                }
                #endif
            }
            .onDisappear {
                let model = model
                Task { await model.close() }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { Task { await model.flush() } }
            }
            .onChange(of: skipFilled) { _, value in model.perform(.setSkipFilledSquares(value)) }
            .focusedSceneValue(\.puzzleModel, model)
            .confirmationDialog(
                confirmationTitle, isPresented: confirmationBinding, titleVisibility: .visible,
                presenting: model.pendingConfirmation
            ) { confirmation in
                switch confirmation {
                case .revealPuzzle:
                    Button("Reveal Puzzle", role: .destructive) { model.perform(.reveal(.puzzle)) }
                case .resetPuzzle:
                    Button("Reset Puzzle", role: .destructive) { model.perform(.resetPuzzle) }
                }
            } message: { confirmation in
                Text(confirmation == .revealPuzzle
                    ? "Every square will be filled in with the answer."
                    : "All entries, checks, and reveals will be erased.")
            }
    }

    @ViewBuilder
    private var content: some View {
        switch model.loadState {
        case .loading:
            ProgressView("Opening puzzle…")
        case .failed(let message):
            ContentUnavailableView("Can't Open Puzzle", systemImage: "exclamationmark.triangle", description: Text(message))
        case .ready:
            if let session = model.session {
                solvingView(session)
            }
        }
    }

    private func solvingView(_ session: SolveSession) -> some View {
        GeometryReader { proxy in
            let wide = proxy.size.width > proxy.size.height * 1.05 && proxy.size.width > 640
            VStack(spacing: 0) {
                Group {
                    if wide {
                        wideLayout(session, size: proxy.size)
                    } else {
                        tallLayout(session, size: proxy.size)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, showsOnscreenKeyboard ? 8 : 16)

                if showsOnscreenKeyboard {
                    CrosswordKeyboard(
                        rebusActive: session.rebusBuffer != nil,
                        pencilOn: session.settings.pencil,
                        perform: model.perform,
                        togglePencil: model.togglePencil
                    )
                    .transition(.move(edge: .bottom))
                }
            }
        }
        .overlay(alignment: .top) { BannerView(banner: model.banner).padding(.top, 84) }
        .animation(.spring(duration: 0.35), value: model.banner)
        .animation(.easeInOut(duration: 0.25), value: showsOnscreenKeyboard)
        .focusable(interactions: .edit)
        .focused($gridFocused)
        .focusEffectDisabled()
        .onKeyPress(phases: [.down, .repeat]) { press in
            // Read live state: the `session` captured by this closure can be a render behind.
            let action = KeyMapper.action(for: press, rebusActive: model.session?.rebusBuffer != nil)
            #if DEBUG
            keyLog.debug("key \(press.characters.debugDescription, privacy: .public) → \(String(describing: action), privacy: .public)")
            #endif
            guard let action else { return .ignored }
            model.perform(action)
            return .handled
        }
    }

    private func wideLayout(_ session: SolveSession, size: CGSize) -> some View {
        WidePuzzleLayout(
            session: session,
            size: CGSize(width: size.width - 32, height: size.height - 28),
            acrossSide: acrossSide,
            downSide: downSide,
            perform: model.perform
        ) {
            grid(session)
        }
    }

    private func tallLayout(_ session: SolveSession, size: CGSize) -> some View {
        let puzzle = session.puzzle
        let keyboardHeight: CGFloat = showsOnscreenKeyboard ? 240 : 0
        let usable = size.height - keyboardHeight - 64 - 40
        let cell = min(
            GridLayout.maxCellSize,
            (size.width - 32) / CGFloat(puzzle.width),
            usable * 0.78 / CGFloat(puzzle.height)
        )
        return VStack(spacing: 12) {
            ClueBar(session: session, perform: model.perform)
            grid(session)
                .frame(height: max(80, floor(cell) * CGFloat(puzzle.height)))
            HStack(alignment: .top, spacing: 8) {
                ClueListView(direction: .across, session: session, perform: model.perform)
                ClueListView(direction: .down, session: session, perform: model.perform)
            }
            .frame(minHeight: 0, maxHeight: .infinity)
        }
    }

    private func grid(_ session: SolveSession) -> some View {
        GridView(session: session) { cell in
            gridFocused = true
            model.perform(.select(cell: cell))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: Keyboard visibility

    private var showsOnscreenKeyboard: Bool {
        #if os(iOS)
        keyboardPreference ?? !hardwareKeyboard.isConnected
        #else
        false
        #endif
    }

    private var showKeyboardBinding: Binding<Bool> {
        Binding(get: { showsOnscreenKeyboard }, set: { keyboardPreference = $0 })
    }

    // MARK: Confirmation

    private var confirmationTitle: String {
        model.pendingConfirmation == .resetPuzzle ? "Reset this puzzle?" : "Reveal the whole puzzle?"
    }

    private var confirmationBinding: Binding<Bool> {
        Binding(get: { model.pendingConfirmation != nil }, set: { if !$0 { model.pendingConfirmation = nil } })
    }
}

private struct BannerView: View {
    let banner: PuzzleViewModel.Banner?

    var body: some View {
        if let banner {
            Label(text(banner), systemImage: symbol(banner))
                .font(.system(.headline, design: .rounded))
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .foregroundStyle(.white)
                .background(color(banner).gradient, in: .capsule)
                .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
                .transition(.scale(scale: 0.8).combined(with: .opacity))
                .accessibilityAddTraits(.updatesFrequently)
        }
    }

    private func text(_ banner: PuzzleViewModel.Banner) -> String {
        switch banner {
        case .solved: "Solved! Nice work."
        case .notQuite: "Grid's full, but something's not right."
        case .checked(let wrong) where wrong == 0: "Everything checked is correct."
        case .checked(let wrong): "\(wrong) square\(wrong == 1 ? "" : "s") wrong"
        }
    }

    private func symbol(_ banner: PuzzleViewModel.Banner) -> String {
        switch banner {
        case .solved: "checkmark.seal.fill"
        case .notQuite: "questionmark.circle.fill"
        case .checked(let wrong): wrong == 0 ? "checkmark.circle.fill" : "xmark.circle.fill"
        }
    }

    private func color(_ banner: PuzzleViewModel.Banner) -> Color {
        switch banner {
        case .solved: Theme.success
        case .notQuite: .orange
        case .checked(let wrong): wrong == 0 ? Theme.success : Theme.incorrect
        }
    }
}

extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
