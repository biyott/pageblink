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

/// Example questions for the sample content the caller holds (research 028).
/// Not stored: the server builds it from its sample packs.
abstract class SampleHint
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  SampleHint._({
    required this.packId,
    required this.locale,
    required this.questions,
  });

  factory SampleHint({
    required String packId,
    required String locale,
    required List<String> questions,
  }) = _SampleHintImpl;

  factory SampleHint.fromJson(Map<String, dynamic> jsonSerialization) {
    return SampleHint(
      packId: jsonSerialization['packId'] as String,
      locale: jsonSerialization['locale'] as String,
      questions: _igm2snhz.Protocol().deserialize<List<String>>(
        jsonSerialization['questions'],
      ),
    );
  }

  /// Which pack the questions belong to (`signup-ko`, `demo-en`, ...).
  String packId;

  /// Language of the questions: the language of the sample's content.
  String locale;

  /// Questions the sample content answers, in display order.
  List<String> questions;

  /// Returns a shallow copy of this [SampleHint]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  SampleHint copyWith({
    String? packId,
    String? locale,
    List<String>? questions,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SampleHint',
      'packId': packId,
      'locale': locale,
      'questions': questions.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'SampleHint',
      'packId': packId,
      'locale': locale,
      'questions': questions.toJson(),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _SampleHintImpl extends SampleHint {
  _SampleHintImpl({
    required String packId,
    required String locale,
    required List<String> questions,
  }) : super._(
         packId: packId,
         locale: locale,
         questions: questions,
       );

  /// Returns a shallow copy of this [SampleHint]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  SampleHint copyWith({
    String? packId,
    String? locale,
    List<String>? questions,
  }) {
    return SampleHint(
      packId: packId ?? this.packId,
      locale: locale ?? this.locale,
      questions: questions ?? this.questions.map((e0) => e0).toList(),
    );
  }
}
