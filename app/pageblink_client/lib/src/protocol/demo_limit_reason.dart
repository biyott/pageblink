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

/// Which demo rule was hit.
enum DemoLimitReason implements _isc.SerializableModel {
  /// The demo account already holds its maximum of own documents.
  createLimit,

  /// The shared daily question limit is used up.
  askLimit,

  /// A sample note or PDF cannot be edited, re-indexed or deleted.
  sampleLocked,

  /// The demo account cannot create or join projects.
  projectLocked;

  static DemoLimitReason fromJson(String name) {
    switch (name) {
      case 'createLimit':
        return DemoLimitReason.createLimit;
      case 'askLimit':
        return DemoLimitReason.askLimit;
      case 'sampleLocked':
        return DemoLimitReason.sampleLocked;
      case 'projectLocked':
        return DemoLimitReason.projectLocked;
      default:
        throw ArgumentError(
          'Value "$name" cannot be converted to "DemoLimitReason"',
        );
    }
  }

  @override
  String toJson() => name;

  @override
  String toString() => name;
}
