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
import 'ask_session_summary.dart' as _ij6hsnla;
import 'ask_session_view.dart' as _i89or6c7;

/// What the Ask screen needs when it opens.
abstract class AskRestore
    implements _is.SerializableModel, _is.ProtocolSerialization {
  AskRestore._({
    this.current,
    required this.recent,
  });

  factory AskRestore({
    _i89or6c7.AskSessionView? current,
    required List<_ij6hsnla.AskSessionSummary> recent,
  }) = _AskRestoreImpl;

  factory AskRestore.fromJson(Map<String, dynamic> jsonSerialization) {
    return AskRestore(
      current: jsonSerialization['current'] == null
          ? null
          : _i897a6pi.Protocol().deserialize<_i89or6c7.AskSessionView>(
              jsonSerialization['current'],
            ),
      recent: _i897a6pi.Protocol()
          .deserialize<List<_ij6hsnla.AskSessionSummary>>(
            jsonSerialization['recent'],
          ),
    );
  }

  /// Last activity within the resume window; null starts a new conversation.
  _i89or6c7.AskSessionView? current;

  /// Visible conversations (recent, at most the listed count), newest first.
  List<_ij6hsnla.AskSessionSummary> recent;

  /// Returns a shallow copy of this [AskRestore]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  AskRestore copyWith({
    _i89or6c7.AskSessionView? current,
    List<_ij6hsnla.AskSessionSummary>? recent,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AskRestore',
      if (current != null) 'current': current?.toJson(),
      'recent': recent.toJson(valueToJson: (v) => v.toJson()),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'AskRestore',
      if (current != null) 'current': current?.toJsonForProtocol(),
      'recent': recent.toJson(valueToJson: (v) => v.toJsonForProtocol()),
    };
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _AskRestoreImpl extends AskRestore {
  _AskRestoreImpl({
    _i89or6c7.AskSessionView? current,
    required List<_ij6hsnla.AskSessionSummary> recent,
  }) : super._(
         current: current,
         recent: recent,
       );

  /// Returns a shallow copy of this [AskRestore]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  AskRestore copyWith({
    Object? current = _Undefined,
    List<_ij6hsnla.AskSessionSummary>? recent,
  }) {
    return AskRestore(
      current: current is _i89or6c7.AskSessionView?
          ? current
          : this.current?.copyWith(),
      recent: recent ?? this.recent.map((e0) => e0.copyWith()).toList(),
    );
  }
}
