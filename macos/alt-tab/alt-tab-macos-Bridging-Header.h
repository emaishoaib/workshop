@import Cocoa; // implicitly visible to every Swift file in the target (unlike Swift's per-file
                // `import`); many files here rely on this rather than writing their own `import
                // Cocoa`. Used to come in transitively via AppCenterApplication.h's own `@import
                // Cocoa;` — moved here explicitly now that AppCenterApplication.h is deleted.
// (ObjCExceptionCatcher.h used to be imported here too, but SwiftPM on this machine's toolchain
// rejects a target with mixed Swift+Objective-C sources ("feature not supported"), which this
// bridging-header technique would have required if ObjCExceptionCatcher.m stayed inside src/.
// It's now its own target, Sources/ObjCExceptionCatcherKit/ — see Application.swift's
// `import ObjCExceptionCatcherKit` and Package.swift.)
