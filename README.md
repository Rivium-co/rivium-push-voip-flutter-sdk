# RiviumPush VoIP

VoIP call handling add-on for [RiviumPush](https://pub.dev/packages/rivium_push) push notifications.

This plugin intercepts VoIP call push notifications and shows native incoming call UI:
- **Android**: CallStyle notification (Android 12+) with full-screen incoming call activity
- **iOS**: CallKit with native iOS call screen

## Features

- Native incoming call UI on both platforms
- Works when app is in foreground, background, or terminated
- Self-contained: no AppDelegate changes needed on iOS
- Configurable timeout and missed call notifications
- Supports audio and video calls
- Cold start support: app launched from call notification

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  rivium_push: ^0.1.26
  rivium_push_voip: ^0.1.3
```

## Usage

### 1. Initialize the plugin

```dart
import 'package:rivium_push/rivium_push.dart';
import 'package:rivium_push_voip/rivium_push_voip.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize RiviumPush first
  await RiviumPush.init(RiviumPushConfig(
    apiKey: 'rv_live_your_api_key',
  ));

  // Register device
  await RiviumPush.register();

  // Initialize VoIP
  await RiviumPushVoIP.init(
    config: RiviumPushVoIPConfig(appName: 'MyApp'),
    onCallAccepted: (callData) {
      navigateToCallScreen(callData);
    },
    onCallDeclined: (callData) {
      notifyCallDeclined(callData.callId);
    },
    onCallTimeout: (callData) {
      handleMissedCall(callData);
    },
  );

  // Set API key for VoIP token registration
  final deviceId = await RiviumPush.getDeviceId();
  await RiviumPushVoIP.setApiKey(
    apiKey: 'rv_live_your_api_key',
    deviceId: deviceId,
  );

  // Check for initial call (app launched from call notification)
  final initialCall = await RiviumPushVoIP.getInitialCall();
  if (initialCall != null) {
    navigateToCallScreen(initialCall);
  }

  runApp(MyApp());
}
```

### 2. Send VoIP call from server

Send a push message with `type: "voip_call"` in the data:

```json
{
  "title": "Incoming Call",
  "body": "John Doe is calling",
  "data": {
    "type": "voip_call",
    "callerName": "John Doe",
    "callerId": "user123",
    "callerAvatar": "https://example.com/avatar.jpg",
    "callType": "video"
  }
}
```

The `type: "voip_call"` field triggers VoIP delivery. Without it, the message is delivered as a regular push notification.

### 3. End the call

```dart
await RiviumPushVoIP.endCall(callData.callId);
```

### 4. Report call connected (iOS)

On iOS, report when the actual call connection is established:

```dart
await RiviumPushVoIP.reportCallConnected(callData.callId);
```

## Configuration

```dart
RiviumPushVoIPConfig(
  appName: 'MyApp',                    // App name shown in call UI
  ringtoneUri: 'ringtone.mp3',         // Custom ringtone (optional)
  timeoutSeconds: 30,                  // Call timeout (default: 30)
  showMissedCallNotification: true,    // Missed call notification (default: true)
  callerNameKey: 'callerName',         // Payload key for caller name
  callerIdKey: 'callerId',            // Payload key for caller ID
  callerAvatarKey: 'callerAvatar',    // Payload key for avatar URL
  callTypeKey: 'callType',            // Payload key for call type
)
```

## Platform Setup

### Android

Add permissions to `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT" />
<uses-permission android:name="android.permission.VIBRATE" />
```

### iOS

Enable in Xcode -> Signing & Capabilities:
- **Push Notifications**
- **Background Modes** -> Voice over IP, Remote notifications

No AppDelegate changes needed. The plugin handles PushKit registration, VoIP token management, and CallKit internally.

## API Reference

### RiviumPushVoIP

| Method | Description |
|--------|-------------|
| `init()` | Initialize the VoIP plugin with config and callbacks |
| `setApiKey()` | Set API key for VoIP token registration with server |
| `getInitialCall()` | Get the call that launched the app (cold start) |
| `endCall(callId)` | End/dismiss a call |
| `reportCallConnected(callId)` | Report call as connected (iOS) |
| `showIncomingCall(callData)` | Manually trigger incoming call UI |
| `isConfigured()` | Check if VoIP was previously enabled |
| `isInitialized` | Check if plugin is currently initialized |

### Callbacks

| Callback | Description |
|----------|-------------|
| `onCallAccepted` | User accepted the incoming call |
| `onCallDeclined` | User declined the incoming call |
| `onCallTimeout` | Call timed out (not answered) |
| `onCallError` | An error occurred |

### CallData

| Property | Type | Description |
|----------|------|-------------|
| `callId` | String | Unique call identifier |
| `callerName` | String | Name of the caller |
| `callerId` | String? | Optional caller ID |
| `callerAvatar` | String? | Optional avatar URL |
| `mediaType` | CallMediaType | audio or video |
| `extra` | Map? | Additional payload data |
| `receivedAt` | DateTime | When call was received |

## How It Works

1. When VoIP is initialized, the plugin registers for PushKit (iOS) and saves the VoIP token to the server
2. When a push with `data.type = "voip_call"` is sent, the server delivers it via VoIP push (PushKit)
3. The plugin receives the push natively and shows CallKit (iOS) or CallStyle notification (Android)
4. Works in all app states: foreground, background, and terminated
5. On cold start (app killed), iOS relaunches the app and the plugin auto-initializes from saved config

## License

MIT License - see [LICENSE](LICENSE) for details.
