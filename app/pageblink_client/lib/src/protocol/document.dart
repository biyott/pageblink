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

/// An uploaded document. projectId null means a personal cloud document.
abstract class Document
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  Document._({
    this.id,
    required this.ownerId,
    this.projectId,
    required this.title,
    required this.contentHash,
    required this.version,
    required this.pageCount,
    this.storagePath,
    required this.status,
    required this.embeddingModel,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Document({
    int? id,
    required _isc.UuidValue ownerId,
    int? projectId,
    required String title,
    required String contentHash,
    required int version,
    required int pageCount,
    String? storagePath,
    required String status,
    required String embeddingModel,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _DocumentImpl;

  factory Document.fromJson(Map<String, dynamic> jsonSerialization) {
    return Document(
      id: jsonSerialization['id'] as int?,
      ownerId: _isc.UuidValueJsonExtension.fromJson(
        jsonSerialization['ownerId'],
      ),
      projectId: jsonSerialization['projectId'] as int?,
      title: jsonSerialization['title'] as String,
      contentHash: jsonSerialization['contentHash'] as String,
      version: jsonSerialization['version'] as int,
      pageCount: jsonSerialization['pageCount'] as int,
      storagePath: jsonSerialization['storagePath'] as String?,
      status: jsonSerialization['status'] as String,
      embeddingModel: jsonSerialization['embeddingModel'] as String,
      createdAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      updatedAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['updatedAt'],
      ),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  _isc.UuidValue ownerId;

  int? projectId;

  String title;

  String contentHash;

  int version;

  int pageCount;

  String? storagePath;

  /// uploaded | indexing | ready | failed
  String status;

  String embeddingModel;

  DateTime createdAt;

  DateTime updatedAt;

  /// Returns a shallow copy of this [Document]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  Document copyWith({
    int? id,
    _isc.UuidValue? ownerId,
    int? projectId,
    String? title,
    String? contentHash,
    int? version,
    int? pageCount,
    String? storagePath,
    String? status,
    String? embeddingModel,
    DateTime? createdAt,
    DateTime? updatedAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Document',
      if (id != null) 'id': id,
      'ownerId': ownerId.toJson(),
      if (projectId != null) 'projectId': projectId,
      'title': title,
      'contentHash': contentHash,
      'version': version,
      'pageCount': pageCount,
      if (storagePath != null) 'storagePath': storagePath,
      'status': status,
      'embeddingModel': embeddingModel,
      'createdAt': createdAt.toJson(),
      'updatedAt': updatedAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'Document',
      if (id != null) 'id': id,
      'ownerId': ownerId.toJson(),
      if (projectId != null) 'projectId': projectId,
      'title': title,
      'contentHash': contentHash,
      'version': version,
      'pageCount': pageCount,
      if (storagePath != null) 'storagePath': storagePath,
      'status': status,
      'embeddingModel': embeddingModel,
      'createdAt': createdAt.toJson(),
      'updatedAt': updatedAt.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DocumentImpl extends Document {
  _DocumentImpl({
    int? id,
    required _isc.UuidValue ownerId,
    int? projectId,
    required String title,
    required String contentHash,
    required int version,
    required int pageCount,
    String? storagePath,
    required String status,
    required String embeddingModel,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : super._(
         id: id,
         ownerId: ownerId,
         projectId: projectId,
         title: title,
         contentHash: contentHash,
         version: version,
         pageCount: pageCount,
         storagePath: storagePath,
         status: status,
         embeddingModel: embeddingModel,
         createdAt: createdAt,
         updatedAt: updatedAt,
       );

  /// Returns a shallow copy of this [Document]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  Document copyWith({
    Object? id = _Undefined,
    _isc.UuidValue? ownerId,
    Object? projectId = _Undefined,
    String? title,
    String? contentHash,
    int? version,
    int? pageCount,
    Object? storagePath = _Undefined,
    String? status,
    String? embeddingModel,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Document(
      id: id is int? ? id : this.id,
      ownerId: ownerId ?? this.ownerId,
      projectId: projectId is int? ? projectId : this.projectId,
      title: title ?? this.title,
      contentHash: contentHash ?? this.contentHash,
      version: version ?? this.version,
      pageCount: pageCount ?? this.pageCount,
      storagePath: storagePath is String? ? storagePath : this.storagePath,
      status: status ?? this.status,
      embeddingModel: embeddingModel ?? this.embeddingModel,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
