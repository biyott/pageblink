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
import 'ask_message_view.dart' as _ibozmn1p;

/// A conversation for the admin list, messages included. Read only.
abstract class AskAdminSession
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  AskAdminSession._({
    required this.id,
    required this.ownerId,
    required this.ownerLabel,
    required this.isDemo,
    required this.hidden,
    required this.title,
    this.locale,
    required this.questionCount,
    required this.createdAt,
    required this.lastActiveAt,
    required this.messages,
  });

  factory AskAdminSession({
    required int id,
    required String ownerId,
    required String ownerLabel,
    required bool isDemo,
    required bool hidden,
    required String title,
    String? locale,
    required int questionCount,
    required DateTime createdAt,
    required DateTime lastActiveAt,
    required List<_ibozmn1p.AskMessageView> messages,
  }) = _AskAdminSessionImpl;

  factory AskAdminSession.fromJson(Map<String, dynamic> jsonSerialization) {
    return AskAdminSession(
      id: jsonSerialization['id'] as int,
      ownerId: jsonSerialization['ownerId'] as String,
      ownerLabel: jsonSerialization['ownerLabel'] as String,
      isDemo: _isc.BoolJsonExtension.fromJson(jsonSerialization['isDemo']),
      hidden: _isc.BoolJsonExtension.fromJson(jsonSerialization['hidden']),
      title: jsonSerialization['title'] as String,
      locale: jsonSerialization['locale'] as String?,
      questionCount: jsonSerialization['questionCount'] as int,
      createdAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      lastActiveAt: _isc.DateTimeJsonExtension.fromJson(
        jsonSerialization['lastActiveAt'],
      ),
      messages: _igm2snhz.Protocol()
          .deserialize<List<_ibozmn1p.AskMessageView>>(
            jsonSerialization['messages'],
          ),
    );
  }

  int id;

  String ownerId;

  /// demo-ko / demo-en for the shared demo accounts, else the user id.
  String ownerLabel;

  bool isDemo;

  bool hidden;

  String title;

  String? locale;

  int questionCount;

  DateTime createdAt;

  DateTime lastActiveAt;

  List<_ibozmn1p.AskMessageView> messages;

  /// Returns a shallow copy of this [AskAdminSession]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  AskAdminSession copyWith({
    int? id,
    String? ownerId,
    String? ownerLabel,
    bool? isDemo,
    bool? hidden,
    String? title,
    String? locale,
    int? questionCount,
    DateTime? createdAt,
    DateTime? lastActiveAt,
    List<_ibozmn1p.AskMessageView>? messages,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AskAdminSession',
      'id': id,
      'ownerId': ownerId,
      'ownerLabel': ownerLabel,
      'isDemo': isDemo,
      'hidden': hidden,
      'title': title,
      if (locale != null) 'locale': locale,
      'questionCount': questionCount,
      'createdAt': createdAt.toJson(),
      'lastActiveAt': lastActiveAt.toJson(),
      'messages': messages.toJson(valueToJson: (v) => v.toJson()),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'AskAdminSession',
      'id': id,
      'ownerId': ownerId,
      'ownerLabel': ownerLabel,
      'isDemo': isDemo,
      'hidden': hidden,
      'title': title,
      if (locale != null) 'locale': locale,
      'questionCount': questionCount,
      'createdAt': createdAt.toJson(),
      'lastActiveAt': lastActiveAt.toJson(),
      'messages': messages.toJson(valueToJson: (v) => v.toJsonForProtocol()),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _AskAdminSessionImpl extends AskAdminSession {
  _AskAdminSessionImpl({
    required int id,
    required String ownerId,
    required String ownerLabel,
    required bool isDemo,
    required bool hidden,
    required String title,
    String? locale,
    required int questionCount,
    required DateTime createdAt,
    required DateTime lastActiveAt,
    required List<_ibozmn1p.AskMessageView> messages,
  }) : super._(
         id: id,
         ownerId: ownerId,
         ownerLabel: ownerLabel,
         isDemo: isDemo,
         hidden: hidden,
         title: title,
         locale: locale,
         questionCount: questionCount,
         createdAt: createdAt,
         lastActiveAt: lastActiveAt,
         messages: messages,
       );

  /// Returns a shallow copy of this [AskAdminSession]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  AskAdminSession copyWith({
    int? id,
    String? ownerId,
    String? ownerLabel,
    bool? isDemo,
    bool? hidden,
    String? title,
    Object? locale = _Undefined,
    int? questionCount,
    DateTime? createdAt,
    DateTime? lastActiveAt,
    List<_ibozmn1p.AskMessageView>? messages,
  }) {
    return AskAdminSession(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      ownerLabel: ownerLabel ?? this.ownerLabel,
      isDemo: isDemo ?? this.isDemo,
      hidden: hidden ?? this.hidden,
      title: title ?? this.title,
      locale: locale is String? ? locale : this.locale,
      questionCount: questionCount ?? this.questionCount,
      createdAt: createdAt ?? this.createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      messages: messages ?? this.messages.map((e0) => e0.copyWith()).toList(),
    );
  }
}
