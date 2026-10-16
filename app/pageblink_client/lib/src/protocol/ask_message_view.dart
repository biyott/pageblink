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
import 'package:pageblink_client/src/protocol/protocol.dart' as _igm2snhz;
import 'package:serverpod_client/serverpod_client.dart' as _isc;
import 'citation.dart' as _i7jy3rkv;

/// A stored question and answer, as the app shows it.
abstract class AskMessageView
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  AskMessageView._({
    required this.seq,
    required this.question,
    required this.answer,
    required this.status,
    this.errorCode,
    required this.citations,
    this.modelId,
    bool? fallback,
    required this.createdAt,
  }) : fallback = fallback ?? false;

  factory AskMessageView({
    required int seq,
    required String question,
    required String answer,
    required String status,
    String? errorCode,
    required List<_i7jy3rkv.Citation> citations,
    String? modelId,
    bool? fallback,
    required DateTime createdAt,
  }) = _AskMessageViewImpl;

  factory AskMessageView.fromJson(Map<String, dynamic> jsonSerialization) {
    return AskMessageView(
      seq: jsonSerialization['seq'] as int,
      question: jsonSerialization['question'] as String,
      answer: jsonSerialization['answer'] as String,
      status: jsonSerialization['status'] as String,
      errorCode: jsonSerialization['errorCode'] as String?,
      citations: _igm2snhz.Protocol().deserialize<List<_i7jy3rkv.Citation>>(
        jsonSerialization['citations'],
      ),
      modelId: jsonSerialization['modelId'] as String?,
      fallback: jsonSerialization['fallback'] == null
          ? null
          : _isc.BoolJsonExtension.fromJson(jsonSerialization['fallback']),
      createdAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
    );
  }

  int seq;

  String question;

  String answer;

  /// streaming | done | error | interrupted
  String status;

  String? errorCode;

  List<_i7jy3rkv.Citation> citations;

  String? modelId;

  bool fallback;

  DateTime createdAt;

  /// Returns a shallow copy of this [AskMessageView]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  AskMessageView copyWith({
    int? seq,
    String? question,
    String? answer,
    String? status,
    String? errorCode,
    List<_i7jy3rkv.Citation>? citations,
    String? modelId,
    bool? fallback,
    DateTime? createdAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AskMessageView',
      'seq': seq,
      'question': question,
      'answer': answer,
      'status': status,
      if (errorCode != null) 'errorCode': errorCode,
      'citations': citations.toJson(valueToJson: (v) => v.toJson()),
      if (modelId != null) 'modelId': modelId,
      'fallback': fallback,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'AskMessageView',
      'seq': seq,
      'question': question,
      'answer': answer,
      'status': status,
      if (errorCode != null) 'errorCode': errorCode,
      'citations': citations.toJson(valueToJson: (v) => v.toJsonForProtocol()),
      if (modelId != null) 'modelId': modelId,
      'fallback': fallback,
      'createdAt': createdAt.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _AskMessageViewImpl extends AskMessageView {
  _AskMessageViewImpl({
    required int seq,
    required String question,
    required String answer,
    required String status,
    String? errorCode,
    required List<_i7jy3rkv.Citation> citations,
    String? modelId,
    bool? fallback,
    required DateTime createdAt,
  }) : super._(
         seq: seq,
         question: question,
         answer: answer,
         status: status,
         errorCode: errorCode,
         citations: citations,
         modelId: modelId,
         fallback: fallback,
         createdAt: createdAt,
       );

  /// Returns a shallow copy of this [AskMessageView]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  AskMessageView copyWith({
    int? seq,
    String? question,
    String? answer,
    String? status,
    Object? errorCode = _Undefined,
    List<_i7jy3rkv.Citation>? citations,
    Object? modelId = _Undefined,
    bool? fallback,
    DateTime? createdAt,
  }) {
    return AskMessageView(
      seq: seq ?? this.seq,
      question: question ?? this.question,
      answer: answer ?? this.answer,
      status: status ?? this.status,
      errorCode: errorCode is String? ? errorCode : this.errorCode,
      citations:
          citations ?? this.citations.map((e0) => e0.copyWith()).toList(),
      modelId: modelId is String? ? modelId : this.modelId,
      fallback: fallback ?? this.fallback,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
