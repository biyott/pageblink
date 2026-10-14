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

/// Text of one PDF page, extracted on the client.
abstract class PageText
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  PageText._({
    required this.page,
    required this.text,
  });

  factory PageText({
    required int page,
    required String text,
  }) = _PageTextImpl;

  factory PageText.fromJson(Map<String, dynamic> jsonSerialization) {
    return PageText(
      page: jsonSerialization['page'] as int,
      text: jsonSerialization['text'] as String,
    );
  }

  int page;

  String text;

  /// Returns a shallow copy of this [PageText]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  PageText copyWith({
    int? page,
    String? text,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'PageText',
      'page': page,
      'text': text,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'PageText',
      'page': page,
      'text': text,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _PageTextImpl extends PageText {
  _PageTextImpl({
    required int page,
    required String text,
  }) : super._(
         page: page,
         text: text,
       );

  /// Returns a shallow copy of this [PageText]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  PageText copyWith({
    int? page,
    String? text,
  }) {
    return PageText(
      page: page ?? this.page,
      text: text ?? this.text,
    );
  }
}
