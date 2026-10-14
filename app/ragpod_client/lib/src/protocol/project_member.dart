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

/// Membership of a user in a project. role: owner | editor | viewer
abstract class ProjectMember
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  ProjectMember._({
    this.id,
    required this.projectId,
    required this.userId,
    required this.role,
  });

  factory ProjectMember({
    int? id,
    required int projectId,
    required _isc.UuidValue userId,
    required String role,
  }) = _ProjectMemberImpl;

  factory ProjectMember.fromJson(Map<String, dynamic> jsonSerialization) {
    return ProjectMember(
      id: jsonSerialization['id'] as int?,
      projectId: jsonSerialization['projectId'] as int,
      userId: _isc.UuidValueJsonExtension.fromJson(jsonSerialization['userId']),
      role: jsonSerialization['role'] as String,
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  int projectId;

  _isc.UuidValue userId;

  String role;

  /// Returns a shallow copy of this [ProjectMember]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  ProjectMember copyWith({
    int? id,
    int? projectId,
    _isc.UuidValue? userId,
    String? role,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ProjectMember',
      if (id != null) 'id': id,
      'projectId': projectId,
      'userId': userId.toJson(),
      'role': role,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'ProjectMember',
      if (id != null) 'id': id,
      'projectId': projectId,
      'userId': userId.toJson(),
      'role': role,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _ProjectMemberImpl extends ProjectMember {
  _ProjectMemberImpl({
    int? id,
    required int projectId,
    required _isc.UuidValue userId,
    required String role,
  }) : super._(
         id: id,
         projectId: projectId,
         userId: userId,
         role: role,
       );

  /// Returns a shallow copy of this [ProjectMember]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  ProjectMember copyWith({
    Object? id = _Undefined,
    int? projectId,
    _isc.UuidValue? userId,
    String? role,
  }) {
    return ProjectMember(
      id: id is int? ? id : this.id,
      projectId: projectId ?? this.projectId,
      userId: userId ?? this.userId,
      role: role ?? this.role,
    );
  }
}
