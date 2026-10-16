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

/// A note (markdown) or an uploaded PDF. projectId null means personal.
abstract class Document
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  Document._({
    this.id,
    required this.ownerId,
    this.projectId,
    String? kind,
    required this.title,
    this.body,
    required this.contentHash,
    required this.version,
    required this.pageCount,
    this.storagePath,
    required this.status,
    this.preview,
    this.lastError,
    required this.embeddingModel,
    this.colorIndex,
    required this.createdAt,
    required this.updatedAt,
  }) : kind = kind ?? 'pdf';

  factory Document({
    int? id,
    required _isc.UuidValue ownerId,
    int? projectId,
    String? kind,
    required String title,
    String? body,
    required String contentHash,
    required int version,
    required int pageCount,
    String? storagePath,
    required String status,
    String? preview,
    String? lastError,
    required String embeddingModel,
    int? colorIndex,
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
      kind: jsonSerialization['kind'] as String?,
      title: jsonSerialization['title'] as String,
      body: jsonSerialization['body'] as String?,
      contentHash: jsonSerialization['contentHash'] as String,
      version: jsonSerialization['version'] as int,
      pageCount: jsonSerialization['pageCount'] as int,
      storagePath: jsonSerialization['storagePath'] as String?,
      status: jsonSerialization['status'] as String,
      preview: jsonSerialization['preview'] as String?,
      lastError: jsonSerialization['lastError'] as String?,
      embeddingModel: jsonSerialization['embeddingModel'] as String,
      colorIndex: jsonSerialization['colorIndex'] as int?,
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

  /// note | pdf
  String kind;

  String title;

  /// Markdown body for notes; null for PDFs.
  String? body;

  String contentHash;

  int version;

  int pageCount;

  String? storagePath;

  /// uploaded | indexing | ready | failed
  String status;

  /// PDF card text: the start of the first page with real text (about 240
  /// characters). null = not computed yet, '' = tried, nothing readable. Notes: null.
  String? preview;

  /// Why the last indexing failed (shown in the app, cleared on success).
  String? lastError;

  String embeddingModel;

  /// Chosen note card color: index into the app palette (0..7 solid, 8 rainbow), null = auto.
  int? colorIndex;

  DateTime createdAt;

  DateTime updatedAt;

  /// Returns a shallow copy of this [Document]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  Document copyWith({
    int? id,
    _isc.UuidValue? ownerId,
    int? projectId,
    String? kind,
    String? title,
    String? body,
    String? contentHash,
    int? version,
    int? pageCount,
    String? storagePath,
    String? status,
    String? preview,
    String? lastError,
    String? embeddingModel,
    int? colorIndex,
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
      'kind': kind,
      'title': title,
      if (body != null) 'body': body,
      'contentHash': contentHash,
      'version': version,
      'pageCount': pageCount,
      if (storagePath != null) 'storagePath': storagePath,
      'status': status,
      if (preview != null) 'preview': preview,
      if (lastError != null) 'lastError': lastError,
      'embeddingModel': embeddingModel,
      if (colorIndex != null) 'colorIndex': colorIndex,
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
      'kind': kind,
      'title': title,
      if (body != null) 'body': body,
      'contentHash': contentHash,
      'version': version,
      'pageCount': pageCount,
      if (storagePath != null) 'storagePath': storagePath,
      'status': status,
      if (preview != null) 'preview': preview,
      if (lastError != null) 'lastError': lastError,
      'embeddingModel': embeddingModel,
      if (colorIndex != null) 'colorIndex': colorIndex,
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
    String? kind,
    required String title,
    String? body,
    required String contentHash,
    required int version,
    required int pageCount,
    String? storagePath,
    required String status,
    String? preview,
    String? lastError,
    required String embeddingModel,
    int? colorIndex,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : super._(
         id: id,
         ownerId: ownerId,
         projectId: projectId,
         kind: kind,
         title: title,
         body: body,
         contentHash: contentHash,
         version: version,
         pageCount: pageCount,
         storagePath: storagePath,
         status: status,
         preview: preview,
         lastError: lastError,
         embeddingModel: embeddingModel,
         colorIndex: colorIndex,
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
    String? kind,
    String? title,
    Object? body = _Undefined,
    String? contentHash,
    int? version,
    int? pageCount,
    Object? storagePath = _Undefined,
    String? status,
    Object? preview = _Undefined,
    Object? lastError = _Undefined,
    String? embeddingModel,
    Object? colorIndex = _Undefined,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Document(
      id: id is int? ? id : this.id,
      ownerId: ownerId ?? this.ownerId,
      projectId: projectId is int? ? projectId : this.projectId,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      body: body is String? ? body : this.body,
      contentHash: contentHash ?? this.contentHash,
      version: version ?? this.version,
      pageCount: pageCount ?? this.pageCount,
      storagePath: storagePath is String? ? storagePath : this.storagePath,
      status: status ?? this.status,
      preview: preview is String? ? preview : this.preview,
      lastError: lastError is String? ? lastError : this.lastError,
      embeddingModel: embeddingModel ?? this.embeddingModel,
      colorIndex: colorIndex is int? ? colorIndex : this.colorIndex,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
