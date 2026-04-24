# Changelog

## [0.1.0] - 2026-04-24

### Added
- Native incoming call UI for iOS (CallKit) and Android (CallStyle notifications)
- PushKit VoIP push registration and handling (iOS)
- Self-contained plugin — no AppDelegate VoIP code required
- Cold start support for killed-app VoIP pushes
- Device ID resolution matching RiviumPush SDK
- VoIP token management and server registration
- Dart API: init, setApiKey, showIncomingCall, endCall, getInitialCall
