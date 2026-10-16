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

/// Why the administrator conversation list was refused.
enum AskAdminReason implements _is.SerializableModel {
  /// The caller is not listed in `ADMIN_USER_IDS`.
  notAdmin,

  /// The caller is a shared demo account (never an administrator).
  demo,

  /// Conversation history is switched off on the server.
  disabled;

  static AskAdminReason fromJson(String name) {
    switch (name) {
      case 'notAdmin':
        return AskAdminReason.notAdmin;
      case 'demo':
        return AskAdminReason.demo;
      case 'disabled':
        return AskAdminReason.disabled;
      default:
        throw ArgumentError(
          'Value "$name" cannot be converted to "AskAdminReason"',
        );
    }
  }

  @override
  String toJson() => name;

  @override
  String toString() => name;
}
