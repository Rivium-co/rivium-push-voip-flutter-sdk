/// Represents an incoming VoIP call
class CallData {
  /// Unique call identifier
  final String callId;

  /// Name of the caller
  final String callerName;

  /// Avatar URL of the caller (optional)
  final String? callerAvatar;

  /// Type of call: VIDEO or AUDIO
  final CallMediaType mediaType;

  /// Additional data from the push notification
  final Map<String, dynamic> extra;

  /// Timestamp when call was received
  final DateTime receivedAt;

  const CallData({
    required this.callId,
    required this.callerName,
    this.callerAvatar,
    required this.mediaType,
    this.extra = const {},
    required this.receivedAt,
  });

  factory CallData.fromMap(Map<String, dynamic> map) {
    return CallData(
      callId: map['callId'] as String? ?? '',
      callerName: map['callerName'] as String? ?? 'Unknown',
      callerAvatar: map['callerAvatar'] as String?,
      mediaType: CallMediaType.fromString(map['mediaType'] as String?),
      extra: Map<String, dynamic>.from(map['extra'] as Map? ?? {}),
      receivedAt: map['receivedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['receivedAt'] as int)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'callId': callId,
        'callerName': callerName,
        'callerAvatar': callerAvatar,
        'mediaType': mediaType.name,
        'extra': extra,
        'receivedAt': receivedAt.millisecondsSinceEpoch,
      };

  @override
  String toString() =>
      'CallData(callId: $callId, callerName: $callerName, mediaType: $mediaType)';
}

/// Type of media for the call
enum CallMediaType {
  video,
  audio;

  static CallMediaType fromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'VIDEO':
        return CallMediaType.video;
      case 'AUDIO':
      default:
        return CallMediaType.audio;
    }
  }
}

/// Call action taken by the user
enum CallAction {
  accepted,
  declined,
  timeout,
}
