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
import 'package:pageblink_client/src/protocol/protocol.dart' as _igm2snhz;
import 'package:serverpod_client/serverpod_client.dart' as _isc;
import 'ask_admin_session.dart' as _ioy8iwam;
import 'ask_model_stat.dart' as _i8us82b8;

/// One page of the admin conversation list.
abstract class AskAdminPage
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  AskAdminPage._({
    required this.items,
    this.nextBeforeActiveAt,
    this.nextBeforeId,
    required this.models,
  });

  factory AskAdminPage({
    required List<_ioy8iwam.AskAdminSession> items,
    DateTime? nextBeforeActiveAt,
    int? nextBeforeId,
    required List<_i8us82b8.AskModelStat> models,
  }) = _AskAdminPageImpl;

  factory AskAdminPage.fromJson(Map<String, dynamic> jsonSerialization) {
    return AskAdminPage(
      items: _igm2snhz.Protocol().deserialize<List<_ioy8iwam.AskAdminSession>>(
        jsonSerialization['items'],
      ),
      nextBeforeActiveAt: jsonSerialization['nextBeforeActiveAt'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(
              jsonSerialization['nextBeforeActiveAt'],
            ),
      nextBeforeId: jsonSerialization['nextBeforeId'] as int?,
      models: _igm2snhz.Protocol().deserialize<List<_i8us82b8.AskModelStat>>(
        jsonSerialization['models'],
      ),
    );
  }

  List<_ioy8iwam.AskAdminSession> items;

  /// Cursor for the next page; null on the last page.
  DateTime? nextBeforeActiveAt;

  int? nextBeforeId;

  /// Over the whole filtered range, not only this page.
  List<_i8us82b8.AskModelStat> models;

  /// Returns a shallow copy of this [AskAdminPage]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  AskAdminPage copyWith({
    List<_ioy8iwam.AskAdminSession>? items,
    DateTime? nextBeforeActiveAt,
    int? nextBeforeId,
    List<_i8us82b8.AskModelStat>? models,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AskAdminPage',
      'items': items.toJson(valueToJson: (v) => v.toJson()),
      if (nextBeforeActiveAt != null)
        'nextBeforeActiveAt': nextBeforeActiveAt?.toJson(),
      if (nextBeforeId != null) 'nextBeforeId': nextBeforeId,
      'models': models.toJson(valueToJson: (v) => v.toJson()),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'AskAdminPage',
      'items': items.toJson(valueToJson: (v) => v.toJsonForProtocol()),
      if (nextBeforeActiveAt != null)
        'nextBeforeActiveAt': nextBeforeActiveAt?.toJson(),
      if (nextBeforeId != null) 'nextBeforeId': nextBeforeId,
      'models': models.toJson(valueToJson: (v) => v.toJsonForProtocol()),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _AskAdminPageImpl extends AskAdminPage {
  _AskAdminPageImpl({
    required List<_ioy8iwam.AskAdminSession> items,
    DateTime? nextBeforeActiveAt,
    int? nextBeforeId,
    required List<_i8us82b8.AskModelStat> models,
  }) : super._(
         items: items,
         nextBeforeActiveAt: nextBeforeActiveAt,
         nextBeforeId: nextBeforeId,
         models: models,
       );

  /// Returns a shallow copy of this [AskAdminPage]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  AskAdminPage copyWith({
    List<_ioy8iwam.AskAdminSession>? items,
    Object? nextBeforeActiveAt = _Undefined,
    Object? nextBeforeId = _Undefined,
    List<_i8us82b8.AskModelStat>? models,
  }) {
    return AskAdminPage(
      items: items ?? this.items.map((e0) => e0.copyWith()).toList(),
      nextBeforeActiveAt: nextBeforeActiveAt is DateTime?
          ? nextBeforeActiveAt
          : this.nextBeforeActiveAt,
      nextBeforeId: nextBeforeId is int? ? nextBeforeId : this.nextBeforeId,
      models: models ?? this.models.map((e0) => e0.copyWith()).toList(),
    );
  }
}
