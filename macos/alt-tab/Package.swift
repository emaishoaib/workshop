// swift-tools-version: 5.9
import PackageDescription
import Foundation

// This replaced alt-tab-macos.xcodeproj as the build definition (see CHANGELOG.md, "Migrated off
// Xcode/xcodebuild to SwiftPM"). `swift build` only needs the Command Line Tools, not full Xcode.app.
//
// Resources (app.icns, SF-Pro-Text-Regular.otf) are intentionally NOT declared here as SwiftPM
// target resources: every resource lookup in this codebase goes through `Bundle.main` (e.g.
// `CGImage.allNamed("app.icns")` in App.swift, `Bundle.main.url(forResource:...)` in
// HelperExtensions.swift), which only resolves paths inside a real .app bundle's Contents/Resources
// — not SwiftPM's `Bundle.module`. build.sh copies them into the assembled .app bundle by hand,
// the same place Xcode's Resources build phase used to put them.

let packageDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let bridgingHeaderPath = packageDir.appendingPathComponent("alt-tab-macos-Bridging-Header.h").path

let package = Package(
    name: "AltTab",
    platforms: [.macOS(.v10_13)],
    dependencies: [
        .package(path: "vendor/ShortcutRecorder"),
    ],
    targets: [
        // Objective-C (ObjCExceptionCatcher.catching { ... }, used once in Application.swift to
        // swallow NSExceptions). This has to be its own target: SwiftPM on this machine's
        // toolchain rejects a single target with both Swift and Objective-C sources ("mixed
        // language source files; feature not supported") — that's an opt-in SwiftPM feature this
        // toolchain doesn't have enabled, not something a flag here can turn on. Splitting it out
        // is the standard workaround and is what upstream would need to do too.
        .target(
            name: "ObjCExceptionCatcherKit",
            path: "Sources/ObjCExceptionCatcherKit",
            publicHeadersPath: "include"
        ),
        .executableTarget(
            name: "AltTab",
            dependencies: [
                .product(name: "ShortcutRecorder", package: "ShortcutRecorder"),
                "ObjCExceptionCatcherKit",
            ],
            path: "src",
            exclude: [
                "experimentations", // EscapeAndGameOverlay.md — notes only, no source
                "vendors/ObjCExceptionCatcher.h", // moved to Sources/ObjCExceptionCatcherKit/
                "vendors/ObjCExceptionCatcher.m", // (kept here too until you delete them — see CHANGELOG)
            ],
            swiftSettings: [
                // Same bridging header Xcode used to wire via SWIFT_OBJC_BRIDGING_HEADER: brings
                // `@import Cocoa;` into scope for every Swift file in this target, matching the
                // old implicit-import behavior exactly (several files rely on this rather than
                // their own `import Cocoa`). ObjCExceptionCatcher itself is no longer imported
                // through here — see ObjCExceptionCatcherKit above.
                .unsafeFlags(["-import-objc-header", bridgingHeaderPath]),
            ],
            linkerSettings: [
                // SkyLight.framework.swift calls private WindowServer APIs via @_silgen_name;
                // these aren't tied to a real Swift module, so autolinking can't discover them —
                // needs an explicit search path + link flag (see config/base.xcconfig's old
                // FRAMEWORK_SEARCH_PATHS/OTHER_LDFLAGS comment for the same explanation).
                .unsafeFlags(["-F/System/Library/PrivateFrameworks"]),
                .linkedFramework("SkyLight"),
            ]
        ),
    ]
)
