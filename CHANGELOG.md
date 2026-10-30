# Changelog

## [0.1.3] - 2026-10-30

### Added
- iOS: Swift Package Manager support. Flutter apps with Swift Package Manager on (the default in current Flutter) get the native iOS SDK through it; apps on CocoaPods work as before.

## [0.1.2] - 2026-10-29

### Fixed
- Android: `callIdKey` is now used to find the call ID in the push payload (Android VoIP SDK 0.1.1), and call payloads and caller names are no longer written to the device log.

## [0.1.1] - 2026-10-12

### Added
- iOS: the VoIP token registration reports the plugin's identity (`sdkName: flutter-voip`, `sdkVersion`) so the dashboard can tell these registrations apart.

## [0.1.0] - 2026-04-24

### Added
- Native incoming call UI for iOS (CallKit) and Android (CallStyle notifications)
- PushKit VoIP push registration and handling (iOS)
- Self-contained plugin — no AppDelegate VoIP code required
- Cold start support for killed-app VoIP pushes
- Device ID resolution matching RiviumPush SDK
- VoIP token management and server registration
- Dart API: init, setApiKey, showIncomingCall, endCall, getInitialCall
