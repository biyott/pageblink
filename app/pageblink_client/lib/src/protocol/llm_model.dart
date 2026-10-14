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

/// A model the app can choose for answers. Served by ModelEndpoint.list.
abstract class LlmModel
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  LlmModel._({
    required this.id,
    required this.label,
    required this.provider,
    required this.free,
    this.note,
  });

  factory LlmModel({
    required String id,
    required String label,
    required String provider,
    required bool free,
    String? note,
  }) = _LlmModelImpl;

  factory LlmModel.fromJson(Map<String, dynamic> jsonSerialization) {
    return LlmModel(
      id: jsonSerialization['id'] as String,
      label: jsonSerialization['label'] as String,
      provider: jsonSerialization['provider'] as String,
      free: _isc.BoolJsonExtension.fromJson(jsonSerialization['free']),
      note: jsonSerialization['note'] as String?,
    );
  }

  /// Provider model id, e.g. google/gemma-4-26b-a4b-it:free
  String id;

  String label;

  /// openrouter | gemini | anthropic
  String provider;

  bool free;

  /// Short note shown in the picker (speed, quality, privacy).
  String? note;

  /// Returns a shallow copy of this [LlmModel]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  LlmModel copyWith({
    String? id,
    String? label,
    String? provider,
    bool? free,
    String? note,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'LlmModel',
      'id': id,
      'label': label,
      'provider': provider,
      'free': free,
      if (note != null) 'note': note,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'LlmModel',
      'id': id,
      'label': label,
      'provider': provider,
      'free': free,
      if (note != null) 'note': note,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _LlmModelImpl extends LlmModel {
  _LlmModelImpl({
    required String id,
    required String label,
    required String provider,
    required bool free,
    String? note,
  }) : super._(
         id: id,
         label: label,
         provider: provider,
         free: free,
         note: note,
       );

  /// Returns a shallow copy of this [LlmModel]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  LlmModel copyWith({
    String? id,
    String? label,
    String? provider,
    bool? free,
    Object? note = _Undefined,
  }) {
    return LlmModel(
      id: id ?? this.id,
      label: label ?? this.label,
      provider: provider ?? this.provider,
      free: free ?? this.free,
      note: note is String? ? note : this.note,
    );
  }
}
