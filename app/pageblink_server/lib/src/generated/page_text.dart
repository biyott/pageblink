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

/// Text of one PDF page, extracted on the client.
abstract class PageText
    implements _is.SerializableModel, _is.ProtocolSerialization {
  PageText._({
    required this.page,
    required this.text,
    this.source,
  });

  factory PageText({
    required int page,
    required String text,
    String? source,
  }) = _PageTextImpl;

  factory PageText.fromJson(Map<String, dynamic> jsonSerialization) {
    return PageText(
      page: jsonSerialization['page'] as int,
      text: jsonSerialization['text'] as String,
      source: jsonSerialization['source'] as String?,
    );
  }

  int page;

  String text;

  /// form | ocr when the client recovered this page's text; null = original.
  /// Older clients omit it. Anything else is stored as null.
  String? source;

  /// Returns a shallow copy of this [PageText]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  PageText copyWith({
    int? page,
    String? text,
    String? source,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'PageText',
      'page': page,
      'text': text,
      if (source != null) 'source': source,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'PageText',
      'page': page,
      'text': text,
      if (source != null) 'source': source,
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _PageTextImpl extends PageText {
  _PageTextImpl({
    required int page,
    required String text,
    String? source,
  }) : super._(
         page: page,
         text: text,
         source: source,
       );

  /// Returns a shallow copy of this [PageText]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  PageText copyWith({
    int? page,
    String? text,
    Object? source = _Undefined,
  }) {
    return PageText(
      page: page ?? this.page,
      text: text ?? this.text,
      source: source is String? ? source : this.source,
    );
  }
}
