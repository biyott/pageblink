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
import 'package:pageblink_client/src/protocol/sample_hint.dart' as _ilp4f5ys;
import 'package:serverpod_auth_core_client/serverpod_auth_core_client.dart'
    as _iacc;
import 'package:serverpod_auth_idp_client/serverpod_auth_idp_client.dart'
    as _iaic;
import 'package:serverpod_client/serverpod_client.dart' as _isc;
import 'account_info.dart' as _i1wu8vx0;
import 'answer_event.dart' as _iiosvpvg;
import 'ask_admin_exception.dart' as _i51waa1s;
import 'ask_admin_filter.dart' as _iw2qnfnq;
import 'ask_admin_page.dart' as _is3ts0ul;
import 'ask_admin_reason.dart' as _ijcvup8n;
import 'ask_admin_session.dart' as _ioy8iwam;
import 'ask_history_status.dart' as _irkfr0me;
import 'ask_limit_exception.dart' as _i7eaw818;
import 'ask_limit_reason.dart' as _ihtb12es;
import 'ask_message_view.dart' as _ibozmn1p;
import 'ask_model_stat.dart' as _i8us82b8;
import 'ask_restore.dart' as _iwpzt5zb;
import 'ask_session_summary.dart' as _ij6hsnla;
import 'ask_session_view.dart' as _i89or6c7;
import 'citation.dart' as _i7jy3rkv;
import 'demo_limit_exception.dart' as _if2i642k;
import 'demo_limit_reason.dart' as _iyfquffa;
import 'demo_status.dart' as _i8rpgbq5;
import 'doc_chunk.dart' as _iy239l3h;
import 'doc_page.dart' as _i92jcfzt;
import 'document.dart' as _i674ac8o;
import 'greetings/greeting.dart' as _izw8z7ou;
import 'llm_model.dart' as _i52zzt9e;
import 'page_text.dart' as _it8u2rte;
import 'project.dart' as _ifiazq2p;
import 'project_member.dart' as _i7o7d07j;
import 'sample_hint.dart' as _isfemdkk;
export 'account_info.dart';
export 'answer_event.dart';
export 'ask_admin_exception.dart';
export 'ask_admin_filter.dart';
export 'ask_admin_page.dart';
export 'ask_admin_reason.dart';
export 'ask_admin_session.dart';
export 'ask_history_status.dart';
export 'ask_limit_exception.dart';
export 'ask_limit_reason.dart';
export 'ask_message_view.dart';
export 'ask_model_stat.dart';
export 'ask_restore.dart';
export 'ask_session_summary.dart';
export 'ask_session_view.dart';
export 'citation.dart';
export 'demo_limit_exception.dart';
export 'demo_limit_reason.dart';
export 'demo_status.dart';
export 'doc_chunk.dart';
export 'doc_page.dart';
export 'document.dart';
export 'greetings/greeting.dart';
export 'llm_model.dart';
export 'page_text.dart';
export 'project.dart';
export 'project_member.dart';
export 'sample_hint.dart';
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

    if (t == _i1wu8vx0.AccountInfo) {
      return _i1wu8vx0.AccountInfo.fromJson(data) as T;
    }
    if (t == _iiosvpvg.AnswerEvent) {
      return _iiosvpvg.AnswerEvent.fromJson(data) as T;
    }
    if (t == _i51waa1s.AskAdminException) {
      return _i51waa1s.AskAdminException.fromJson(data) as T;
    }
    if (t == _iw2qnfnq.AskAdminFilter) {
      return _iw2qnfnq.AskAdminFilter.fromJson(data) as T;
    }
    if (t == _is3ts0ul.AskAdminPage) {
      return _is3ts0ul.AskAdminPage.fromJson(data) as T;
    }
    if (t == _ijcvup8n.AskAdminReason) {
      return _ijcvup8n.AskAdminReason.fromJson(data) as T;
    }
    if (t == _ioy8iwam.AskAdminSession) {
      return _ioy8iwam.AskAdminSession.fromJson(data) as T;
    }
    if (t == _irkfr0me.AskHistoryStatus) {
      return _irkfr0me.AskHistoryStatus.fromJson(data) as T;
    }
    if (t == _i7eaw818.AskLimitException) {
      return _i7eaw818.AskLimitException.fromJson(data) as T;
    }
    if (t == _ihtb12es.AskLimitReason) {
      return _ihtb12es.AskLimitReason.fromJson(data) as T;
    }
    if (t == _ibozmn1p.AskMessageView) {
      return _ibozmn1p.AskMessageView.fromJson(data) as T;
    }
    if (t == _i8us82b8.AskModelStat) {
      return _i8us82b8.AskModelStat.fromJson(data) as T;
    }
    if (t == _iwpzt5zb.AskRestore) {
      return _iwpzt5zb.AskRestore.fromJson(data) as T;
    }
    if (t == _ij6hsnla.AskSessionSummary) {
      return _ij6hsnla.AskSessionSummary.fromJson(data) as T;
    }
    if (t == _i89or6c7.AskSessionView) {
      return _i89or6c7.AskSessionView.fromJson(data) as T;
    }
    if (t == _i7jy3rkv.Citation) {
      return _i7jy3rkv.Citation.fromJson(data) as T;
    }
    if (t == _if2i642k.DemoLimitException) {
      return _if2i642k.DemoLimitException.fromJson(data) as T;
    }
    if (t == _iyfquffa.DemoLimitReason) {
      return _iyfquffa.DemoLimitReason.fromJson(data) as T;
    }
    if (t == _i8rpgbq5.DemoStatus) {
      return _i8rpgbq5.DemoStatus.fromJson(data) as T;
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
    if (t == _isfemdkk.SampleHint) {
      return _isfemdkk.SampleHint.fromJson(data) as T;
    }
    if (t == _isc.getType<_i1wu8vx0.AccountInfo?>()) {
      return (data != null ? _i1wu8vx0.AccountInfo.fromJson(data) : null) as T;
    }
    if (t == _isc.getType<_iiosvpvg.AnswerEvent?>()) {
      return (data != null ? _iiosvpvg.AnswerEvent.fromJson(data) : null) as T;
    }
    if (t == _isc.getType<_i51waa1s.AskAdminException?>()) {
      return (data != null ? _i51waa1s.AskAdminException.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_iw2qnfnq.AskAdminFilter?>()) {
      return (data != null ? _iw2qnfnq.AskAdminFilter.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_is3ts0ul.AskAdminPage?>()) {
      return (data != null ? _is3ts0ul.AskAdminPage.fromJson(data) : null) as T;
    }
    if (t == _isc.getType<_ijcvup8n.AskAdminReason?>()) {
      return (data != null ? _ijcvup8n.AskAdminReason.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_ioy8iwam.AskAdminSession?>()) {
      return (data != null ? _ioy8iwam.AskAdminSession.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_irkfr0me.AskHistoryStatus?>()) {
      return (data != null ? _irkfr0me.AskHistoryStatus.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_i7eaw818.AskLimitException?>()) {
      return (data != null ? _i7eaw818.AskLimitException.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_ihtb12es.AskLimitReason?>()) {
      return (data != null ? _ihtb12es.AskLimitReason.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_ibozmn1p.AskMessageView?>()) {
      return (data != null ? _ibozmn1p.AskMessageView.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_i8us82b8.AskModelStat?>()) {
      return (data != null ? _i8us82b8.AskModelStat.fromJson(data) : null) as T;
    }
    if (t == _isc.getType<_iwpzt5zb.AskRestore?>()) {
      return (data != null ? _iwpzt5zb.AskRestore.fromJson(data) : null) as T;
    }
    if (t == _isc.getType<_ij6hsnla.AskSessionSummary?>()) {
      return (data != null ? _ij6hsnla.AskSessionSummary.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_i89or6c7.AskSessionView?>()) {
      return (data != null ? _i89or6c7.AskSessionView.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_i7jy3rkv.Citation?>()) {
      return (data != null ? _i7jy3rkv.Citation.fromJson(data) : null) as T;
    }
    if (t == _isc.getType<_if2i642k.DemoLimitException?>()) {
      return (data != null ? _if2i642k.DemoLimitException.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_iyfquffa.DemoLimitReason?>()) {
      return (data != null ? _iyfquffa.DemoLimitReason.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_i8rpgbq5.DemoStatus?>()) {
      return (data != null ? _i8rpgbq5.DemoStatus.fromJson(data) : null) as T;
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
    if (t == _isc.getType<_isfemdkk.SampleHint?>()) {
      return (data != null ? _isfemdkk.SampleHint.fromJson(data) : null) as T;
    }
    if (t == List<_ioy8iwam.AskAdminSession>) {
      return (data as List)
              .map((e) => deserialize<_ioy8iwam.AskAdminSession>(e))
              .toList()
          as T;
    }
    if (t == List<_i8us82b8.AskModelStat>) {
      return (data as List)
              .map((e) => deserialize<_i8us82b8.AskModelStat>(e))
              .toList()
          as T;
    }
    if (t == List<_ibozmn1p.AskMessageView>) {
      return (data as List)
              .map((e) => deserialize<_ibozmn1p.AskMessageView>(e))
              .toList()
          as T;
    }
    if (t == List<_i7jy3rkv.Citation>) {
      return (data as List)
              .map((e) => deserialize<_i7jy3rkv.Citation>(e))
              .toList()
          as T;
    }
    if (t == List<_ij6hsnla.AskSessionSummary>) {
      return (data as List)
              .map((e) => deserialize<_ij6hsnla.AskSessionSummary>(e))
              .toList()
          as T;
    }
    if (t == List<String>) {
      return (data as List).map((e) => deserialize<String>(e)).toList() as T;
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
    if (t == List<_ilp4f5ys.SampleHint>) {
      return (data as List)
              .map((e) => deserialize<_ilp4f5ys.SampleHint>(e))
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
      _i1wu8vx0.AccountInfo => 'AccountInfo',
      _iiosvpvg.AnswerEvent => 'AnswerEvent',
      _i51waa1s.AskAdminException => 'AskAdminException',
      _iw2qnfnq.AskAdminFilter => 'AskAdminFilter',
      _is3ts0ul.AskAdminPage => 'AskAdminPage',
      _ijcvup8n.AskAdminReason => 'AskAdminReason',
      _ioy8iwam.AskAdminSession => 'AskAdminSession',
      _irkfr0me.AskHistoryStatus => 'AskHistoryStatus',
      _i7eaw818.AskLimitException => 'AskLimitException',
      _ihtb12es.AskLimitReason => 'AskLimitReason',
      _ibozmn1p.AskMessageView => 'AskMessageView',
      _i8us82b8.AskModelStat => 'AskModelStat',
      _iwpzt5zb.AskRestore => 'AskRestore',
      _ij6hsnla.AskSessionSummary => 'AskSessionSummary',
      _i89or6c7.AskSessionView => 'AskSessionView',
      _i7jy3rkv.Citation => 'Citation',
      _if2i642k.DemoLimitException => 'DemoLimitException',
      _iyfquffa.DemoLimitReason => 'DemoLimitReason',
      _i8rpgbq5.DemoStatus => 'DemoStatus',
      _iy239l3h.DocChunk => 'DocChunk',
      _i92jcfzt.DocPage => 'DocPage',
      _i674ac8o.Document => 'Document',
      _izw8z7ou.Greeting => 'Greeting',
      _i52zzt9e.LlmModel => 'LlmModel',
      _it8u2rte.PageText => 'PageText',
      _ifiazq2p.Project => 'Project',
      _i7o7d07j.ProjectMember => 'ProjectMember',
      _isfemdkk.SampleHint => 'SampleHint',
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
      case _i1wu8vx0.AccountInfo():
        return 'AccountInfo';
      case _iiosvpvg.AnswerEvent():
        return 'AnswerEvent';
      case _i51waa1s.AskAdminException():
        return 'AskAdminException';
      case _iw2qnfnq.AskAdminFilter():
        return 'AskAdminFilter';
      case _is3ts0ul.AskAdminPage():
        return 'AskAdminPage';
      case _ijcvup8n.AskAdminReason():
        return 'AskAdminReason';
      case _ioy8iwam.AskAdminSession():
        return 'AskAdminSession';
      case _irkfr0me.AskHistoryStatus():
        return 'AskHistoryStatus';
      case _i7eaw818.AskLimitException():
        return 'AskLimitException';
      case _ihtb12es.AskLimitReason():
        return 'AskLimitReason';
      case _ibozmn1p.AskMessageView():
        return 'AskMessageView';
      case _i8us82b8.AskModelStat():
        return 'AskModelStat';
      case _iwpzt5zb.AskRestore():
        return 'AskRestore';
      case _ij6hsnla.AskSessionSummary():
        return 'AskSessionSummary';
      case _i89or6c7.AskSessionView():
        return 'AskSessionView';
      case _i7jy3rkv.Citation():
        return 'Citation';
      case _if2i642k.DemoLimitException():
        return 'DemoLimitException';
      case _iyfquffa.DemoLimitReason():
        return 'DemoLimitReason';
      case _i8rpgbq5.DemoStatus():
        return 'DemoStatus';
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
      case _isfemdkk.SampleHint():
        return 'SampleHint';
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
    if (dataClassName == 'AccountInfo') {
      return deserialize<_i1wu8vx0.AccountInfo>(data['data']);
    }
    if (dataClassName == 'AnswerEvent') {
      return deserialize<_iiosvpvg.AnswerEvent>(data['data']);
    }
    if (dataClassName == 'AskAdminException') {
      return deserialize<_i51waa1s.AskAdminException>(data['data']);
    }
    if (dataClassName == 'AskAdminFilter') {
      return deserialize<_iw2qnfnq.AskAdminFilter>(data['data']);
    }
    if (dataClassName == 'AskAdminPage') {
      return deserialize<_is3ts0ul.AskAdminPage>(data['data']);
    }
    if (dataClassName == 'AskAdminReason') {
      return deserialize<_ijcvup8n.AskAdminReason>(data['data']);
    }
    if (dataClassName == 'AskAdminSession') {
      return deserialize<_ioy8iwam.AskAdminSession>(data['data']);
    }
    if (dataClassName == 'AskHistoryStatus') {
      return deserialize<_irkfr0me.AskHistoryStatus>(data['data']);
    }
    if (dataClassName == 'AskLimitException') {
      return deserialize<_i7eaw818.AskLimitException>(data['data']);
    }
    if (dataClassName == 'AskLimitReason') {
      return deserialize<_ihtb12es.AskLimitReason>(data['data']);
    }
    if (dataClassName == 'AskMessageView') {
      return deserialize<_ibozmn1p.AskMessageView>(data['data']);
    }
    if (dataClassName == 'AskModelStat') {
      return deserialize<_i8us82b8.AskModelStat>(data['data']);
    }
    if (dataClassName == 'AskRestore') {
      return deserialize<_iwpzt5zb.AskRestore>(data['data']);
    }
    if (dataClassName == 'AskSessionSummary') {
      return deserialize<_ij6hsnla.AskSessionSummary>(data['data']);
    }
    if (dataClassName == 'AskSessionView') {
      return deserialize<_i89or6c7.AskSessionView>(data['data']);
    }
    if (dataClassName == 'Citation') {
      return deserialize<_i7jy3rkv.Citation>(data['data']);
    }
    if (dataClassName == 'DemoLimitException') {
      return deserialize<_if2i642k.DemoLimitException>(data['data']);
    }
    if (dataClassName == 'DemoLimitReason') {
      return deserialize<_iyfquffa.DemoLimitReason>(data['data']);
    }
    if (dataClassName == 'DemoStatus') {
      return deserialize<_i8rpgbq5.DemoStatus>(data['data']);
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
    if (dataClassName == 'SampleHint') {
      return deserialize<_isfemdkk.SampleHint>(data['data']);
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
