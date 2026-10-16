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
import 'demo_limit_reason.dart' as _iyfquffa;

/// Thrown when the demo account hits one of its rules. Not a permission
/// error: the app answers it with "sign up to keep going".
abstract class DemoLimitException
    implements
        _isc.SerializableException,
        _isc.SerializableModel,
        _isc.ProtocolSerialization {
  DemoLimitException._({
    required this.reason,
    this.limit,
  });

  factory DemoLimitException({
    required _iyfquffa.DemoLimitReason reason,
    int? limit,
  }) = _DemoLimitExceptionImpl;

  factory DemoLimitException.fromJson(Map<String, dynamic> jsonSerialization) {
    return DemoLimitException(
      reason: _iyfquffa.DemoLimitReason.fromJson(
        (jsonSerialization['reason'] as String),
      ),
      limit: jsonSerialization['limit'] as int?,
    );
  }

  _iyfquffa.DemoLimitReason reason;

  /// The number behind [reason]: documents for createLimit, questions per day
  /// for askLimit. Null for the other reasons.
  int? limit;

  /// Returns a shallow copy of this [DemoLimitException]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  DemoLimitException copyWith({
    _iyfquffa.DemoLimitReason? reason,
    int? limit,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DemoLimitException',
      'reason': reason.toJson(),
      if (limit != null) 'limit': limit,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'DemoLimitException',
      'reason': reason.toJson(),
      if (limit != null) 'limit': limit,
    };
  }

  @override
  String toString() {
    return 'DemoLimitException(reason: $reason, limit: $limit)';
  }
}

class _Undefined {}

class _DemoLimitExceptionImpl extends DemoLimitException {
  _DemoLimitExceptionImpl({
    required _iyfquffa.DemoLimitReason reason,
    int? limit,
  }) : super._(
         reason: reason,
         limit: limit,
       );

  /// Returns a shallow copy of this [DemoLimitException]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  DemoLimitException copyWith({
    _iyfquffa.DemoLimitReason? reason,
    Object? limit = _Undefined,
  }) {
    return DemoLimitException(
      reason: reason ?? this.reason,
      limit: limit is int? ? limit : this.limit,
    );
  }
}
