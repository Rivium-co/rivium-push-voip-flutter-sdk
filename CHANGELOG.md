# Changelog

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
