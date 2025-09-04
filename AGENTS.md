# AGENTS.md

This file provides guidance to coding agents when working with code in this repository.

# Leader Key Development Guide

## Build & Test Commands

- Build and run: `xcodebuild -scheme "Leader Key" -configuration Debug build`
- Run all tests: `xcodebuild -scheme "Leader Key" -testPlan "TestPlan" test`
- Run single test: `xcodebuild -scheme "Leader Key" -testPlan "TestPlan" -only-testing:Leader KeyTests/UserConfigTests/testInitializesWithDefaults test`
- Bump version: `bin/bump`
- Create release: `bin/release`

## Architecture Overview

Leader Key is a macOS application that provides customizable keyboard shortcuts. The core architecture consists of:

**Key Components:**

- `AppDelegate`: Application lifecycle, global shortcuts registration, update management
- `Controller`: Central event handling, manages key sequences and window display
- `UserConfig`: JSON configuration management with validation
- `UserState`: Tracks navigation through key sequences
- `MainWindow`: Base class for theme windows

**Theme System:**

- Themes inherit from `MainWindow` and implement `draw()` method
- Available themes: MysteryBox, Mini, Breadcrumbs, ForTheHorde, Cheater
- Each theme provides different visual representations of shortcuts

**Configuration Flow:**

- Config stored at `~/Library/Application Support/Leader Key/config.json`
- `FileMonitor` watches for changes and triggers reload
- `ConfigValidator` ensures no key conflicts
- Actions support: applications, URLs, commands, folders

**Testing Architecture:**

- Uses XCTest with custom `TestAlertManager` for UI testing
- Tests use isolated UserDefaults and temporary directories
- Focus on configuration validation and state management

## Code Style Guidelines

- **Imports**: Group Foundation/AppKit imports first, then third-party libraries (Combine, Defaults)
- **Naming**: Use descriptive camelCase for variables/functions, PascalCase for types
- **Types**: Use explicit type annotations for public properties and parameters
- **Error Handling**: Use appropriate error handling with do/catch blocks and alerts
- **Extensions**: Create extensions for additional functionality on existing types
- **State Management**: Use @Published and ObservableObject for reactive UI updates
- **Testing**: Create separate test cases with descriptive names, use XCTAssert\* methods
- **Access Control**: Use appropriate access modifiers (private, fileprivate, internal)
- **Documentation**: Use comments for complex logic or non-obvious implementations

Follow Swift idioms and default formatting (4-space indentation, spaces around operators).

