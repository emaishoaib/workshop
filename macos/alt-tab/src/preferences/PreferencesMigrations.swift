import Cocoa

/// This fork started from a fresh install with no legacy `UserDefaults` to carry forward, so the
/// long chain of upstream-AltTab version migrations (menubar-icon dropdown conversions,
/// blacklist->exceptions rename, shortcut-index remapping, etc. — going back to v6.18.1) was
/// dropped entirely. What's left is the still-relevant, version-independent cleanup plus the
/// `preferencesVersion` stamp (kept so a future migration, if one's ever needed again, has
/// something to key off of).
class PreferencesMigrations {
    /// Injectable so tests can run migrations against an isolated `UserDefaults` suite.
    /// Production keeps `.standard`; behavior is unchanged.
    static var defaults = UserDefaults.standard

    static func removeCorruptedPreferences() {
        // from v5.1.0+, there are crash reports of users somehow having their hold shortcuts set to ""
        ["holdShortcut", "holdShortcut2", "holdShortcut3", "holdShortcut4", "holdShortcut5"].forEach {
            if let s = Self.defaults.string(forKey: $0), s == "" {
                Self.defaults.removeObject(forKey: $0)
            }
        }
    }

    static func migratePreferences() {
        // Used to also call `ProTransitionState.markFreshInstallIfUnknown(existingVersion == nil)`
        // here — recorded whether this was a fresh install so the trial/upsell state machine
        // (Day 1/4/12/15/21/35 windows) knew when to start counting. Dropped along with `pro/`.
        Self.defaults.set(App.version, forKey: "preferencesVersion")
    }
}
