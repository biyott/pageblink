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
import 'ask_limit_reason.dart' as _ihtb12es;

/// Thrown when a question breaks a conversation rule. Not a permission error:
/// the app answers it with a hint (new conversation / wait).
abstract class AskLimitException
    implements
        _isc.SerializableException,
        _isc.SerializableModel,
        _isc.ProtocolSerialization {
  AskLimitException._({
    required this.reason,
    this.limit,
  });

  factory AskLimitException({
    required _ihtb12es.AskLimitReason reason,
    int? limit,
  }) = _AskLimitExceptionImpl;

  factory AskLimitException.fromJson(Map<String, dynamic> jsonSerialization) {
    return AskLimitException(
      reason: _ihtb12es.AskLimitReason.fromJson(
        (jsonSerialization['reason'] as String),
      ),
      limit: jsonSerialization['limit'] as int?,
    );
  }

  _ihtb12es.AskLimitReason reason;

  /// Questions per conversation, for questionLimit.
  int? limit;

  /// Returns a shallow copy of this [AskLimitException]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  AskLimitException copyWith({
    _ihtb12es.AskLimitReason? reason,
    int? limit,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AskLimitException',
      'reason': reason.toJson(),
      if (limit != null) 'limit': limit,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'AskLimitException',
      'reason': reason.toJson(),
      if (limit != null) 'limit': limit,
    };
  }

  @override
  String toString() {
    return 'AskLimitException(reason: $reason, limit: $limit)';
  }
}

class _Undefined {}

class _AskLimitExceptionImpl extends AskLimitException {
  _AskLimitExceptionImpl({
    required _ihtb12es.AskLimitReason reason,
    int? limit,
  }) : super._(
         reason: reason,
         limit: limit,
       );

  /// Returns a shallow copy of this [AskLimitException]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  AskLimitException copyWith({
    _ihtb12es.AskLimitReason? reason,
    Object? limit = _Undefined,
  }) {
    return AskLimitException(
      reason: reason ?? this.reason,
      limit: limit is int? ? limit : this.limit,
    );
  }
}
