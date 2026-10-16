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

/// Why an Ask question was refused by the conversation rules.
enum AskLimitReason implements _isc.SerializableModel {
  /// The conversation already holds its maximum number of questions.
  questionLimit,

  /// The previous answer of this conversation is still being written.
  busy,

  /// The conversation is gone or past the viewing window: start a new one.
  expired;

  static AskLimitReason fromJson(String name) {
    switch (name) {
      case 'questionLimit':
        return AskLimitReason.questionLimit;
      case 'busy':
        return AskLimitReason.busy;
      case 'expired':
        return AskLimitReason.expired;
      default:
        throw ArgumentError(
          'Value "$name" cannot be converted to "AskLimitReason"',
        );
    }
  }

  @override
  String toJson() => name;

  @override
  String toString() => name;
}
