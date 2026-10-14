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

/// A source passage backing part of an answer.
abstract class Citation
    implements _is.SerializableModel, _is.ProtocolSerialization {
  Citation._({
    required this.index,
    required this.documentId,
    required this.documentTitle,
    String? kind,
    required this.page,
    required this.quote,
  }) : kind = kind ?? 'pdf';

  factory Citation({
    required int index,
    required int documentId,
    required String documentTitle,
    String? kind,
    required int page,
    required String quote,
  }) = _CitationImpl;

  factory Citation.fromJson(Map<String, dynamic> jsonSerialization) {
    return Citation(
      index: jsonSerialization['index'] as int,
      documentId: jsonSerialization['documentId'] as int,
      documentTitle: jsonSerialization['documentTitle'] as String,
      kind: jsonSerialization['kind'] as String?,
      page: jsonSerialization['page'] as int,
      quote: jsonSerialization['quote'] as String,
    );
  }

  int index;

  int documentId;

  String documentTitle;

  /// note | pdf — notes open in the note view, PDFs at the page.
  String kind;

  int page;

  String quote;

  /// Returns a shallow copy of this [Citation]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  Citation copyWith({
    int? index,
    int? documentId,
    String? documentTitle,
    String? kind,
    int? page,
    String? quote,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Citation',
      'index': index,
      'documentId': documentId,
      'documentTitle': documentTitle,
      'kind': kind,
      'page': page,
      'quote': quote,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'Citation',
      'index': index,
      'documentId': documentId,
      'documentTitle': documentTitle,
      'kind': kind,
      'page': page,
      'quote': quote,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _CitationImpl extends Citation {
  _CitationImpl({
    required int index,
    required int documentId,
    required String documentTitle,
    String? kind,
    required int page,
    required String quote,
  }) : super._(
         index: index,
         documentId: documentId,
         documentTitle: documentTitle,
         kind: kind,
         page: page,
         quote: quote,
       );

  /// Returns a shallow copy of this [Citation]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  Citation copyWith({
    int? index,
    int? documentId,
    String? documentTitle,
    String? kind,
    int? page,
    String? quote,
  }) {
    return Citation(
      index: index ?? this.index,
      documentId: documentId ?? this.documentId,
      documentTitle: documentTitle ?? this.documentTitle,
      kind: kind ?? this.kind,
      page: page ?? this.page,
      quote: quote ?? this.quote,
    );
  }
}
