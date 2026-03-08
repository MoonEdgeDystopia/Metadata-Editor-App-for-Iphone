# MetadataRemover Project

## Project Overview

MetadataRemover is an iOS application project built with **SwiftUI** and **Swift 5.0**. It is a standard Xcode project targeting iOS devices (iPhone and iPad). Currently, this is a newly created template project with minimal implementation - it displays a "Hello, world!" placeholder view.

- **Bundle Identifier**: `name.danielsantosmendez.MetadataRemover`
- **Version**: 1.0
- **Development Team**: 38X539SLX8
- **Author**: Daniel Santos Mendez

## Technology Stack

- **Language**: Swift 5.0
- **UI Framework**: SwiftUI
- **IDE**: Xcode 26.1.1 (or later)
- **Minimum iOS Version**: 26.1
- **Supported Devices**: iPhone and iPad (TARGETED_DEVICE_FAMILY = "1,2")
- **Concurrency**: Swift Concurrency enabled with `MainActor` default isolation

## Project Structure

```
MetadataRemover/
├── MetadataRemover/                    # Main application source
│   ├── MetadataRemoverApp.swift        # App entry point (@main)
│   ├── ContentView.swift               # Main view (placeholder)
│   └── Assets.xcassets/                # Image and color assets
├── MetadataRemoverTests/               # Unit tests
│   └── MetadataRemoverTests.swift      # Swift Testing framework tests
├── MetadataRemoverUITests/             # UI tests
│   ├── MetadataRemoverUITests.swift    # XCTest-based UI tests
│   └── MetadataRemoverUITestsLaunchTests.swift  # Launch tests with screenshots
└── MetadataRemover.xcodeproj/          # Xcode project configuration
    └── project.pbxproj                 # Project settings and build phases
```

## Key Configuration Files

- **`MetadataRemover.xcodeproj/project.pbxproj`**: Main Xcode project file containing all build settings, targets, and file references. Uses `PBXFileSystemSynchronizedRootGroup` for folder-based synchronization (modern Xcode feature).
- **`MetadataRemover/Assets.xcassets/`**: Asset catalog containing app icons and color definitions.

## Build and Test Commands

This project uses Xcode's native build system. Use the following commands:

### Build
```bash
# Build the project for iOS Simulator
xcodebuild -project MetadataRemover.xcodeproj -scheme MetadataRemover -destination 'platform=iOS Simulator,name=iPhone 16' build

# Build for device (requires signing)
xcodebuild -project MetadataRemover.xcodeproj -scheme MetadataRemover -destination 'generic/platform=iOS' build
```

### Test
```bash
# Run all tests
xcodebuild -project MetadataRemover.xcodeproj -scheme MetadataRemover -destination 'platform=iOS Simulator,name=iPhone 16' test

# Run only unit tests
xcodebuild -project MetadataRemover.xcodeproj -scheme MetadataRemover -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:MetadataRemoverTests

# Run only UI tests
xcodebuild -project MetadataRemover.xcodeproj -scheme MetadataRemover -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:MetadataRemoverUITests
```

### Clean
```bash
xcodebuild -project MetadataRemover.xcodeproj clean
```

## Code Style Guidelines

The project uses standard Swift and Xcode conventions:

- **Swift Version**: 5.0 with modern concurrency features
- **File Headers**: Standard Xcode header comments with author and creation date
- **Import Style**: Use `@testable import` for test targets
- **Actor Isolation**: `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` - UI updates should use MainActor
- **Documentation**: `CLANG_WARN_DOCUMENTATION_COMMENTS = YES` - documentation comments are encouraged

## Testing Strategy

The project includes three test targets:

### 1. MetadataRemoverTests (Unit Tests)
- **Framework**: Swift Testing (modern replacement for XCTest)
- **Pattern**: Uses `@Test` annotation and `#expect(...)` assertions
- **Purpose**: Test business logic and model layers
- **Current State**: Contains only a placeholder test

### 2. MetadataRemoverUITests (UI Tests)
- **Framework**: XCTest
- **Pattern**: `XCUIApplication()` for app launching and interaction
- **Features**:
  - `continueAfterFailure = false` - tests stop on first failure
  - `setUpWithError()` and `tearDownWithError()` lifecycle methods
  - `@MainActor` annotation for UI test methods
  - Performance testing with `measure(metrics:)`

### 3. MetadataRemoverUITestsLaunchTests (Launch Tests)
- **Framework**: XCTest
- **Purpose**: Screenshot generation for launch screens
- **Features**:
  - `runsForEachTargetApplicationUIConfiguration = true` - runs for all UI configurations (light/dark mode, etc.)
  - Captures and attaches screenshots using `XCTAttachment`

## Build Configurations

### Debug Configuration
- Optimization Level: `-Onone` (no optimization)
- Debug Information: `dwarf` with source inclusion
- Preprocessor Definitions: `DEBUG=1`
- Swift Active Compilation Conditions: `DEBUG`
- Testability: Enabled (`ENABLE_TESTABILITY = YES`)

### Release Configuration
- Optimization Level: `wholemodule` (whole module optimization)
- Debug Information: `dwarf-with-dsym`
- Assertions: Disabled (`ENABLE_NS_ASSERTIONS = NO`)
- Swift Compilation Mode: `wholemodule`
- Validation: Enabled (`VALIDATE_PRODUCT = YES`)

## Deployment and Signing

- **Code Signing**: Automatic (`CODE_SIGN_STYLE = Automatic`)
- **Development Team**: 38X539SLX8
- **Supported Orientations**:
  - iPhone: Portrait, Landscape Left, Landscape Right
  - iPad: Portrait, Portrait Upside Down, Landscape Left, Landscape Right
- **Bundle Generation**: Auto-generated Info.plist (`GENERATE_INFOPLIST_FILE = YES`)

## Security Considerations

- **User Script Sandboxing**: Enabled (`ENABLE_USER_SCRIPT_SANDBOXING = YES`)
- **ARC**: Enabled (`CLANG_ENABLE_OBJC_ARC = YES`)
- **Modules**: Enabled (`CLANG_ENABLE_MODULES = YES`)
- **Nullability**: Analyzer enabled (`CLANG_ANALYZER_NONNULL = YES`)
- **User Paths**: Never search (`ALWAYS_SEARCH_USER_PATHS = NO`)

## Development Notes

- This is currently a **template project** with placeholder content. The main functionality for metadata removal needs to be implemented.
- The project uses modern Xcode features like `PBXFileSystemSynchronizedRootGroup` for automatic file synchronization.
- No external dependencies or package managers (Swift Package Manager, CocoaPods, Carthage) are currently configured.
- The app currently supports English localization (`en` and `Base` regions).
