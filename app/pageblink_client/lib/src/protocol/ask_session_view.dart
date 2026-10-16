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

/// One conversation with its messages (open / restore).
abstract class AskSessionView
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  AskSessionView._({
    required this.id,
    required this.title,
    required this.questionCount,
    required this.questionLimit,
    required this.lastActiveAt,
    required this.messages,
  });

  factory AskSessionView({
    required int id,
    required String title,
    required int questionCount,
    required int questionLimit,
    required DateTime lastActiveAt,
    required List<_ibozmn1p.AskMessageView> messages,
  }) = _AskSessionViewImpl;

  factory AskSessionView.fromJson(Map<String, dynamic> jsonSerialization) {
    return AskSessionView(
      id: jsonSerialization['id'] as int,
      title: jsonSerialization['title'] as String,
      questionCount: jsonSerialization['questionCount'] as int,
      questionLimit: jsonSerialization['questionLimit'] as int,
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

  String title;

  int questionCount;

  int questionLimit;

  DateTime lastActiveAt;

  List<_ibozmn1p.AskMessageView> messages;

  /// Returns a shallow copy of this [AskSessionView]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  AskSessionView copyWith({
    int? id,
    String? title,
    int? questionCount,
    int? questionLimit,
    DateTime? lastActiveAt,
    List<_ibozmn1p.AskMessageView>? messages,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AskSessionView',
      'id': id,
      'title': title,
      'questionCount': questionCount,
      'questionLimit': questionLimit,
      'lastActiveAt': lastActiveAt.toJson(),
      'messages': messages.toJson(valueToJson: (v) => v.toJson()),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'AskSessionView',
      'id': id,
      'title': title,
      'questionCount': questionCount,
      'questionLimit': questionLimit,
      'lastActiveAt': lastActiveAt.toJson(),
      'messages': messages.toJson(valueToJson: (v) => v.toJsonForProtocol()),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _AskSessionViewImpl extends AskSessionView {
  _AskSessionViewImpl({
    required int id,
    required String title,
    required int questionCount,
    required int questionLimit,
    required DateTime lastActiveAt,
    required List<_ibozmn1p.AskMessageView> messages,
  }) : super._(
         id: id,
         title: title,
         questionCount: questionCount,
         questionLimit: questionLimit,
         lastActiveAt: lastActiveAt,
         messages: messages,
       );

  /// Returns a shallow copy of this [AskSessionView]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  AskSessionView copyWith({
    int? id,
    String? title,
    int? questionCount,
    int? questionLimit,
    DateTime? lastActiveAt,
    List<_ibozmn1p.AskMessageView>? messages,
  }) {
    return AskSessionView(
      id: id ?? this.id,
      title: title ?? this.title,
      questionCount: questionCount ?? this.questionCount,
      questionLimit: questionLimit ?? this.questionLimit,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      messages: messages ?? this.messages.map((e0) => e0.copyWith()).toList(),
    );
  }
}
