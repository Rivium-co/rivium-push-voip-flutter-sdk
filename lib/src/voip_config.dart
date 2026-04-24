/// Configuration for RiviumPushVoIP plugin
class RiviumPushVoIPConfig {
  /// The key in push data that contains the call type identifier
  /// Default: 'type', expects value 'voip_call'
  final String callTypeKey;

  /// The value that identifies a VoIP call message
  /// Default: 'voip_call'
  final String callTypeValue;

  /// The key in push data for caller name
  /// Default: 'callerName'
  final String callerNameKey;

  /// The key in push data for caller avatar URL
  /// Default: 'callerAvatar'
  final String callerAvatarKey;

  /// The key in push data for call ID/UUID
  /// Default: 'uuid'
  final String callIdKey;

  /// The key in push data for call type (VIDEO/AUDIO)
  /// Default: 'callType'
  final String callMediaTypeKey;

  /// App name shown in call UI
  final String appName;

  /// Ringtone resource name (without extension)
  /// Place in android/app/src/main/res/raw/
  /// Default: uses system ringtone
  final String? ringtone;

  /// Vibration pattern for incoming call
  /// Default: [0, 1000, 500, 1000]
  final List<int>? vibrationPattern;

  /// Timeout in seconds before call is auto-declined
  /// Default: 60 seconds
  final int callTimeout;

  /// Whether to show call UI when app is in foreground
  /// Default: false (let Flutter handle foreground calls)
  final bool showCallUIInForeground;

  /// Android notification channel ID for calls
  final String androidChannelId;

  /// Android notification channel name
  final String androidChannelName;

  const RiviumPushVoIPConfig({
    this.callTypeKey = 'type',
    this.callTypeValue = 'voip_call',
    this.callerNameKey = 'callerName',
    this.callerAvatarKey = 'callerAvatar',
    this.callIdKey = 'uuid',
    this.callMediaTypeKey = 'callType',
    required this.appName,
    this.ringtone,
    this.vibrationPattern,
    this.callTimeout = 60,
    this.showCallUIInForeground = false,
    this.androidChannelId = 'rivium_push_voip_calls',
    this.androidChannelName = 'Incoming Calls',
  });

  Map<String, dynamic> toMap() => {
        'callTypeKey': callTypeKey,
        'callTypeValue': callTypeValue,
        'callerNameKey': callerNameKey,
        'callerAvatarKey': callerAvatarKey,
        'callIdKey': callIdKey,
        'callMediaTypeKey': callMediaTypeKey,
        'appName': appName,
        'ringtone': ringtone,
        'vibrationPattern': vibrationPattern,
        'callTimeout': callTimeout,
        'showCallUIInForeground': showCallUIInForeground,
        'androidChannelId': androidChannelId,
        'androidChannelName': androidChannelName,
      };
}
