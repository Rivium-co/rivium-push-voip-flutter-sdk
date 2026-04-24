import 'dart:async';
import 'package:flutter/services.dart';
import 'voip_config.dart';
import 'call_data.dart';

/// Callback when user accepts an incoming call
typedef OnCallAccepted = void Function(CallData callData);

/// Callback when user declines an incoming call
typedef OnCallDeclined = void Function(CallData callData);

/// Callback when call times out (not answered)
typedef OnCallTimeout = void Function(CallData callData);

/// Callback when there's an error
typedef OnCallError = void Function(String error);

/// RiviumPushVoIP - VoIP call handling add-on for RiviumPush
///
/// This plugin intercepts VoIP call push notifications and shows
/// native incoming call UI on Android (CallStyle notification) and
/// iOS (CallKit).
///
/// Example usage:
/// ```dart
/// await RiviumPushVoIP.init(
///   config: RiviumPushVoIPConfig(appName: 'MyApp'),
///   onCallAccepted: (callData) {
///     // Navigate to call screen
///     navigateToCallScreen(callData);
///   },
///   onCallDeclined: (callData) {
///     // Notify server that call was declined
///     notifyCallDeclined(callData.callId);
///   },
/// );
/// ```
class RiviumPushVoIP {
  static const MethodChannel _channel = MethodChannel('co.rivium.push/voip');

  static OnCallAccepted? _onCallAccepted;
  static OnCallDeclined? _onCallDeclined;
  static OnCallTimeout? _onCallTimeout;
  static OnCallError? _onCallError;

  static bool _initialized = false;
  static bool _methodHandlerSet = false;
  static RiviumPushVoIPConfig? _config;

  /// Queue for calls that arrive before callbacks are set
  static CallData? _pendingAcceptedCall;
  static CallData? _pendingDeclinedCall;
  static CallData? _pendingTimeoutCall;

  /// Initialize the VoIP plugin
  ///
  /// Must be called after [RiviumPush.init()]
  static Future<void> init({
    required RiviumPushVoIPConfig config,
    required OnCallAccepted onCallAccepted,
    OnCallDeclined? onCallDeclined,
    OnCallTimeout? onCallTimeout,
    OnCallError? onCallError,
  }) async {
    if (_initialized) {
      print('[RiviumPushVoIP] Already initialized');
      return;
    }

    _config = config;
    _onCallAccepted = onCallAccepted;
    _onCallDeclined = onCallDeclined;
    _onCallTimeout = onCallTimeout;
    _onCallError = onCallError;

    // Set method handler early to catch any pending calls
    if (!_methodHandlerSet) {
      _channel.setMethodCallHandler(_handleMethod);
      _methodHandlerSet = true;
    }

    try {
      await _channel.invokeMethod('init', config.toMap());
      _initialized = true;
      print('[RiviumPushVoIP] Initialized successfully');

      // Deliver any pending calls that arrived before callbacks were set
      _deliverPendingCalls();
    } catch (e) {
      print('[RiviumPushVoIP] Initialization error: $e');
      _onCallError?.call(e.toString());
    }
  }

  /// Set API key for VoIP token registration with server.
  /// Call this after RiviumPush.init() so the VoIP plugin can send
  /// its PushKit token to the server independently.
  static Future<void> setApiKey({
    required String apiKey,
    String? deviceId,
    String? serverUrl,
  }) async {
    try {
      await _channel.invokeMethod('setApiKey', {
        'apiKey': apiKey,
        'deviceId': deviceId ?? '',
        'serverUrl': serverUrl ?? 'https://push-api.rivium.co',
      });
    } catch (e) {
      print('[RiviumPushVoIP] setApiKey error: $e');
    }
  }

  /// Deliver any calls that were queued before callbacks were set
  static void _deliverPendingCalls() {
    if (_pendingAcceptedCall != null) {
      print('[RiviumPushVoIP] Delivering pending accepted call: ${_pendingAcceptedCall!.callId}');
      _onCallAccepted?.call(_pendingAcceptedCall!);
      _pendingAcceptedCall = null;
    }
    if (_pendingDeclinedCall != null) {
      print('[RiviumPushVoIP] Delivering pending declined call: ${_pendingDeclinedCall!.callId}');
      _onCallDeclined?.call(_pendingDeclinedCall!);
      _pendingDeclinedCall = null;
    }
    if (_pendingTimeoutCall != null) {
      print('[RiviumPushVoIP] Delivering pending timeout call: ${_pendingTimeoutCall!.callId}');
      _onCallTimeout?.call(_pendingTimeoutCall!);
      _pendingTimeoutCall = null;
    }
  }

  /// Check if there's a pending call that launched the app
  ///
  /// Call this early in your app initialization to handle
  /// cases where the app was launched from a call notification
  static Future<CallData?> getInitialCall() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getInitialCall');
      if (result == null) return null;
      return CallData.fromMap(Map<String, dynamic>.from(result));
    } catch (e) {
      print('[RiviumPushVoIP] getInitialCall error: $e');
      return null;
    }
  }

  /// End the current call (dismiss the native call UI)
  ///
  /// Call this when the call ends or is cancelled
  static Future<void> endCall(String callId) async {
    try {
      await _channel.invokeMethod('endCall', {'callId': callId});
    } catch (e) {
      print('[RiviumPushVoIP] endCall error: $e');
    }
  }

  /// Report call as connected (for CallKit on iOS)
  ///
  /// Call this when the actual call connection is established
  static Future<void> reportCallConnected(String callId) async {
    try {
      await _channel.invokeMethod('reportCallConnected', {'callId': callId});
    } catch (e) {
      print('[RiviumPushVoIP] reportCallConnected error: $e');
    }
  }

  /// Show incoming call UI manually
  ///
  /// Use this to trigger the native incoming call UI from a push message.
  /// The [callData] should contain at minimum: callId, callerName
  static Future<void> showIncomingCall(CallData callData) async {
    try {
      print('[RiviumPushVoIP] showIncomingCall: ${callData.callId}');
      await _channel.invokeMethod('showIncomingCall', callData.toMap());
    } catch (e) {
      print('[RiviumPushVoIP] showIncomingCall error: $e');
      _onCallError?.call(e.toString());
    }
  }

  /// Check if plugin is initialized
  static bool get isInitialized => _initialized;

  /// Check if VoIP was previously configured (native side has saved config)
  /// Returns true if VoIP was enabled in a previous session
  static Future<bool> isConfigured() async {
    try {
      final result = await _channel.invokeMethod<bool>('isConfigured');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Get current configuration
  static RiviumPushVoIPConfig? get config => _config;

  /// Handle method calls from native side
  static Future<void> _handleMethod(MethodCall call) async {
    print('[RiviumPushVoIP] _handleMethod: ${call.method}');
    print('[RiviumPushVoIP] Arguments: ${call.arguments}');

    switch (call.method) {
      case 'onCallAccepted':
        final callData = CallData.fromMap(
          Map<String, dynamic>.from(call.arguments as Map),
        );
        print('[RiviumPushVoIP] Call accepted: ${callData.callId}');
        if (_onCallAccepted != null) {
          _onCallAccepted!(callData);
        } else {
          // Queue the call for later delivery when callbacks are set
          print('[RiviumPushVoIP] Callback not set yet, queuing accepted call');
          _pendingAcceptedCall = callData;
        }
        break;

      case 'onCallDeclined':
        final callData = CallData.fromMap(
          Map<String, dynamic>.from(call.arguments as Map),
        );
        print('[RiviumPushVoIP] Call declined: ${callData.callId}');
        if (_onCallDeclined != null) {
          _onCallDeclined!(callData);
        } else {
          print('[RiviumPushVoIP] Callback not set yet, queuing declined call');
          _pendingDeclinedCall = callData;
        }
        break;

      case 'onCallTimeout':
        final callData = CallData.fromMap(
          Map<String, dynamic>.from(call.arguments as Map),
        );
        print('[RiviumPushVoIP] Call timeout: ${callData.callId}');
        if (_onCallTimeout != null) {
          _onCallTimeout!(callData);
        } else {
          print('[RiviumPushVoIP] Callback not set yet, queuing timeout call');
          _pendingTimeoutCall = callData;
        }
        break;

      case 'onError':
        final error = call.arguments as String;
        print('[RiviumPushVoIP] Error: $error');
        _onCallError?.call(error);
        break;

      default:
        print('[RiviumPushVoIP] Unknown method: ${call.method}');
    }
  }
}
