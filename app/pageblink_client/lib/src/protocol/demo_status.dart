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

/// Public state of the demo account ("Try the demo"). When `enabled` is false
/// nothing else is meaningful (the app hides the button).
abstract class DemoStatus
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  DemoStatus._({
    required this.enabled,
    bool? isDemo,
    int? createLimit,
    this.createRemaining,
    int? askLimit,
    this.askRemaining,
  }) : isDemo = isDemo ?? false,
       createLimit = createLimit ?? 0,
       askLimit = askLimit ?? 0;

  factory DemoStatus({
    required bool enabled,
    bool? isDemo,
    int? createLimit,
    int? createRemaining,
    int? askLimit,
    int? askRemaining,
  }) = _DemoStatusImpl;

  factory DemoStatus.fromJson(Map<String, dynamic> jsonSerialization) {
    return DemoStatus(
      enabled: _isc.BoolJsonExtension.fromJson(jsonSerialization['enabled']),
      isDemo: jsonSerialization['isDemo'] == null
          ? null
          : _isc.BoolJsonExtension.fromJson(jsonSerialization['isDemo']),
      createLimit: jsonSerialization['createLimit'] as int?,
      createRemaining: jsonSerialization['createRemaining'] as int?,
      askLimit: jsonSerialization['askLimit'] as int?,
      askRemaining: jsonSerialization['askRemaining'] as int?,
    );
  }

  /// demoEnabled flag is on and the demo user exists.
  bool enabled;

  /// The caller is signed in as the demo account.
  bool isDemo;

  /// Documents (notes + PDFs, samples excluded) the demo account may create.
  int createLimit;

  /// Slots left right now. Null unless [isDemo].
  int? createRemaining;

  /// Questions per day, shared by every demo visitor.
  int askLimit;

  /// Questions left today. Null unless [isDemo].
  int? askRemaining;

  /// Returns a shallow copy of this [DemoStatus]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  DemoStatus copyWith({
    bool? enabled,
    bool? isDemo,
    int? createLimit,
    int? createRemaining,
    int? askLimit,
    int? askRemaining,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DemoStatus',
      'enabled': enabled,
      'isDemo': isDemo,
      'createLimit': createLimit,
      if (createRemaining != null) 'createRemaining': createRemaining,
      'askLimit': askLimit,
      if (askRemaining != null) 'askRemaining': askRemaining,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'DemoStatus',
      'enabled': enabled,
      'isDemo': isDemo,
      'createLimit': createLimit,
      if (createRemaining != null) 'createRemaining': createRemaining,
      'askLimit': askLimit,
      if (askRemaining != null) 'askRemaining': askRemaining,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DemoStatusImpl extends DemoStatus {
  _DemoStatusImpl({
    required bool enabled,
    bool? isDemo,
    int? createLimit,
    int? createRemaining,
    int? askLimit,
    int? askRemaining,
  }) : super._(
         enabled: enabled,
         isDemo: isDemo,
         createLimit: createLimit,
         createRemaining: createRemaining,
         askLimit: askLimit,
         askRemaining: askRemaining,
       );

  /// Returns a shallow copy of this [DemoStatus]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  DemoStatus copyWith({
    bool? enabled,
    bool? isDemo,
    int? createLimit,
    Object? createRemaining = _Undefined,
    int? askLimit,
    Object? askRemaining = _Undefined,
  }) {
    return DemoStatus(
      enabled: enabled ?? this.enabled,
      isDemo: isDemo ?? this.isDemo,
      createLimit: createLimit ?? this.createLimit,
      createRemaining: createRemaining is int?
          ? createRemaining
          : this.createRemaining,
      askLimit: askLimit ?? this.askLimit,
      askRemaining: askRemaining is int? ? askRemaining : this.askRemaining,
    );
  }
}
