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
import 'ask_admin_reason.dart' as _ijcvup8n;

/// Thrown by the administrator list when the caller may not use it. A
/// serialized exception, so the app gets it as an answer and the server logs
/// no error: it is a normal refusal, not a failure.
abstract class AskAdminException
    implements
        _isc.SerializableException,
        _isc.SerializableModel,
        _isc.ProtocolSerialization {
  AskAdminException._({required this.reason});

  factory AskAdminException({required _ijcvup8n.AskAdminReason reason}) =
      _AskAdminExceptionImpl;

  factory AskAdminException.fromJson(Map<String, dynamic> jsonSerialization) {
    return AskAdminException(
      reason: _ijcvup8n.AskAdminReason.fromJson(
        (jsonSerialization['reason'] as String),
      ),
    );
  }

  _ijcvup8n.AskAdminReason reason;

  /// Returns a shallow copy of this [AskAdminException]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  AskAdminException copyWith({_ijcvup8n.AskAdminReason? reason});
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AskAdminException',
      'reason': reason.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'AskAdminException',
      'reason': reason.toJson(),
    };
  }

  @override
  String toString() {
    return 'AskAdminException(reason: $reason)';
  }
}

class _AskAdminExceptionImpl extends AskAdminException {
  _AskAdminExceptionImpl({required _ijcvup8n.AskAdminReason reason})
    : super._(reason: reason);

  /// Returns a shallow copy of this [AskAdminException]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  AskAdminException copyWith({_ijcvup8n.AskAdminReason? reason}) {
    return AskAdminException(reason: reason ?? this.reason);
  }
}
