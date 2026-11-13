import Observation

/// App-wide presentation state that menu-bar commands and views both drive.
@Observable
@MainActor
final class AppNavigation {
    var showingFolderPicker = false
    var showingSettings = false
}
