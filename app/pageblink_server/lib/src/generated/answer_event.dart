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

/// One event in a streamed answer.
/// type: session | token | citation | model | done | error
/// (`session` comes first when history is on; older apps ignore it.)
abstract class AnswerEvent
    implements _is.SerializableModel, _is.ProtocolSerialization {
  AnswerEvent._({
    required this.type,
    this.text,
    this.citation,
    this.sessionId,
    this.questionCount,
    this.questionLimit,
  });

  factory AnswerEvent({
    required String type,
    String? text,
    _i7jy3rkv.Citation? citation,
    int? sessionId,
    int? questionCount,
    int? questionLimit,
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
      sessionId: jsonSerialization['sessionId'] as int?,
      questionCount: jsonSerialization['questionCount'] as int?,
      questionLimit: jsonSerialization['questionLimit'] as int?,
    );
  }

  String type;

  String? text;

  _i7jy3rkv.Citation? citation;

  /// session event: the conversation id and its counter.
  int? sessionId;

  int? questionCount;

  int? questionLimit;

  /// Returns a shallow copy of this [AnswerEvent]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  AnswerEvent copyWith({
    String? type,
    String? text,
    _i7jy3rkv.Citation? citation,
    int? sessionId,
    int? questionCount,
    int? questionLimit,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AnswerEvent',
      'type': type,
      if (text != null) 'text': text,
      if (citation != null) 'citation': citation?.toJson(),
      if (sessionId != null) 'sessionId': sessionId,
      if (questionCount != null) 'questionCount': questionCount,
      if (questionLimit != null) 'questionLimit': questionLimit,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'AnswerEvent',
      'type': type,
      if (text != null) 'text': text,
      if (citation != null) 'citation': citation?.toJsonForProtocol(),
      if (sessionId != null) 'sessionId': sessionId,
      if (questionCount != null) 'questionCount': questionCount,
      if (questionLimit != null) 'questionLimit': questionLimit,
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
    int? sessionId,
    int? questionCount,
    int? questionLimit,
  }) : super._(
         type: type,
         text: text,
         citation: citation,
         sessionId: sessionId,
         questionCount: questionCount,
         questionLimit: questionLimit,
       );

  /// Returns a shallow copy of this [AnswerEvent]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  AnswerEvent copyWith({
    String? type,
    Object? text = _Undefined,
    Object? citation = _Undefined,
    Object? sessionId = _Undefined,
    Object? questionCount = _Undefined,
    Object? questionLimit = _Undefined,
  }) {
    return AnswerEvent(
      type: type ?? this.type,
      text: text is String? ? text : this.text,
      citation: citation is _i7jy3rkv.Citation?
          ? citation
          : this.citation?.copyWith(),
      sessionId: sessionId is int? ? sessionId : this.sessionId,
      questionCount: questionCount is int? ? questionCount : this.questionCount,
      questionLimit: questionLimit is int? ? questionLimit : this.questionLimit,
    );
  }
}
