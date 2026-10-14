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

/// A searchable chunk of a document with its embedding.
abstract class DocChunk
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  DocChunk._({
    this.id,
    required this.documentId,
    this.projectId,
    required this.ownerId,
    required this.page,
    required this.ordinal,
    required this.text,
    required this.contentHash,
    required this.embedding,
  });

  factory DocChunk({
    int? id,
    required int documentId,
    int? projectId,
    required _isc.UuidValue ownerId,
    required int page,
    required int ordinal,
    required String text,
    required String contentHash,
    required _isc.Vector embedding,
  }) = _DocChunkImpl;

  factory DocChunk.fromJson(Map<String, dynamic> jsonSerialization) {
    return DocChunk(
      id: jsonSerialization['id'] as int?,
      documentId: jsonSerialization['documentId'] as int,
      projectId: jsonSerialization['projectId'] as int?,
      ownerId: _isc.UuidValueJsonExtension.fromJson(
        jsonSerialization['ownerId'],
      ),
      page: jsonSerialization['page'] as int,
      ordinal: jsonSerialization['ordinal'] as int,
      text: jsonSerialization['text'] as String,
      contentHash: jsonSerialization['contentHash'] as String,
      embedding: _isc.VectorJsonExtension.fromJson(
        jsonSerialization['embedding'],
      ),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  int documentId;

  /// Denormalized for ACL filtering in the same query as vector search.
  int? projectId;

  _isc.UuidValue ownerId;

  int page;

  int ordinal;

  String text;

  String contentHash;

  _isc.Vector embedding;

  /// Returns a shallow copy of this [DocChunk]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  DocChunk copyWith({
    int? id,
    int? documentId,
    int? projectId,
    _isc.UuidValue? ownerId,
    int? page,
    int? ordinal,
    String? text,
    String? contentHash,
    _isc.Vector? embedding,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DocChunk',
      if (id != null) 'id': id,
      'documentId': documentId,
      if (projectId != null) 'projectId': projectId,
      'ownerId': ownerId.toJson(),
      'page': page,
      'ordinal': ordinal,
      'text': text,
      'contentHash': contentHash,
      'embedding': embedding.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'DocChunk',
      if (id != null) 'id': id,
      'documentId': documentId,
      if (projectId != null) 'projectId': projectId,
      'ownerId': ownerId.toJson(),
      'page': page,
      'ordinal': ordinal,
      'text': text,
      'contentHash': contentHash,
      'embedding': embedding.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DocChunkImpl extends DocChunk {
  _DocChunkImpl({
    int? id,
    required int documentId,
    int? projectId,
    required _isc.UuidValue ownerId,
    required int page,
    required int ordinal,
    required String text,
    required String contentHash,
    required _isc.Vector embedding,
  }) : super._(
         id: id,
         documentId: documentId,
         projectId: projectId,
         ownerId: ownerId,
         page: page,
         ordinal: ordinal,
         text: text,
         contentHash: contentHash,
         embedding: embedding,
       );

  /// Returns a shallow copy of this [DocChunk]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  DocChunk copyWith({
    Object? id = _Undefined,
    int? documentId,
    Object? projectId = _Undefined,
    _isc.UuidValue? ownerId,
    int? page,
    int? ordinal,
    String? text,
    String? contentHash,
    _isc.Vector? embedding,
  }) {
    return DocChunk(
      id: id is int? ? id : this.id,
      documentId: documentId ?? this.documentId,
      projectId: projectId is int? ? projectId : this.projectId,
      ownerId: ownerId ?? this.ownerId,
      page: page ?? this.page,
      ordinal: ordinal ?? this.ordinal,
      text: text ?? this.text,
      contentHash: contentHash ?? this.contentHash,
      embedding: embedding ?? this.embedding.clone(),
    );
  }
}
