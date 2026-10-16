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
import 'package:pageblink_server/src/generated/document.dart' as _iloq337r;
import 'package:pageblink_server/src/generated/llm_model.dart' as _iladjzkp;
import 'package:pageblink_server/src/generated/page_text.dart' as _ibhttuac;
import 'package:pageblink_server/src/generated/project.dart' as _ik18e4tv;
import 'package:pageblink_server/src/generated/project_member.dart'
    as _i6s9o0ma;
import 'package:pageblink_server/src/generated/sample_hint.dart' as _iejty6dv;
import 'package:serverpod/protocol.dart' as _isp;
import 'package:serverpod/serverpod.dart' as _is;
import 'package:serverpod_auth_core_server/serverpod_auth_core_server.dart'
    as _iacs;
import 'package:serverpod_auth_idp_server/serverpod_auth_idp_server.dart'
    as _iais;
import 'answer_event.dart' as _iiosvpvg;
import 'ask_admin_filter.dart' as _iw2qnfnq;
import 'ask_admin_page.dart' as _is3ts0ul;
import 'ask_admin_session.dart' as _ioy8iwam;
import 'ask_history_status.dart' as _irkfr0me;
import 'ask_limit_exception.dart' as _i7eaw818;
import 'ask_limit_reason.dart' as _ihtb12es;
import 'ask_message.dart' as _ipc6xyah;
import 'ask_message_view.dart' as _ibozmn1p;
import 'ask_model_stat.dart' as _i8us82b8;
import 'ask_restore.dart' as _iwpzt5zb;
import 'ask_session.dart' as _iomvf0vw;
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
export 'answer_event.dart';
export 'ask_admin_filter.dart';
export 'ask_admin_page.dart';
export 'ask_admin_session.dart';
export 'ask_history_status.dart';
export 'ask_limit_exception.dart';
export 'ask_limit_reason.dart';
export 'ask_message.dart';
export 'ask_message_view.dart';
export 'ask_model_stat.dart';
export 'ask_restore.dart';
export 'ask_session.dart';
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

class Protocol extends _is.DatabaseSerializationManager {
  Protocol._();

  factory Protocol() => _instance;

  static final Protocol _instance = Protocol._().._registerHostProtocols();

  static List<_isp.TableDefinition> get targetTableDefinitions => [
    _isp.TableDefinition(
      name: 'ask_message',
      dartName: 'AskMessage',
      schema: 'public',
      module: 'pageblink',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isp.ColumnDefinition(
          name: 'sessionId',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'seq',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'question',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'answer',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
          columnDefault: '\'\'',
        ),
        _isp.ColumnDefinition(
          name: 'status',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'errorCode',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'citations',
          columnType: _isp.ColumnType.json,
          isNullable: true,
          dartType: 'List<protocol:Citation>?',
        ),
        _isp.ColumnDefinition(
          name: 'modelId',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'fallback',
          columnType: _isp.ColumnType.boolean,
          isNullable: false,
          dartType: 'bool',
          columnDefault: 'false',
        ),
        _isp.ColumnDefinition(
          name: 'projectIds',
          columnType: _isp.ColumnType.json,
          isNullable: true,
          dartType: 'List<int>?',
        ),
        _isp.ColumnDefinition(
          name: 'includePersonal',
          columnType: _isp.ColumnType.boolean,
          isNullable: false,
          dartType: 'bool',
          columnDefault: 'true',
        ),
        _isp.ColumnDefinition(
          name: 'createdAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _isp.ColumnDefinition(
          name: 'updatedAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [
        _isp.ForeignKeyDefinition(
          constraintName: 'ask_message_fk_0',
          columns: ['sessionId'],
          referenceTable: 'ask_session',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'ask_message_session_seq_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'sessionId',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'seq',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'ask_session',
      dartName: 'AskSession',
      schema: 'public',
      module: 'pageblink',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isp.ColumnDefinition(
          name: 'ownerId',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isp.ColumnDefinition(
          name: 'visitorKeyHash',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'isDemo',
          columnType: _isp.ColumnType.boolean,
          isNullable: false,
          dartType: 'bool',
          columnDefault: 'false',
        ),
        _isp.ColumnDefinition(
          name: 'title',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'locale',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'questionCount',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
          columnDefault: '0',
        ),
        _isp.ColumnDefinition(
          name: 'createdAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _isp.ColumnDefinition(
          name: 'lastActiveAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _isp.ColumnDefinition(
          name: 'streamingSince',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _isp.ColumnDefinition(
          name: 'hiddenAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'ask_session_owner_active_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'ownerId',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'visitorKeyHash',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'lastActiveAt',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _isp.IndexDefinition(
          indexName: 'ask_session_active_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'lastActiveAt',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'doc_chunk',
      dartName: 'DocChunk',
      schema: 'public',
      module: 'pageblink',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isp.ColumnDefinition(
          name: 'documentId',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'projectId',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'ownerId',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isp.ColumnDefinition(
          name: 'page',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'ordinal',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'text',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'contentHash',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'embedding',
          columnType: _isp.ColumnType.vector,
          isNullable: false,
          dartType: 'Vector(768)',
          vectorDimension: 768,
        ),
      ],
      foreignKeys: [],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'doc_chunk_embedding_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'embedding',
            ),
          ],
          type: 'hnsw',
          isUnique: false,
          isPrimary: false,
          vectorDistanceFunction: _isp.VectorDistanceFunction.cosine,
          vectorColumnType: _isp.ColumnType.vector,
        ),
        _isp.IndexDefinition(
          indexName: 'doc_chunk_document_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'documentId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'doc_page',
      dartName: 'DocPage',
      schema: 'public',
      module: 'pageblink',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isp.ColumnDefinition(
          name: 'documentId',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'page',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'text',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'doc_page_document_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'documentId',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'page',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'document',
      dartName: 'Document',
      schema: 'public',
      module: 'pageblink',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isp.ColumnDefinition(
          name: 'ownerId',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isp.ColumnDefinition(
          name: 'projectId',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'kind',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
          columnDefault: '\'pdf\'',
        ),
        _isp.ColumnDefinition(
          name: 'title',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'body',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'contentHash',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'version',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'pageCount',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'storagePath',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'status',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'lastError',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'embeddingModel',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'colorIndex',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'createdAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _isp.ColumnDefinition(
          name: 'updatedAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'document_owner_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'ownerId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _isp.IndexDefinition(
          indexName: 'document_project_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'projectId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'project',
      dartName: 'Project',
      schema: 'public',
      module: 'pageblink',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isp.ColumnDefinition(
          name: 'name',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'ownerId',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isp.ColumnDefinition(
          name: 'createdAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [],
      indexes: [],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'project_member',
      dartName: 'ProjectMember',
      schema: 'public',
      module: 'pageblink',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'serial',
        ),
        _isp.ColumnDefinition(
          name: 'projectId',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _isp.ColumnDefinition(
          name: 'userId',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isp.ColumnDefinition(
          name: 'role',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'project_member_unique_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'projectId',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'userId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _isp.IndexDefinition(
          indexName: 'project_member_user_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'userId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    ..._iais.Protocol.targetTableDefinitions,
    ..._iacs.Protocol.targetTableDefinitions,
    ..._isp.Protocol.targetTableDefinitions,
  ];

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
      } on _is.DeserializationClassNameNotFoundException catch (_) {
        // If the className is not recognized (e.g., older client receiving
        // data with a new subtype), fall back to deserializing without the
        // className, using the expected type T.
      }
    }

    if (t == _iiosvpvg.AnswerEvent) {
      return _iiosvpvg.AnswerEvent.fromJson(data) as T;
    }
    if (t == _iw2qnfnq.AskAdminFilter) {
      return _iw2qnfnq.AskAdminFilter.fromJson(data) as T;
    }
    if (t == _is3ts0ul.AskAdminPage) {
      return _is3ts0ul.AskAdminPage.fromJson(data) as T;
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
    if (t == _ipc6xyah.AskMessage) {
      return _ipc6xyah.AskMessage.fromJson(data) as T;
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
    if (t == _iomvf0vw.AskSession) {
      return _iomvf0vw.AskSession.fromJson(data) as T;
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
    if (t == _is.getType<_iiosvpvg.AnswerEvent?>()) {
      return (data != null ? _iiosvpvg.AnswerEvent.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_iw2qnfnq.AskAdminFilter?>()) {
      return (data != null ? _iw2qnfnq.AskAdminFilter.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_is3ts0ul.AskAdminPage?>()) {
      return (data != null ? _is3ts0ul.AskAdminPage.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_ioy8iwam.AskAdminSession?>()) {
      return (data != null ? _ioy8iwam.AskAdminSession.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_irkfr0me.AskHistoryStatus?>()) {
      return (data != null ? _irkfr0me.AskHistoryStatus.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_i7eaw818.AskLimitException?>()) {
      return (data != null ? _i7eaw818.AskLimitException.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_ihtb12es.AskLimitReason?>()) {
      return (data != null ? _ihtb12es.AskLimitReason.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_ipc6xyah.AskMessage?>()) {
      return (data != null ? _ipc6xyah.AskMessage.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_ibozmn1p.AskMessageView?>()) {
      return (data != null ? _ibozmn1p.AskMessageView.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_i8us82b8.AskModelStat?>()) {
      return (data != null ? _i8us82b8.AskModelStat.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_iwpzt5zb.AskRestore?>()) {
      return (data != null ? _iwpzt5zb.AskRestore.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_iomvf0vw.AskSession?>()) {
      return (data != null ? _iomvf0vw.AskSession.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_ij6hsnla.AskSessionSummary?>()) {
      return (data != null ? _ij6hsnla.AskSessionSummary.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_i89or6c7.AskSessionView?>()) {
      return (data != null ? _i89or6c7.AskSessionView.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_i7jy3rkv.Citation?>()) {
      return (data != null ? _i7jy3rkv.Citation.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_if2i642k.DemoLimitException?>()) {
      return (data != null ? _if2i642k.DemoLimitException.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_iyfquffa.DemoLimitReason?>()) {
      return (data != null ? _iyfquffa.DemoLimitReason.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_i8rpgbq5.DemoStatus?>()) {
      return (data != null ? _i8rpgbq5.DemoStatus.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_iy239l3h.DocChunk?>()) {
      return (data != null ? _iy239l3h.DocChunk.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_i92jcfzt.DocPage?>()) {
      return (data != null ? _i92jcfzt.DocPage.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_i674ac8o.Document?>()) {
      return (data != null ? _i674ac8o.Document.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_izw8z7ou.Greeting?>()) {
      return (data != null ? _izw8z7ou.Greeting.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_i52zzt9e.LlmModel?>()) {
      return (data != null ? _i52zzt9e.LlmModel.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_it8u2rte.PageText?>()) {
      return (data != null ? _it8u2rte.PageText.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_ifiazq2p.Project?>()) {
      return (data != null ? _ifiazq2p.Project.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_i7o7d07j.ProjectMember?>()) {
      return (data != null ? _i7o7d07j.ProjectMember.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_isfemdkk.SampleHint?>()) {
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
    if (t == _is.getType<List<_i7jy3rkv.Citation>?>()) {
      return (data != null
              ? (data as List)
                    .map((e) => deserialize<_i7jy3rkv.Citation>(e))
                    .toList()
              : null)
          as T;
    }
    if (t == List<int>) {
      return (data as List).map((e) => deserialize<int>(e)).toList() as T;
    }
    if (t == _is.getType<List<int>?>()) {
      return (data != null
              ? (data as List).map((e) => deserialize<int>(e)).toList()
              : null)
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
    if (t == List<_ibhttuac.PageText>) {
      return (data as List)
              .map((e) => deserialize<_ibhttuac.PageText>(e))
              .toList()
          as T;
    }
    if (t == List<_iejty6dv.SampleHint>) {
      return (data as List)
              .map((e) => deserialize<_iejty6dv.SampleHint>(e))
              .toList()
          as T;
    }
    if (t == List<_iloq337r.Document>) {
      return (data as List)
              .map((e) => deserialize<_iloq337r.Document>(e))
              .toList()
          as T;
    }
    if (t == List<_iladjzkp.LlmModel>) {
      return (data as List)
              .map((e) => deserialize<_iladjzkp.LlmModel>(e))
              .toList()
          as T;
    }
    if (t == List<_ik18e4tv.Project>) {
      return (data as List)
              .map((e) => deserialize<_ik18e4tv.Project>(e))
              .toList()
          as T;
    }
    if (t == List<_i6s9o0ma.ProjectMember>) {
      return (data as List)
              .map((e) => deserialize<_i6s9o0ma.ProjectMember>(e))
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
      return _iais.Protocol().deserialize<T>(data, t);
    } on _is.DeserializationTypeNotFoundException catch (_) {}
    try {
      return _iacs.Protocol().deserialize<T>(data, t);
    } on _is.DeserializationTypeNotFoundException catch (_) {}
    try {
      return _isp.Protocol().deserialize<T>(data, t);
    } on _is.DeserializationTypeNotFoundException catch (_) {}
    return super.deserialize<T>(data, t);
  }

  static String? getClassNameForType(Type type) {
    return switch (type) {
      _iiosvpvg.AnswerEvent => 'AnswerEvent',
      _iw2qnfnq.AskAdminFilter => 'AskAdminFilter',
      _is3ts0ul.AskAdminPage => 'AskAdminPage',
      _ioy8iwam.AskAdminSession => 'AskAdminSession',
      _irkfr0me.AskHistoryStatus => 'AskHistoryStatus',
      _i7eaw818.AskLimitException => 'AskLimitException',
      _ihtb12es.AskLimitReason => 'AskLimitReason',
      _ipc6xyah.AskMessage => 'AskMessage',
      _ibozmn1p.AskMessageView => 'AskMessageView',
      _i8us82b8.AskModelStat => 'AskModelStat',
      _iwpzt5zb.AskRestore => 'AskRestore',
      _iomvf0vw.AskSession => 'AskSession',
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
      case _iiosvpvg.AnswerEvent():
        return 'AnswerEvent';
      case _iw2qnfnq.AskAdminFilter():
        return 'AskAdminFilter';
      case _is3ts0ul.AskAdminPage():
        return 'AskAdminPage';
      case _ioy8iwam.AskAdminSession():
        return 'AskAdminSession';
      case _irkfr0me.AskHistoryStatus():
        return 'AskHistoryStatus';
      case _i7eaw818.AskLimitException():
        return 'AskLimitException';
      case _ihtb12es.AskLimitReason():
        return 'AskLimitReason';
      case _ipc6xyah.AskMessage():
        return 'AskMessage';
      case _ibozmn1p.AskMessageView():
        return 'AskMessageView';
      case _i8us82b8.AskModelStat():
        return 'AskModelStat';
      case _iwpzt5zb.AskRestore():
        return 'AskRestore';
      case _iomvf0vw.AskSession():
        return 'AskSession';
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
    className = _iais.Protocol().getClassNameForObject(data);
    if (className != null) {
      return className.contains('.')
          ? className
          : 'serverpod_auth_idp.$className';
    }
    className = _iacs.Protocol().getClassNameForObject(data);
    if (className != null) {
      return className.contains('.')
          ? className
          : 'serverpod_auth_core.$className';
    }
    className = _isp.Protocol().getClassNameForObject(data);
    if (className != null) {
      return className.contains('.') ? className : 'serverpod.$className';
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
    if (dataClassName == 'AskAdminFilter') {
      return deserialize<_iw2qnfnq.AskAdminFilter>(data['data']);
    }
    if (dataClassName == 'AskAdminPage') {
      return deserialize<_is3ts0ul.AskAdminPage>(data['data']);
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
    if (dataClassName == 'AskMessage') {
      return deserialize<_ipc6xyah.AskMessage>(data['data']);
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
    if (dataClassName == 'AskSession') {
      return deserialize<_iomvf0vw.AskSession>(data['data']);
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
      return _iais.Protocol().deserializeByClassName(data);
    }
    if (dataClassName.startsWith('serverpod_auth_core.')) {
      data['className'] = dataClassName.substring(20);
      return _iacs.Protocol().deserializeByClassName(data);
    }
    if (dataClassName.startsWith('serverpod.')) {
      data['className'] = dataClassName.substring(10);
      return _isp.Protocol().deserializeByClassName(data);
    }
    return super.deserializeByClassName(data);
  }

  void _registerHostProtocols() {
    _iais.Protocol().registerHostProtocol('pageblink', this);
    _iacs.Protocol().registerHostProtocol('pageblink', this);
  }

  @override
  _is.Table? getTableForType(Type t) {
    {
      var table = _iais.Protocol().getTableForType(t);
      if (table != null) {
        return table;
      }
    }
    {
      var table = _iacs.Protocol().getTableForType(t);
      if (table != null) {
        return table;
      }
    }
    {
      var table = _isp.Protocol().getTableForType(t);
      if (table != null) {
        return table;
      }
    }
    switch (t) {
      case _ipc6xyah.AskMessage:
        return _ipc6xyah.AskMessage.t;
      case _iomvf0vw.AskSession:
        return _iomvf0vw.AskSession.t;
      case _iy239l3h.DocChunk:
        return _iy239l3h.DocChunk.t;
      case _i92jcfzt.DocPage:
        return _i92jcfzt.DocPage.t;
      case _i674ac8o.Document:
        return _i674ac8o.Document.t;
      case _ifiazq2p.Project:
        return _ifiazq2p.Project.t;
      case _i7o7d07j.ProjectMember:
        return _i7o7d07j.ProjectMember.t;
    }
    return null;
  }

  @override
  List<_isp.TableDefinition> getTargetTableDefinitions() =>
      targetTableDefinitions;

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
      return _iais.Protocol().mapRecordToJson(record);
    } catch (_) {}
    try {
      return _iacs.Protocol().mapRecordToJson(record);
    } catch (_) {}
    throw Exception('Unsupported record type ${record.runtimeType}');
  }
}
