/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member
// ignore_for_file: dead_code, unnecessary_type_check

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:pageblink_client/src/protocol/document.dart' as _ix72owx0;
import 'package:pageblink_client/src/protocol/llm_model.dart' as _ikmj492w;
import 'package:pageblink_client/src/protocol/page_text.dart' as _iu4vwvb3;
import 'package:pageblink_client/src/protocol/project.dart' as _id2xbn90;
import 'package:pageblink_client/src/protocol/project_member.dart' as _ijtrgq11;
import 'package:serverpod_auth_core_client/serverpod_auth_core_client.dart'
    as _iacc;
import 'package:serverpod_auth_idp_client/serverpod_auth_idp_client.dart'
    as _iaic;
import 'package:serverpod_client/serverpod_client.dart' as _isc;
import 'answer_event.dart' as _iiosvpvg;
import 'citation.dart' as _i7jy3rkv;
import 'doc_chunk.dart' as _iy239l3h;
import 'doc_page.dart' as _i92jcfzt;
import 'document.dart' as _i674ac8o;
import 'greetings/greeting.dart' as _izw8z7ou;
import 'llm_model.dart' as _i52zzt9e;
import 'page_text.dart' as _it8u2rte;
import 'project.dart' as _ifiazq2p;
import 'project_member.dart' as _i7o7d07j;
export 'answer_event.dart';
export 'citation.dart';
export 'doc_chunk.dart';
export 'doc_page.dart';
export 'document.dart';
export 'greetings/greeting.dart';
export 'llm_model.dart';
export 'page_text.dart';
export 'project.dart';
export 'project_member.dart';
export 'client.dart';

class Protocol extends _isc.SerializationManager {
  Protocol._();

  factory Protocol() => _instance;

  static final Protocol _instance = Protocol._().._registerHostProtocols();

  static String? getClassNameFromObjectJson(dynamic data) {
    if (data is! Map) return null;
    final className = data['__className__'] as String?;
    return className;
  }

  @override
  T deserialize<T>(
    dynamic data, [
    Type? t,
  ]) {
    t ??= T;

    final dataClassName = getClassNameFromObjectJson(data);
    if (dataClassName != null && dataClassName != getClassNameForType(t)) {
      try {
        return deserializeByClassName({
          'className': dataClassName,
          'data': data,
        });
      } on _isc.DeserializationClassNameNotFoundException catch (_) {
        // If the className is not recognized (e.g., older client receiving
        // data with a new subtype), fall back to deserializing without the
        // className, using the expected type T.
      }
    }

    if (t == _iiosvpvg.AnswerEvent) {
      return _iiosvpvg.AnswerEvent.fromJson(data) as T;
    }
    if (t == _i7jy3rkv.Citation) {
      return _i7jy3rkv.Citation.fromJson(data) as T;
    }
    if (t == _iy239l3h.DocChunk) {
      return _iy239l3h.DocChunk.fromJson(data) as T;
    }
    if (t == _i92jcfzt.DocPage) {
      return _i92jcfzt.DocPage.fromJson(data) as T;
    }
    if (t == _i674ac8o.Document) {
      return _i674ac8o.Document.fromJson(data) as T;
    }
    if (t == _izw8z7ou.Greeting) {
      return _izw8z7ou.Greeting.fromJson(data) as T;
    }
    if (t == _i52zzt9e.LlmModel) {
      return _i52zzt9e.LlmModel.fromJson(data) as T;
    }
    if (t == _it8u2rte.PageText) {
      return _it8u2rte.PageText.fromJson(data) as T;
    }
    if (t == _ifiazq2p.Project) {
      return _ifiazq2p.Project.fromJson(data) as T;
    }
    if (t == _i7o7d07j.ProjectMember) {
      return _i7o7d07j.ProjectMember.fromJson(data) as T;
    }
    if (t == _isc.getType<_iiosvpvg.AnswerEvent?>()) {
      return (data != null ? _iiosvpvg.AnswerEvent.fromJson(data) : null) as T;
    }
    if (t == _isc.getType<_i7jy3rkv.Citation?>()) {
      return (data != null ? _i7jy3rkv.Citation.fromJson(data) : null) as T;
    }
    if (t == _isc.getType<_iy239l3h.DocChunk?>()) {
      return (data != null ? _iy239l3h.DocChunk.fromJson(data) : null) as T;
    }
    if (t == _isc.getType<_i92jcfzt.DocPage?>()) {
      return (data != null ? _i92jcfzt.DocPage.fromJson(data) : null) as T;
    }
    if (t == _isc.getType<_i674ac8o.Document?>()) {
      return (data != null ? _i674ac8o.Document.fromJson(data) : null) as T;
    }
    if (t == _isc.getType<_izw8z7ou.Greeting?>()) {
      return (data != null ? _izw8z7ou.Greeting.fromJson(data) : null) as T;
    }
    if (t == _isc.getType<_i52zzt9e.LlmModel?>()) {
      return (data != null ? _i52zzt9e.LlmModel.fromJson(data) : null) as T;
    }
    if (t == _isc.getType<_it8u2rte.PageText?>()) {
      return (data != null ? _it8u2rte.PageText.fromJson(data) : null) as T;
    }
    if (t == _isc.getType<_ifiazq2p.Project?>()) {
      return (data != null ? _ifiazq2p.Project.fromJson(data) : null) as T;
    }
    if (t == _isc.getType<_i7o7d07j.ProjectMember?>()) {
      return (data != null ? _i7o7d07j.ProjectMember.fromJson(data) : null)
          as T;
    }
    if (t == List<int>) {
      return (data as List).map((e) => deserialize<int>(e)).toList() as T;
    }
    if (t == List<_iu4vwvb3.PageText>) {
      return (data as List)
              .map((e) => deserialize<_iu4vwvb3.PageText>(e))
              .toList()
          as T;
    }
    if (t == List<_ix72owx0.Document>) {
      return (data as List)
              .map((e) => deserialize<_ix72owx0.Document>(e))
              .toList()
          as T;
    }
    if (t == List<_ikmj492w.LlmModel>) {
      return (data as List)
              .map((e) => deserialize<_ikmj492w.LlmModel>(e))
              .toList()
          as T;
    }
    if (t == List<_id2xbn90.Project>) {
      return (data as List)
              .map((e) => deserialize<_id2xbn90.Project>(e))
              .toList()
          as T;
    }
    if (t == List<_ijtrgq11.ProjectMember>) {
      return (data as List)
              .map((e) => deserialize<_ijtrgq11.ProjectMember>(e))
              .toList()
          as T;
    }
    if (t == Map<String, int>) {
      return (data as Map).map(
            (k, v) => MapEntry(deserialize<String>(k), deserialize<int>(v)),
          )
          as T;
    }
    try {
      return _iaic.Protocol().deserialize<T>(data, t);
    } on _isc.DeserializationTypeNotFoundException catch (_) {}
    try {
      return _iacc.Protocol().deserialize<T>(data, t);
    } on _isc.DeserializationTypeNotFoundException catch (_) {}
    return super.deserialize<T>(data, t);
  }

  static String? getClassNameForType(Type type) {
    return switch (type) {
      _iiosvpvg.AnswerEvent => 'AnswerEvent',
      _i7jy3rkv.Citation => 'Citation',
      _iy239l3h.DocChunk => 'DocChunk',
      _i92jcfzt.DocPage => 'DocPage',
      _i674ac8o.Document => 'Document',
      _izw8z7ou.Greeting => 'Greeting',
      _i52zzt9e.LlmModel => 'LlmModel',
      _it8u2rte.PageText => 'PageText',
      _ifiazq2p.Project => 'Project',
      _i7o7d07j.ProjectMember => 'ProjectMember',
      _ => null,
    };
  }

  @override
  String? getClassNameForObject(Object? data) {
    String? className = super.getClassNameForObject(data);
    if (className != null) return className;

    if (data is Map<String, dynamic> && data['__className__'] is String) {
      return (data['__className__'] as String).replaceFirst('pageblink.', '');
    }

    switch (data) {
      case _iiosvpvg.AnswerEvent():
        return 'AnswerEvent';
      case _i7jy3rkv.Citation():
        return 'Citation';
      case _iy239l3h.DocChunk():
        return 'DocChunk';
      case _i92jcfzt.DocPage():
        return 'DocPage';
      case _i674ac8o.Document():
        return 'Document';
      case _izw8z7ou.Greeting():
        return 'Greeting';
      case _i52zzt9e.LlmModel():
        return 'LlmModel';
      case _it8u2rte.PageText():
        return 'PageText';
      case _ifiazq2p.Project():
        return 'Project';
      case _i7o7d07j.ProjectMember():
        return 'ProjectMember';
    }
    className = _iaic.Protocol().getClassNameForObject(data);
    if (className != null) {
      return className.contains('.')
          ? className
          : 'serverpod_auth_idp.$className';
    }
    className = _iacc.Protocol().getClassNameForObject(data);
    if (className != null) {
      return className.contains('.')
          ? className
          : 'serverpod_auth_core.$className';
    }
    return null;
  }

  @override
  dynamic deserializeByClassName(Map<String, dynamic> data) {
    var dataClassName = data['className'];
    if (dataClassName is! String) {
      return super.deserializeByClassName(data);
    }
    if (dataClassName == 'AnswerEvent') {
      return deserialize<_iiosvpvg.AnswerEvent>(data['data']);
    }
    if (dataClassName == 'Citation') {
      return deserialize<_i7jy3rkv.Citation>(data['data']);
    }
    if (dataClassName == 'DocChunk') {
      return deserialize<_iy239l3h.DocChunk>(data['data']);
    }
    if (dataClassName == 'DocPage') {
      return deserialize<_i92jcfzt.DocPage>(data['data']);
    }
    if (dataClassName == 'Document') {
      return deserialize<_i674ac8o.Document>(data['data']);
    }
    if (dataClassName == 'Greeting') {
      return deserialize<_izw8z7ou.Greeting>(data['data']);
    }
    if (dataClassName == 'LlmModel') {
      return deserialize<_i52zzt9e.LlmModel>(data['data']);
    }
    if (dataClassName == 'PageText') {
      return deserialize<_it8u2rte.PageText>(data['data']);
    }
    if (dataClassName == 'Project') {
      return deserialize<_ifiazq2p.Project>(data['data']);
    }
    if (dataClassName == 'ProjectMember') {
      return deserialize<_i7o7d07j.ProjectMember>(data['data']);
    }
    if (dataClassName.startsWith('serverpod_auth_idp.')) {
      data['className'] = dataClassName.substring(19);
      return _iaic.Protocol().deserializeByClassName(data);
    }
    if (dataClassName.startsWith('serverpod_auth_core.')) {
      data['className'] = dataClassName.substring(20);
      return _iacc.Protocol().deserializeByClassName(data);
    }
    return super.deserializeByClassName(data);
  }

  void _registerHostProtocols() {
    _iaic.Protocol().registerHostProtocol('pageblink', this);
    _iacc.Protocol().registerHostProtocol('pageblink', this);
  }

  @override
  String getModuleName() => 'pageblink';

  /// Maps any `Record`s known to this [Protocol] to their JSON representation
  ///
  /// Throws in case the record type is not known.
  ///
  /// This method will return `null` (only) for `null` inputs.
  Map<String, dynamic>? mapRecordToJson(Record? record) {
    if (record == null) {
      return null;
    }
    try {
      return _iaic.Protocol().mapRecordToJson(record);
    } catch (_) {}
    try {
      return _iacc.Protocol().mapRecordToJson(record);
    } catch (_) {}
    throw Exception('Unsupported record type ${record.runtimeType}');
  }
}
