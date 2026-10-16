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
import 'package:serverpod/serverpod.dart' as _is;

/// One Ask conversation. Server only: the app gets AskSessionView instead.
abstract class AskSession
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  AskSession._({
    this.id,
    required this.ownerId,
    this.visitorKeyHash,
    bool? isDemo,
    required this.title,
    this.locale,
    int? questionCount,
    required this.createdAt,
    required this.lastActiveAt,
    this.streamingSince,
    this.hiddenAt,
  }) : isDemo = isDemo ?? false,
       questionCount = questionCount ?? 0;

  factory AskSession({
    int? id,
    required _is.UuidValue ownerId,
    String? visitorKeyHash,
    bool? isDemo,
    required String title,
    String? locale,
    int? questionCount,
    required DateTime createdAt,
    required DateTime lastActiveAt,
    DateTime? streamingSince,
    DateTime? hiddenAt,
  }) = _AskSessionImpl;

  factory AskSession.fromJson(Map<String, dynamic> jsonSerialization) {
    return AskSession(
      id: jsonSerialization['id'] as int?,
      ownerId: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['ownerId'],
      ),
      visitorKeyHash: jsonSerialization['visitorKeyHash'] as String?,
      isDemo: jsonSerialization['isDemo'] == null
          ? null
          : _is.BoolJsonExtension.fromJson(jsonSerialization['isDemo']),
      title: jsonSerialization['title'] as String,
      locale: jsonSerialization['locale'] as String?,
      questionCount: jsonSerialization['questionCount'] as int?,
      createdAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      lastActiveAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['lastActiveAt'],
      ),
      streamingSince: jsonSerialization['streamingSince'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(
              jsonSerialization['streamingSince'],
            ),
      hiddenAt: jsonSerialization['hiddenAt'] == null
          ? null
          : _is.DateTimeJsonExtension.fromJson(jsonSerialization['hiddenAt']),
    );
  }

  static final t = AskSessionTable();

  static const db = AskSessionRepository._();

  @override
  int? id;

  /// Authenticated user. Demo accounts are shared by many visitors.
  _is.UuidValue ownerId;

  /// SHA-256 hex of the browser's visitor key. Demo accounts only.
  String? visitorKeyHash;

  bool isDemo;

  /// First question, shortened to 80 characters.
  String title;

  /// UI language of the first question (ko | en), for the admin list.
  String? locale;

  /// Questions asked so far (display; the message rows are the truth).
  int questionCount;

  DateTime createdAt;

  /// Last question received, checkpoint or answer finished. Drives the
  /// 30-minute list, the 30-second resume rule and the retention purge.
  DateTime lastActiveAt;

  /// Set while an answer streams; the gate for "one question at a time".
  DateTime? streamingSince;

  /// Hidden from the user's lists (legacy-client rows, user "delete").
  /// Still kept for the retention period.
  DateTime? hiddenAt;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [AskSession]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  AskSession copyWith({
    int? id,
    _is.UuidValue? ownerId,
    String? visitorKeyHash,
    bool? isDemo,
    String? title,
    String? locale,
    int? questionCount,
    DateTime? createdAt,
    DateTime? lastActiveAt,
    DateTime? streamingSince,
    DateTime? hiddenAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'AskSession',
      if (id != null) 'id': id,
      'ownerId': ownerId.toJson(),
      if (visitorKeyHash != null) 'visitorKeyHash': visitorKeyHash,
      'isDemo': isDemo,
      'title': title,
      if (locale != null) 'locale': locale,
      'questionCount': questionCount,
      'createdAt': createdAt.toJson(),
      'lastActiveAt': lastActiveAt.toJson(),
      if (streamingSince != null) 'streamingSince': streamingSince?.toJson(),
      if (hiddenAt != null) 'hiddenAt': hiddenAt?.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  static AskSessionInclude include() {
    return AskSessionInclude._();
  }

  static AskSessionIncludeList includeList({
    _is.WhereExpressionBuilder<AskSessionTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<AskSessionTable>? orderBy,
    _is.OrderByListBuilder<AskSessionTable>? orderByList,
    AskSessionInclude? include,
  }) {
    return AskSessionIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(AskSession.t),
      orderByList: orderByList?.call(AskSession.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _AskSessionImpl extends AskSession {
  _AskSessionImpl({
    int? id,
    required _is.UuidValue ownerId,
    String? visitorKeyHash,
    bool? isDemo,
    required String title,
    String? locale,
    int? questionCount,
    required DateTime createdAt,
    required DateTime lastActiveAt,
    DateTime? streamingSince,
    DateTime? hiddenAt,
  }) : super._(
         id: id,
         ownerId: ownerId,
         visitorKeyHash: visitorKeyHash,
         isDemo: isDemo,
         title: title,
         locale: locale,
         questionCount: questionCount,
         createdAt: createdAt,
         lastActiveAt: lastActiveAt,
         streamingSince: streamingSince,
         hiddenAt: hiddenAt,
       );

  /// Returns a shallow copy of this [AskSession]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  AskSession copyWith({
    Object? id = _Undefined,
    _is.UuidValue? ownerId,
    Object? visitorKeyHash = _Undefined,
    bool? isDemo,
    String? title,
    Object? locale = _Undefined,
    int? questionCount,
    DateTime? createdAt,
    DateTime? lastActiveAt,
    Object? streamingSince = _Undefined,
    Object? hiddenAt = _Undefined,
  }) {
    return AskSession(
      id: id is int? ? id : this.id,
      ownerId: ownerId ?? this.ownerId,
      visitorKeyHash: visitorKeyHash is String?
          ? visitorKeyHash
          : this.visitorKeyHash,
      isDemo: isDemo ?? this.isDemo,
      title: title ?? this.title,
      locale: locale is String? ? locale : this.locale,
      questionCount: questionCount ?? this.questionCount,
      createdAt: createdAt ?? this.createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      streamingSince: streamingSince is DateTime?
          ? streamingSince
          : this.streamingSince,
      hiddenAt: hiddenAt is DateTime? ? hiddenAt : this.hiddenAt,
    );
  }
}

class AskSessionUpdateTable extends _is.UpdateTable<AskSessionTable> {
  AskSessionUpdateTable(super.table);

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> ownerId(_is.UuidValue value) =>
      _is.ColumnValue(
        table.ownerId,
        value,
      );

  _is.ColumnValue<String, String> visitorKeyHash(String? value) =>
      _is.ColumnValue(
        table.visitorKeyHash,
        value,
      );

  _is.ColumnValue<bool, bool> isDemo(bool value) => _is.ColumnValue(
    table.isDemo,
    value,
  );

  _is.ColumnValue<String, String> title(String value) => _is.ColumnValue(
    table.title,
    value,
  );

  _is.ColumnValue<String, String> locale(String? value) => _is.ColumnValue(
    table.locale,
    value,
  );

  _is.ColumnValue<int, int> questionCount(int value) => _is.ColumnValue(
    table.questionCount,
    value,
  );

  _is.ColumnValue<DateTime, DateTime> createdAt(DateTime value) =>
      _is.ColumnValue(
        table.createdAt,
        value,
      );

  _is.ColumnValue<DateTime, DateTime> lastActiveAt(DateTime value) =>
      _is.ColumnValue(
        table.lastActiveAt,
        value,
      );

  _is.ColumnValue<DateTime, DateTime> streamingSince(DateTime? value) =>
      _is.ColumnValue(
        table.streamingSince,
        value,
      );

  _is.ColumnValue<DateTime, DateTime> hiddenAt(DateTime? value) =>
      _is.ColumnValue(
        table.hiddenAt,
        value,
      );
}

class AskSessionTable extends _is.Table<int?> {
  AskSessionTable({super.tableRelation}) : super(tableName: 'ask_session') {
    updateTable = AskSessionUpdateTable(this);
    ownerId = _is.ColumnUuid(
      'ownerId',
      this,
    );
    visitorKeyHash = _is.ColumnString(
      'visitorKeyHash',
      this,
    );
    isDemo = _is.ColumnBool(
      'isDemo',
      this,
      hasDefault: true,
    );
    title = _is.ColumnString(
      'title',
      this,
    );
    locale = _is.ColumnString(
      'locale',
      this,
    );
    questionCount = _is.ColumnInt(
      'questionCount',
      this,
      hasDefault: true,
    );
    createdAt = _is.ColumnDateTime(
      'createdAt',
      this,
    );
    lastActiveAt = _is.ColumnDateTime(
      'lastActiveAt',
      this,
    );
    streamingSince = _is.ColumnDateTime(
      'streamingSince',
      this,
    );
    hiddenAt = _is.ColumnDateTime(
      'hiddenAt',
      this,
    );
  }

  late final AskSessionUpdateTable updateTable;

  /// Authenticated user. Demo accounts are shared by many visitors.
  late final _is.ColumnUuid ownerId;

  /// SHA-256 hex of the browser's visitor key. Demo accounts only.
  late final _is.ColumnString visitorKeyHash;

  late final _is.ColumnBool isDemo;

  /// First question, shortened to 80 characters.
  late final _is.ColumnString title;

  /// UI language of the first question (ko | en), for the admin list.
  late final _is.ColumnString locale;

  /// Questions asked so far (display; the message rows are the truth).
  late final _is.ColumnInt questionCount;

  late final _is.ColumnDateTime createdAt;

  /// Last question received, checkpoint or answer finished. Drives the
  /// 30-minute list, the 30-second resume rule and the retention purge.
  late final _is.ColumnDateTime lastActiveAt;

  /// Set while an answer streams; the gate for "one question at a time".
  late final _is.ColumnDateTime streamingSince;

  /// Hidden from the user's lists (legacy-client rows, user "delete").
  /// Still kept for the retention period.
  late final _is.ColumnDateTime hiddenAt;

  @override
  List<_is.Column> get columns => [
    id,
    ownerId,
    visitorKeyHash,
    isDemo,
    title,
    locale,
    questionCount,
    createdAt,
    lastActiveAt,
    streamingSince,
    hiddenAt,
  ];
}

class AskSessionInclude extends _is.IncludeObject {
  AskSessionInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => AskSession.t;
}

class AskSessionIncludeList extends _is.IncludeList {
  AskSessionIncludeList._({
    _is.WhereExpressionBuilder<AskSessionTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(AskSession.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => AskSession.t;
}

class AskSessionRepository {
  const AskSessionRepository._();

  /// Returns a list of [AskSession]s matching the given query parameters.
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
  Future<List<AskSession>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<AskSessionTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<AskSessionTable>? orderBy,
    _is.OrderByListBuilder<AskSessionTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<AskSession>(
      where: where?.call(AskSession.t),
      orderBy: orderBy?.call(AskSession.t),
      orderByList: orderByList?.call(AskSession.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [AskSession] matching the given query parameters.
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
  Future<AskSession?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<AskSessionTable>? where,
    int? offset,
    _is.OrderByBuilder<AskSessionTable>? orderBy,
    _is.OrderByListBuilder<AskSessionTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<AskSession>(
      where: where?.call(AskSession.t),
      orderBy: orderBy?.call(AskSession.t),
      orderByList: orderByList?.call(AskSession.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [AskSession] by its [id] or null if no such row exists.
  Future<AskSession?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<AskSession>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [AskSession]s in the list and returns the inserted rows.
  ///
  /// The returned [AskSession]s will have their `id` fields set.
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
  Future<List<AskSession>> insert(
    _is.DatabaseSession session,
    List<AskSession> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<AskSession>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [AskSession] and returns the inserted row.
  ///
  /// The returned [AskSession] will have its `id` field set.
  Future<AskSession> insertRow(
    _is.DatabaseSession session,
    AskSession row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<AskSession>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [AskSession]s in the list and returns the resulting rows.
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
  /// The returned [AskSession]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<AskSession>> upsert(
    _is.DatabaseSession session,
    List<AskSession> rows, {
    required _is.ColumnSelections<AskSessionTable> conflictColumns,
    _is.ColumnSelections<AskSessionTable>? updateColumns,
    _is.WhereExpressionBuilder<AskSessionTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<AskSession>(
      rows,
      conflictColumns: conflictColumns(AskSession.t),
      updateColumns: updateColumns?.call(AskSession.t),
      updateWhere: updateWhere?.call(AskSession.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [AskSession] and returns the resulting row.
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
  /// The returned [AskSession] will have its `id` field set.
  Future<AskSession?> upsertRow(
    _is.DatabaseSession session,
    AskSession row, {
    required _is.ColumnSelections<AskSessionTable> conflictColumns,
    _is.ColumnSelections<AskSessionTable>? updateColumns,
    _is.WhereExpressionBuilder<AskSessionTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<AskSession>(
      row,
      conflictColumns: conflictColumns(AskSession.t),
      updateColumns: updateColumns?.call(AskSession.t),
      updateWhere: updateWhere?.call(AskSession.t),
      transaction: transaction,
    );
  }

  /// Updates all [AskSession]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<AskSession>> update(
    _is.DatabaseSession session,
    List<AskSession> rows, {
    _is.ColumnSelections<AskSessionTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<AskSession>(
      rows,
      columns: columns?.call(AskSession.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [AskSession]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<AskSession> updateRow(
    _is.DatabaseSession session,
    AskSession row, {
    _is.ColumnSelections<AskSessionTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<AskSession>(
      row,
      columns: columns?.call(AskSession.t),
      transaction: transaction,
    );
  }

  /// Updates a single [AskSession] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<AskSession?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<AskSessionUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<AskSession>(
      id,
      columnValues: columnValues(AskSession.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [AskSession]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<AskSession>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<AskSessionUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<AskSessionTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<AskSessionTable>? orderBy,
    _is.OrderByListBuilder<AskSessionTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<AskSession>(
      columnValues: columnValues(AskSession.t.updateTable),
      where: where(AskSession.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(AskSession.t),
      orderByList: orderByList?.call(AskSession.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [AskSession]s in the list and returns the deleted rows.
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
  Future<List<AskSession>> delete(
    _is.DatabaseSession session,
    List<AskSession> rows, {
    _is.OrderByBuilder<AskSessionTable>? orderBy,
    _is.OrderByListBuilder<AskSessionTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<AskSession>(
      rows,
      orderBy: orderBy?.call(AskSession.t),
      orderByList: orderByList?.call(AskSession.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [AskSession].
  Future<AskSession> deleteRow(
    _is.DatabaseSession session,
    AskSession row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<AskSession>(
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
  Future<List<AskSession>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<AskSessionTable> where,
    _is.OrderByBuilder<AskSessionTable>? orderBy,
    _is.OrderByListBuilder<AskSessionTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<AskSession>(
      where: where(AskSession.t),
      orderBy: orderBy?.call(AskSession.t),
      orderByList: orderByList?.call(AskSession.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<AskSessionTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<AskSession>(
      where: where?.call(AskSession.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [AskSession] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<AskSessionTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<AskSession>(
      where: where(AskSession.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
