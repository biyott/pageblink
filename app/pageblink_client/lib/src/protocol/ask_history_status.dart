/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod_client/serverpod_client.dart' as _isc;

/// Whether Ask history is on and its rules. When `enabled` is false the app
/// shows none of the history UI.
abstract class AskHistoryStatus
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  AskHistoryStatus._({
    required this.enabled,
    int? questionLimit,
    int? visibleMinutes,
    int? retentionDays,
    int? questionMaxChars,
    bool? isAdmin,
  }) : questionLimit = questionLimit ?? 0,
       visibleMinutes = visibleMinutes ?? 0,
       retentionDays = retentionDays ?? 0,
       questionMaxChars = questionMaxChars ?? 0,
       isAdmin = isAdmin ?? false;

  factory AskHistoryStatus({
    required bool enabled,
    int? questionLimit,
    int? visibleMinutes,
    int? retentionDays,
    int? questionMaxChars,
    bool? isAdmin,
  }) = _AskHistoryStatusImpl;

  factory AskHistoryStatus.fromJson(Map<String, dynamic> jsonSerialization) {
    return AskHistoryStatus(
      enabled: _isc.BoolJsonExtension.fromJson(jsonSerialization['enabled']),
      questionLimit: jsonSerialization['questionLimit'] as int?,
      visibleMinutes: jsonSerialization['visibleMinutes'] as int?,
      retentionDays: jsonSerialization['retentionDays'] as int?,
      questionMaxChars: jsonSerialization['questionMaxChars'] as int?,
      isAdmin: jsonSerialization['isAdmin'] == null
          ? null
          : _isc.BoolJsonExtension.fromJson(jsonSerialization['isAdmin']),
    );
  }

  bool enabled;

  /// Questions per conversation.
  int questionLimit;

  /// Minutes a conversation stays visible after its last activity.
  int visibleMinutes;

  /// Days the server keeps conversations.
  int retentionDays;

  /// Longest question the server keeps (the input box stops there).
  int questionMaxChars;

  /// The caller may open the admin conversation list.
  bool isAdmin;

  /// Returns a shallow copy of this [AskHistoryStatus]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  AskHistoryStatus copyWith({
    bool? enabled,
    int? questionLimit,
    int? visibleMinutes,
    int? retentionDays,
    int? questionMaxChars,
    bool? isAdmin,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AskHistoryStatus',
      'enabled': enabled,
      'questionLimit': questionLimit,
      'visibleMinutes': visibleMinutes,
      'retentionDays': retentionDays,
      'questionMaxChars': questionMaxChars,
      'isAdmin': isAdmin,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'AskHistoryStatus',
      'enabled': enabled,
      'questionLimit': questionLimit,
      'visibleMinutes': visibleMinutes,
      'retentionDays': retentionDays,
      'questionMaxChars': questionMaxChars,
      'isAdmin': isAdmin,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _AskHistoryStatusImpl extends AskHistoryStatus {
  _AskHistoryStatusImpl({
    required bool enabled,
    int? questionLimit,
    int? visibleMinutes,
    int? retentionDays,
    int? questionMaxChars,
    bool? isAdmin,
  }) : super._(
         enabled: enabled,
         questionLimit: questionLimit,
         visibleMinutes: visibleMinutes,
         retentionDays: retentionDays,
         questionMaxChars: questionMaxChars,
         isAdmin: isAdmin,
       );

  /// Returns a shallow copy of this [AskHistoryStatus]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  AskHistoryStatus copyWith({
    bool? enabled,
    int? questionLimit,
    int? visibleMinutes,
    int? retentionDays,
    int? questionMaxChars,
    bool? isAdmin,
  }) {
    return AskHistoryStatus(
      enabled: enabled ?? this.enabled,
      questionLimit: questionLimit ?? this.questionLimit,
      visibleMinutes: visibleMinutes ?? this.visibleMinutes,
      retentionDays: retentionDays ?? this.retentionDays,
      questionMaxChars: questionMaxChars ?? this.questionMaxChars,
      isAdmin: isAdmin ?? this.isAdmin,
    );
  }
}
