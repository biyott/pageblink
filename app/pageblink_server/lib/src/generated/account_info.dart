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
import 'package:serverpod/serverpod.dart' as _is;

/// Who is signed in, for the account line in Settings. Never about anyone
/// but the caller.
abstract class AccountInfo
    implements _is.SerializableModel, _is.ProtocolSerialization {
  AccountInfo._({
    this.email,
    required this.isDemo,
  });

  factory AccountInfo({
    String? email,
    required bool isDemo,
  }) = _AccountInfoImpl;

  factory AccountInfo.fromJson(Map<String, dynamic> jsonSerialization) {
    return AccountInfo(
      email: jsonSerialization['email'] as String?,
      isDemo: _is.BoolJsonExtension.fromJson(jsonSerialization['isDemo']),
    );
  }

  /// Sign-in email of a regular account. Null for a demo account (shared,
  /// nothing personal to show) and when no email account is found.
  String? email;

  /// The caller is signed in as a shared demo account.
  bool isDemo;

  /// Returns a shallow copy of this [AccountInfo]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  AccountInfo copyWith({
    String? email,
    bool? isDemo,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AccountInfo',
      if (email != null) 'email': email,
      'isDemo': isDemo,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'AccountInfo',
      if (email != null) 'email': email,
      'isDemo': isDemo,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _AccountInfoImpl extends AccountInfo {
  _AccountInfoImpl({
    String? email,
    required bool isDemo,
  }) : super._(
         email: email,
         isDemo: isDemo,
       );

  /// Returns a shallow copy of this [AccountInfo]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  AccountInfo copyWith({
    Object? email = _Undefined,
    bool? isDemo,
  }) {
    return AccountInfo(
      email: email is String? ? email : this.email,
      isDemo: isDemo ?? this.isDemo,
    );
  }
}
