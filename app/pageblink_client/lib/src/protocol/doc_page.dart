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

/// Raw text of one page (PDF) or the whole note, kept so failed or stale
/// documents can be re-indexed without re-uploading.
abstract class DocPage
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  DocPage._({
    this.id,
    required this.documentId,
    required this.page,
    required this.text,
    this.source,
  });

  factory DocPage({
    int? id,
    required int documentId,
    required int page,
    required String text,
    String? source,
  }) = _DocPageImpl;

  factory DocPage.fromJson(Map<String, dynamic> jsonSerialization) {
    return DocPage(
      id: jsonSerialization['id'] as int?,
      documentId: jsonSerialization['documentId'] as int,
      page: jsonSerialization['page'] as int,
      text: jsonSerialization['text'] as String,
      source: jsonSerialization['source'] as String?,
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  int documentId;

  int page;

  String text;

  /// Where [text] came from when it was not read from the PDF text layer:
  /// form (form field values) | ocr (recognized on the client). Null = the
  /// original text. Kept through re-indexing and re-uploads.
  String? source;

  /// Returns a shallow copy of this [DocPage]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  DocPage copyWith({
    int? id,
    int? documentId,
    int? page,
    String? text,
    String? source,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DocPage',
      if (id != null) 'id': id,
      'documentId': documentId,
      'page': page,
      'text': text,
      if (source != null) 'source': source,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'DocPage',
      if (id != null) 'id': id,
      'documentId': documentId,
      'page': page,
      'text': text,
      if (source != null) 'source': source,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DocPageImpl extends DocPage {
  _DocPageImpl({
    int? id,
    required int documentId,
    required int page,
    required String text,
    String? source,
  }) : super._(
         id: id,
         documentId: documentId,
         page: page,
         text: text,
         source: source,
       );

  /// Returns a shallow copy of this [DocPage]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  DocPage copyWith({
    Object? id = _Undefined,
    int? documentId,
    int? page,
    String? text,
    Object? source = _Undefined,
  }) {
    return DocPage(
      id: id is int? ? id : this.id,
      documentId: documentId ?? this.documentId,
      page: page ?? this.page,
      text: text ?? this.text,
      source: source is String? ? source : this.source,
    );
  }
}
