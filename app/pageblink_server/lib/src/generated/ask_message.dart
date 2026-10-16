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
import 'citation.dart' as _i7jy3rkv;

/// One question and its answer inside an AskSession. Server only.
abstract class AskMessage
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  AskMessage._({
    this.id,
    required this.sessionId,
    required this.seq,
    required this.question,
    String? answer,
    required this.status,
    this.errorCode,
    this.citations,
    this.modelId,
    bool? fallback,
    this.projectIds,
    bool? includePersonal,
    required this.createdAt,
    required this.updatedAt,
  }) : answer = answer ?? '',
       fallback = fallback ?? false,
       includePersonal = includePersonal ?? true;

  factory AskMessage({
    int? id,
    required int sessionId,
    required int seq,
    required String question,
    String? answer,
    required String status,
    String? errorCode,
    List<_i7jy3rkv.Citation>? citations,
    String? modelId,
    bool? fallback,
    List<int>? projectIds,
    bool? includePersonal,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _AskMessageImpl;

  factory AskMessage.fromJson(Map<String, dynamic> jsonSerialization) {
    return AskMessage(
      id: jsonSerialization['id'] as int?,
      sessionId: jsonSerialization['sessionId'] as int,
      seq: jsonSerialization['seq'] as int,
      question: jsonSerialization['question'] as String,
      answer: jsonSerialization['answer'] as String?,
      status: jsonSerialization['status'] as String,
      errorCode: jsonSerialization['errorCode'] as String?,
      citations: jsonSerialization['citations'] == null
          ? null
          : _i897a6pi.Protocol().deserialize<List<_i7jy3rkv.Citation>>(
              jsonSerialization['citations'],
            ),
      modelId: jsonSerialization['modelId'] as String?,
      fallback: jsonSerialization['fallback'] == null
          ? null
          : _is.BoolJsonExtension.fromJson(jsonSerialization['fallback']),
      projectIds: jsonSerialization['projectIds'] == null
          ? null
          : _i897a6pi.Protocol().deserialize<List<int>>(
              jsonSerialization['projectIds'],
            ),
      includePersonal: jsonSerialization['includePersonal'] == null
          ? null
          : _is.BoolJsonExtension.fromJson(
              jsonSerialization['includePersonal'],
            ),
      createdAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      updatedAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['updatedAt'],
      ),
    );
  }

  static final t = AskMessageTable();

  static const db = AskMessageRepository._();

  @override
  int? id;

  int sessionId;

  /// 1-based position in the conversation.
  int seq;

  String question;

  /// The answer exactly as streamed, [n] markers included.
  String answer;

  /// streaming | done | error | interrupted
  String status;

  /// Short code only (busy, llm, internal). Never an exception message.
  String? errorCode;

  List<_i7jy3rkv.Citation>? citations;

  /// The model that actually answered.
  String? modelId;

  /// The answer came from another model than the one asked for.
  bool fallback;

  /// Scope the question was asked with (after the membership intersection).
  List<int>? projectIds;

  bool includePersonal;

  DateTime createdAt;

  /// Last checkpoint while streaming, then the finish time.
  DateTime updatedAt;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [AskMessage]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  AskMessage copyWith({
    int? id,
    int? sessionId,
    int? seq,
    String? question,
    String? answer,
    String? status,
    String? errorCode,
    List<_i7jy3rkv.Citation>? citations,
    String? modelId,
    bool? fallback,
    List<int>? projectIds,
    bool? includePersonal,
    DateTime? createdAt,
    DateTime? updatedAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AskMessage',
      if (id != null) 'id': id,
      'sessionId': sessionId,
      'seq': seq,
      'question': question,
      'answer': answer,
      'status': status,
      if (errorCode != null) 'errorCode': errorCode,
      if (citations != null)
        'citations': citations?.toJson(valueToJson: (v) => v.toJson()),
      if (modelId != null) 'modelId': modelId,
      'fallback': fallback,
      if (projectIds != null) 'projectIds': projectIds?.toJson(),
      'includePersonal': includePersonal,
      'createdAt': createdAt.toJson(),
      'updatedAt': updatedAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static AskMessageInclude include() {
    return AskMessageInclude._();
  }

  static AskMessageIncludeList includeList({
    _is.WhereExpressionBuilder<AskMessageTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<AskMessageTable>? orderBy,
    _is.OrderByListBuilder<AskMessageTable>? orderByList,
    AskMessageInclude? include,
  }) {
    return AskMessageIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(AskMessage.t),
      orderByList: orderByList?.call(AskMessage.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _AskMessageImpl extends AskMessage {
  _AskMessageImpl({
    int? id,
    required int sessionId,
    required int seq,
    required String question,
    String? answer,
    required String status,
    String? errorCode,
    List<_i7jy3rkv.Citation>? citations,
    String? modelId,
    bool? fallback,
    List<int>? projectIds,
    bool? includePersonal,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : super._(
         id: id,
         sessionId: sessionId,
         seq: seq,
         question: question,
         answer: answer,
         status: status,
         errorCode: errorCode,
         citations: citations,
         modelId: modelId,
         fallback: fallback,
         projectIds: projectIds,
         includePersonal: includePersonal,
         createdAt: createdAt,
         updatedAt: updatedAt,
       );

  /// Returns a shallow copy of this [AskMessage]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  AskMessage copyWith({
    Object? id = _Undefined,
    int? sessionId,
    int? seq,
    String? question,
    String? answer,
    String? status,
    Object? errorCode = _Undefined,
    Object? citations = _Undefined,
    Object? modelId = _Undefined,
    bool? fallback,
    Object? projectIds = _Undefined,
    bool? includePersonal,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AskMessage(
      id: id is int? ? id : this.id,
      sessionId: sessionId ?? this.sessionId,
      seq: seq ?? this.seq,
      question: question ?? this.question,
      answer: answer ?? this.answer,
      status: status ?? this.status,
      errorCode: errorCode is String? ? errorCode : this.errorCode,
      citations: citations is List<_i7jy3rkv.Citation>?
          ? citations
          : this.citations?.map((e0) => e0.copyWith()).toList(),
      modelId: modelId is String? ? modelId : this.modelId,
      fallback: fallback ?? this.fallback,
      projectIds: projectIds is List<int>?
          ? projectIds
          : this.projectIds?.map((e0) => e0).toList(),
      includePersonal: includePersonal ?? this.includePersonal,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class AskMessageUpdateTable extends _is.UpdateTable<AskMessageTable> {
  AskMessageUpdateTable(super.table);

  _is.ColumnValue<int, int> sessionId(int value) => _is.ColumnValue(
    table.sessionId,
    value,
  );

  _is.ColumnValue<int, int> seq(int value) => _is.ColumnValue(
    table.seq,
    value,
  );

  _is.ColumnValue<String, String> question(String value) => _is.ColumnValue(
    table.question,
    value,
  );

  _is.ColumnValue<String, String> answer(String value) => _is.ColumnValue(
    table.answer,
    value,
  );

  _is.ColumnValue<String, String> status(String value) => _is.ColumnValue(
    table.status,
    value,
  );

  _is.ColumnValue<String, String> errorCode(String? value) => _is.ColumnValue(
    table.errorCode,
    value,
  );

  _is.ColumnValue<List<_i7jy3rkv.Citation>, List<_i7jy3rkv.Citation>> citations(
    List<_i7jy3rkv.Citation>? value,
  ) => _is.ColumnValue(
    table.citations,
    value,
  );

  _is.ColumnValue<String, String> modelId(String? value) => _is.ColumnValue(
    table.modelId,
    value,
  );

  _is.ColumnValue<bool, bool> fallback(bool value) => _is.ColumnValue(
    table.fallback,
    value,
  );

  _is.ColumnValue<List<int>, List<int>> projectIds(List<int>? value) =>
      _is.ColumnValue(
        table.projectIds,
        value,
      );

  _is.ColumnValue<bool, bool> includePersonal(bool value) => _is.ColumnValue(
    table.includePersonal,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _is.ColumnValue(
        table.createdAt,
        value,
      );

  _is.ColumnValue<DateTime, DateTime> updatedAt(DateTime value) =>
      _is.ColumnValue(
        table.updatedAt,
        value,
      );
}

class AskMessageTable extends _is.Table<int?> {
  AskMessageTable({super.tableRelation}) : super(tableName: 'ask_message') {
    updateTable = AskMessageUpdateTable(this);
    sessionId = _is.ColumnInt(
      'sessionId',
      this,
    );
    seq = _is.ColumnInt(
      'seq',
      this,
    );
    question = _is.ColumnString(
      'question',
      this,
    );
    answer = _is.ColumnString(
      'answer',
      this,
      hasDefault: true,
    );
    status = _is.ColumnString(
      'status',
      this,
    );
    errorCode = _is.ColumnString(
      'errorCode',
      this,
    );
    citations = _is.ColumnSerializable<List<_i7jy3rkv.Citation>>(
      'citations',
      this,
    );
    modelId = _is.ColumnString(
      'modelId',
      this,
    );
    fallback = _is.ColumnBool(
      'fallback',
      this,
      hasDefault: true,
    );
    projectIds = _is.ColumnSerializable<List<int>>(
      'projectIds',
      this,
    );
    includePersonal = _is.ColumnBool(
      'includePersonal',
      this,
      hasDefault: true,
    );
    createdAt = _is.ColumnDateTime(
      'createdAt',
      this,
    );
    updatedAt = _is.ColumnDateTime(
      'updatedAt',
      this,
    );
  }

  late final AskMessageUpdateTable updateTable;

  late final _is.ColumnInt sessionId;

  /// 1-based position in the conversation.
  late final _is.ColumnInt seq;

  late final _is.ColumnString question;

  /// The answer exactly as streamed, [n] markers included.
  late final _is.ColumnString answer;

  /// streaming | done | error | interrupted
  late final _is.ColumnString status;

  /// Short code only (busy, llm, internal). Never an exception message.
  late final _is.ColumnString errorCode;

  late final _is.ColumnSerializable<List<_i7jy3rkv.Citation>> citations;

  /// The model that actually answered.
  late final _is.ColumnString modelId;

  /// The answer came from another model than the one asked for.
  late final _is.ColumnBool fallback;

  /// Scope the question was asked with (after the membership intersection).
  late final _is.ColumnSerializable<List<int>> projectIds;

  late final _is.ColumnBool includePersonal;

  late final _is.ColumnDateTime createdAt;

  /// Last checkpoint while streaming, then the finish time.
  late final _is.ColumnDateTime updatedAt;

  @override
  List<_is.Column> get columns => [
    id,
    sessionId,
    seq,
    question,
    answer,
    status,
    errorCode,
    citations,
    modelId,
    fallback,
    projectIds,
    includePersonal,
    createdAt,
    updatedAt,
  ];
}

class AskMessageInclude extends _is.IncludeObject {
  AskMessageInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => AskMessage.t;
}

class AskMessageIncludeList extends _is.IncludeList {
  AskMessageIncludeList._({
    _is.WhereExpressionBuilder<AskMessageTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(AskMessage.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => AskMessage.t;
}

class AskMessageRepository {
  const AskMessageRepository._();

  /// Returns a list of [AskMessage]s matching the given query parameters.
  ///
  /// Use [where] to specify which items to include in the return value.
  /// If none is specified, all items will be returned.
  ///
  /// To specify the order of the items use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// The maximum number of items can be set by [limit]. If no limit is set,
  /// all items matching the query will be returned.
  ///
  /// [offset] defines how many items to skip, after which [limit] (or all)
  /// items are read from the database.
  ///
  /// ```dart
  /// var persons = await Persons.db.find(
  ///   session,
  ///   where: (t) => t.lastName.equals('Jones'),
  ///   orderBy: (t) => t.firstName,
  ///   limit: 100,
  /// );
  /// ```
  Future<List<AskMessage>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<AskMessageTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<AskMessageTable>? orderBy,
    _is.OrderByListBuilder<AskMessageTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<AskMessage>(
      where: where?.call(AskMessage.t),
      orderBy: orderBy?.call(AskMessage.t),
      orderByList: orderByList?.call(AskMessage.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [AskMessage] matching the given query parameters.
  ///
  /// Use [where] to specify which items to include in the return value.
  /// If none is specified, all items will be returned.
  ///
  /// To specify the order use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// [offset] defines how many items to skip, after which the next one will be picked.
  ///
  /// ```dart
  /// var youngestPerson = await Persons.db.findFirstRow(
  ///   session,
  ///   where: (t) => t.lastName.equals('Jones'),
  ///   orderBy: (t) => t.age,
  /// );
  /// ```
  Future<AskMessage?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<AskMessageTable>? where,
    int? offset,
    _is.OrderByBuilder<AskMessageTable>? orderBy,
    _is.OrderByListBuilder<AskMessageTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<AskMessage>(
      where: where?.call(AskMessage.t),
      orderBy: orderBy?.call(AskMessage.t),
      orderByList: orderByList?.call(AskMessage.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [AskMessage] by its [id] or null if no such row exists.
  Future<AskMessage?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<AskMessage>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [AskMessage]s in the list and returns the inserted rows.
  ///
  /// The returned [AskMessage]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  ///
  /// If [ignoreConflicts] is set to `true`, rows that conflict with existing
  /// rows are silently skipped, and only the successfully inserted rows are
  /// returned.
  ///
  /// If [noReturn] is set to `true`, the inserted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<AskMessage>> insert(
    _is.DatabaseSession session,
    List<AskMessage> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<AskMessage>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [AskMessage] and returns the inserted row.
  ///
  /// The returned [AskMessage] will have its `id` field set.
  Future<AskMessage> insertRow(
    _is.DatabaseSession session,
    AskMessage row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<AskMessage>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [AskMessage]s in the list and returns the resulting rows.
  ///
  /// If a row conflicts on the given [conflictColumns], the existing row is
  /// updated with the new values. Otherwise, a new row is inserted.
  ///
  /// If [updateColumns] is provided, only those columns will be updated on
  /// conflict. If null, all non-conflict, non-id columns are updated.
  ///
  /// If [updateWhere] is provided, the update only applies to rows matching the
  /// given expression. Conflicting rows that don't match are skipped and not
  /// returned, so the resulting list may be shorter than [rows].
  ///
  /// The returned [AskMessage]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<AskMessage>> upsert(
    _is.DatabaseSession session,
    List<AskMessage> rows, {
    required _is.ColumnSelections<AskMessageTable> conflictColumns,
    _is.ColumnSelections<AskMessageTable>? updateColumns,
    _is.WhereExpressionBuilder<AskMessageTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<AskMessage>(
      rows,
      conflictColumns: conflictColumns(AskMessage.t),
      updateColumns: updateColumns?.call(AskMessage.t),
      updateWhere: updateWhere?.call(AskMessage.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [AskMessage] and returns the resulting row.
  ///
  /// If the row conflicts on the given [conflictColumns], the existing row is
  /// updated. Otherwise, a new row is inserted.
  ///
  /// If [updateColumns] is provided, only those columns will be updated on
  /// conflict. If null, all non-conflict, non-id columns are updated.
  ///
  /// If [updateWhere] is provided, the update only applies when the existing
  /// row matches the expression. Returns `null` if no row was affected — for
  /// example when [updateWhere] does not match the conflicting row.
  ///
  /// The returned [AskMessage] will have its `id` field set.
  Future<AskMessage?> upsertRow(
    _is.DatabaseSession session,
    AskMessage row, {
    required _is.ColumnSelections<AskMessageTable> conflictColumns,
    _is.ColumnSelections<AskMessageTable>? updateColumns,
    _is.WhereExpressionBuilder<AskMessageTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<AskMessage>(
      row,
      conflictColumns: conflictColumns(AskMessage.t),
      updateColumns: updateColumns?.call(AskMessage.t),
      updateWhere: updateWhere?.call(AskMessage.t),
      transaction: transaction,
    );
  }

  /// Updates all [AskMessage]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<AskMessage>> update(
    _is.DatabaseSession session,
    List<AskMessage> rows, {
    _is.ColumnSelections<AskMessageTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<AskMessage>(
      rows,
      columns: columns?.call(AskMessage.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [AskMessage]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<AskMessage> updateRow(
    _is.DatabaseSession session,
    AskMessage row, {
    _is.ColumnSelections<AskMessageTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<AskMessage>(
      row,
      columns: columns?.call(AskMessage.t),
      transaction: transaction,
    );
  }

  /// Updates a single [AskMessage] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<AskMessage?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<AskMessageUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<AskMessage>(
      id,
      columnValues: columnValues(AskMessage.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [AskMessage]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<AskMessage>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<AskMessageUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<AskMessageTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<AskMessageTable>? orderBy,
    _is.OrderByListBuilder<AskMessageTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<AskMessage>(
      columnValues: columnValues(AskMessage.t.updateTable),
      where: where(AskMessage.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(AskMessage.t),
      orderByList: orderByList?.call(AskMessage.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [AskMessage]s in the list and returns the deleted rows.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<AskMessage>> delete(
    _is.DatabaseSession session,
    List<AskMessage> rows, {
    _is.OrderByBuilder<AskMessageTable>? orderBy,
    _is.OrderByListBuilder<AskMessageTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<AskMessage>(
      rows,
      orderBy: orderBy?.call(AskMessage.t),
      orderByList: orderByList?.call(AskMessage.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [AskMessage].
  Future<AskMessage> deleteRow(
    _is.DatabaseSession session,
    AskMessage row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<AskMessage>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  ///
  /// To specify the order of the returned rows use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// If [noReturn] is set to `true`, the deleted rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<AskMessage>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<AskMessageTable> where,
    _is.OrderByBuilder<AskMessageTable>? orderBy,
    _is.OrderByListBuilder<AskMessageTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<AskMessage>(
      where: where(AskMessage.t),
      orderBy: orderBy?.call(AskMessage.t),
      orderByList: orderByList?.call(AskMessage.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<AskMessageTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<AskMessage>(
      where: where?.call(AskMessage.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [AskMessage] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<AskMessageTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<AskMessage>(
      where: where(AskMessage.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
