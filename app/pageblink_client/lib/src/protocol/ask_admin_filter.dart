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

/// Filter and page cursor of the admin conversation list.
abstract class AskAdminFilter
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  AskAdminFilter._({
    this.userId,
    this.from,
    this.to,
    this.beforeActiveAt,
    this.beforeId,
    this.pageSize,
  });

  factory AskAdminFilter({
    String? userId,
    DateTime? from,
    DateTime? to,
    DateTime? beforeActiveAt,
    int? beforeId,
    int? pageSize,
  }) = _AskAdminFilterImpl;

  factory AskAdminFilter.fromJson(Map<String, dynamic> jsonSerialization) {
    return AskAdminFilter(
      userId: jsonSerialization['userId'] as String?,
      from: jsonSerialization['from'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(jsonSerialization['from']),
      to: jsonSerialization['to'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(jsonSerialization['to']),
      beforeActiveAt: jsonSerialization['beforeActiveAt'] == null
          ? null
          : _isc.DateTimeJsonExtension.fromJson(
              jsonSerialization['beforeActiveAt'],
            ),
      beforeId: jsonSerialization['beforeId'] as int?,
      pageSize: jsonSerialization['pageSize'] as int?,
    );
  }

  String? userId;

  /// Last activity from / to (inclusive).
  DateTime? from;

  DateTime? to;

  /// Keyset cursor: the previous page's last item.
  DateTime? beforeActiveAt;

  int? beforeId;

  /// 1 to 50, default 20.
  int? pageSize;

  /// Returns a shallow copy of this [AskAdminFilter]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  AskAdminFilter copyWith({
    String? userId,
    DateTime? from,
    DateTime? to,
    DateTime? beforeActiveAt,
    int? beforeId,
    int? pageSize,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AskAdminFilter',
      if (userId != null) 'userId': userId,
      if (from != null) 'from': from?.toJson(),
      if (to != null) 'to': to?.toJson(),
      if (beforeActiveAt != null) 'beforeActiveAt': beforeActiveAt?.toJson(),
      if (beforeId != null) 'beforeId': beforeId,
      if (pageSize != null) 'pageSize': pageSize,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'AskAdminFilter',
      if (userId != null) 'userId': userId,
      if (from != null) 'from': from?.toJson(),
      if (to != null) 'to': to?.toJson(),
      if (beforeActiveAt != null) 'beforeActiveAt': beforeActiveAt?.toJson(),
      if (beforeId != null) 'beforeId': beforeId,
      if (pageSize != null) 'pageSize': pageSize,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _AskAdminFilterImpl extends AskAdminFilter {
  _AskAdminFilterImpl({
    String? userId,
    DateTime? from,
    DateTime? to,
    DateTime? beforeActiveAt,
    int? beforeId,
    int? pageSize,
  }) : super._(
         userId: userId,
         from: from,
         to: to,
         beforeActiveAt: beforeActiveAt,
         beforeId: beforeId,
         pageSize: pageSize,
       );

  /// Returns a shallow copy of this [AskAdminFilter]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  AskAdminFilter copyWith({
    Object? userId = _Undefined,
    Object? from = _Undefined,
    Object? to = _Undefined,
    Object? beforeActiveAt = _Undefined,
    Object? beforeId = _Undefined,
    Object? pageSize = _Undefined,
  }) {
    return AskAdminFilter(
      userId: userId is String? ? userId : this.userId,
      from: from is DateTime? ? from : this.from,
      to: to is DateTime? ? to : this.to,
      beforeActiveAt: beforeActiveAt is DateTime?
          ? beforeActiveAt
          : this.beforeActiveAt,
      beforeId: beforeId is int? ? beforeId : this.beforeId,
      pageSize: pageSize is int? ? pageSize : this.pageSize,
    );
  }
}
