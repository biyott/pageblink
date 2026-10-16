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

/// Answers per model over the filtered range of the admin list.
abstract class AskModelStat
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  AskModelStat._({
    required this.modelId,
    required this.answers,
    required this.fallbacks,
  });

  factory AskModelStat({
    required String modelId,
    required int answers,
    required int fallbacks,
  }) = _AskModelStatImpl;

  factory AskModelStat.fromJson(Map<String, dynamic> jsonSerialization) {
    return AskModelStat(
      modelId: jsonSerialization['modelId'] as String,
      answers: jsonSerialization['answers'] as int,
      fallbacks: jsonSerialization['fallbacks'] as int,
    );
  }

  String modelId;

  int answers;

  /// Of those, answers given by another model than the one asked for.
  int fallbacks;

  /// Returns a shallow copy of this [AskModelStat]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  AskModelStat copyWith({
    String? modelId,
    int? answers,
    int? fallbacks,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AskModelStat',
      'modelId': modelId,
      'answers': answers,
      'fallbacks': fallbacks,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'AskModelStat',
      'modelId': modelId,
      'answers': answers,
      'fallbacks': fallbacks,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _AskModelStatImpl extends AskModelStat {
  _AskModelStatImpl({
    required String modelId,
    required int answers,
    required int fallbacks,
  }) : super._(
         modelId: modelId,
         answers: answers,
         fallbacks: fallbacks,
       );

  /// Returns a shallow copy of this [AskModelStat]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  AskModelStat copyWith({
    String? modelId,
    int? answers,
    int? fallbacks,
  }) {
    return AskModelStat(
      modelId: modelId ?? this.modelId,
      answers: answers ?? this.answers,
      fallbacks: fallbacks ?? this.fallbacks,
    );
  }
}
