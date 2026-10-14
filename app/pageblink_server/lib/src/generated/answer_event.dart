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
import 'package:pageblink_server/src/generated/protocol.dart' as _i897a6pi;
import 'package:serverpod/serverpod.dart' as _is;
import 'citation.dart' as _i7jy3rkv;

/// One event in a streamed answer. type: token | citation | done | error
abstract class AnswerEvent
    implements _is.SerializableModel, _is.ProtocolSerialization {
  AnswerEvent._({
    required this.type,
    this.text,
    this.citation,
  });

  factory AnswerEvent({
    required String type,
    String? text,
    _i7jy3rkv.Citation? citation,
  }) = _AnswerEventImpl;

  factory AnswerEvent.fromJson(Map<String, dynamic> jsonSerialization) {
    return AnswerEvent(
      type: jsonSerialization['type'] as String,
      text: jsonSerialization['text'] as String?,
      citation: jsonSerialization['citation'] == null
          ? null
          : _i897a6pi.Protocol().deserialize<_i7jy3rkv.Citation>(
              jsonSerialization['citation'],
            ),
    );
  }

  String type;

  String? text;

  _i7jy3rkv.Citation? citation;

  /// Returns a shallow copy of this [AnswerEvent]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  AnswerEvent copyWith({
    String? type,
    String? text,
    _i7jy3rkv.Citation? citation,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AnswerEvent',
      'type': type,
      if (text != null) 'text': text,
      if (citation != null) 'citation': citation?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'AnswerEvent',
      'type': type,
      if (text != null) 'text': text,
      if (citation != null) 'citation': citation?.toJsonForProtocol(),
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _AnswerEventImpl extends AnswerEvent {
  _AnswerEventImpl({
    required String type,
    String? text,
    _i7jy3rkv.Citation? citation,
  }) : super._(
         type: type,
         text: text,
         citation: citation,
       );

  /// Returns a shallow copy of this [AnswerEvent]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  AnswerEvent copyWith({
    String? type,
    Object? text = _Undefined,
    Object? citation = _Undefined,
  }) {
    return AnswerEvent(
      type: type ?? this.type,
      text: text is String? ? text : this.text,
      citation: citation is _i7jy3rkv.Citation?
          ? citation
          : this.citation?.copyWith(),
    );
  }
}
