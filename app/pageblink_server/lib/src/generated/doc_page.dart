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

/// Raw text of one page (PDF) or the whole note, kept so failed or stale
/// documents can be re-indexed without re-uploading.
abstract class DocPage
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  DocPage._({
    this.id,
    required this.documentId,
    required this.page,
    required this.text,
  });

  factory DocPage({
    int? id,
    required int documentId,
    required int page,
    required String text,
  }) = _DocPageImpl;

  factory DocPage.fromJson(Map<String, dynamic> jsonSerialization) {
    return DocPage(
      id: jsonSerialization['id'] as int?,
      documentId: jsonSerialization['documentId'] as int,
      page: jsonSerialization['page'] as int,
      text: jsonSerialization['text'] as String,
    );
  }

  static final t = DocPageTable();

  static const db = DocPageRepository._();

  @override
  int? id;

  int documentId;

  int page;

  String text;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [DocPage]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  DocPage copyWith({
    int? id,
    int? documentId,
    int? page,
    String? text,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DocPage',
      if (id != null) 'id': id,
      'documentId': documentId,
      'page': page,
      'text': text,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'DocPage',
      if (id != null) 'id': id,
      'documentId': documentId,
      'page': page,
      'text': text,
    };
  }

  static DocPageInclude include() {
    return DocPageInclude._();
  }

  static DocPageIncludeList includeList({
    _is.WhereExpressionBuilder<DocPageTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<DocPageTable>? orderBy,
    _is.OrderByListBuilder<DocPageTable>? orderByList,
    DocPageInclude? include,
  }) {
    return DocPageIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(DocPage.t),
      orderByList: orderByList?.call(DocPage.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DocPageImpl extends DocPage {
  _DocPageImpl({
    int? id,
    required int documentId,
    required int page,
    required String text,
  }) : super._(
         id: id,
         documentId: documentId,
         page: page,
         text: text,
       );

  /// Returns a shallow copy of this [DocPage]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  DocPage copyWith({
    Object? id = _Undefined,
    int? documentId,
    int? page,
    String? text,
  }) {
    return DocPage(
      id: id is int? ? id : this.id,
      documentId: documentId ?? this.documentId,
      page: page ?? this.page,
      text: text ?? this.text,
    );
  }
}

class DocPageUpdateTable extends _is.UpdateTable<DocPageTable> {
  DocPageUpdateTable(super.table);

  _is.ColumnValue<int, int> documentId(int value) => _is.ColumnValue(
    table.documentId,
    value,
  );

  _is.ColumnValue<int, int> page(int value) => _is.ColumnValue(
    table.page,
    value,
  );

  _is.ColumnValue<String, String> text(String value) => _is.ColumnValue(
    table.text,
    value,
  );
}

class DocPageTable extends _is.Table<int?> {
  DocPageTable({super.tableRelation}) : super(tableName: 'doc_page') {
    updateTable = DocPageUpdateTable(this);
    documentId = _is.ColumnInt(
      'documentId',
      this,
    );
    page = _is.ColumnInt(
      'page',
      this,
    );
    text = _is.ColumnString(
      'text',
      this,
    );
  }

  late final DocPageUpdateTable updateTable;

  late final _is.ColumnInt documentId;

  late final _is.ColumnInt page;

  late final _is.ColumnString text;

  @override
  List<_is.Column> get columns => [
    id,
    documentId,
    page,
    text,
  ];
}

class DocPageInclude extends _is.IncludeObject {
  DocPageInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => DocPage.t;
}

class DocPageIncludeList extends _is.IncludeList {
  DocPageIncludeList._({
    _is.WhereExpressionBuilder<DocPageTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(DocPage.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => DocPage.t;
}

class DocPageRepository {
  const DocPageRepository._();

  /// Returns a list of [DocPage]s matching the given query parameters.
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
  Future<List<DocPage>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<DocPageTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<DocPageTable>? orderBy,
    _is.OrderByListBuilder<DocPageTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<DocPage>(
      where: where?.call(DocPage.t),
      orderBy: orderBy?.call(DocPage.t),
      orderByList: orderByList?.call(DocPage.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [DocPage] matching the given query parameters.
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
  Future<DocPage?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<DocPageTable>? where,
    int? offset,
    _is.OrderByBuilder<DocPageTable>? orderBy,
    _is.OrderByListBuilder<DocPageTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<DocPage>(
      where: where?.call(DocPage.t),
      orderBy: orderBy?.call(DocPage.t),
      orderByList: orderByList?.call(DocPage.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [DocPage] by its [id] or null if no such row exists.
  Future<DocPage?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<DocPage>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [DocPage]s in the list and returns the inserted rows.
  ///
  /// The returned [DocPage]s will have their `id` fields set.
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
  Future<List<DocPage>> insert(
    _is.DatabaseSession session,
    List<DocPage> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<DocPage>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [DocPage] and returns the inserted row.
  ///
  /// The returned [DocPage] will have its `id` field set.
  Future<DocPage> insertRow(
    _is.DatabaseSession session,
    DocPage row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<DocPage>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [DocPage]s in the list and returns the resulting rows.
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
  /// The returned [DocPage]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<DocPage>> upsert(
    _is.DatabaseSession session,
    List<DocPage> rows, {
    required _is.ColumnSelections<DocPageTable> conflictColumns,
    _is.ColumnSelections<DocPageTable>? updateColumns,
    _is.WhereExpressionBuilder<DocPageTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<DocPage>(
      rows,
      conflictColumns: conflictColumns(DocPage.t),
      updateColumns: updateColumns?.call(DocPage.t),
      updateWhere: updateWhere?.call(DocPage.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [DocPage] and returns the resulting row.
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
  /// The returned [DocPage] will have its `id` field set.
  Future<DocPage?> upsertRow(
    _is.DatabaseSession session,
    DocPage row, {
    required _is.ColumnSelections<DocPageTable> conflictColumns,
    _is.ColumnSelections<DocPageTable>? updateColumns,
    _is.WhereExpressionBuilder<DocPageTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<DocPage>(
      row,
      conflictColumns: conflictColumns(DocPage.t),
      updateColumns: updateColumns?.call(DocPage.t),
      updateWhere: updateWhere?.call(DocPage.t),
      transaction: transaction,
    );
  }

  /// Updates all [DocPage]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<DocPage>> update(
    _is.DatabaseSession session,
    List<DocPage> rows, {
    _is.ColumnSelections<DocPageTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<DocPage>(
      rows,
      columns: columns?.call(DocPage.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [DocPage]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<DocPage> updateRow(
    _is.DatabaseSession session,
    DocPage row, {
    _is.ColumnSelections<DocPageTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<DocPage>(
      row,
      columns: columns?.call(DocPage.t),
      transaction: transaction,
    );
  }

  /// Updates a single [DocPage] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<DocPage?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<DocPageUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<DocPage>(
      id,
      columnValues: columnValues(DocPage.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [DocPage]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<DocPage>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<DocPageUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<DocPageTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<DocPageTable>? orderBy,
    _is.OrderByListBuilder<DocPageTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<DocPage>(
      columnValues: columnValues(DocPage.t.updateTable),
      where: where(DocPage.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(DocPage.t),
      orderByList: orderByList?.call(DocPage.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [DocPage]s in the list and returns the deleted rows.
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
  Future<List<DocPage>> delete(
    _is.DatabaseSession session,
    List<DocPage> rows, {
    _is.OrderByBuilder<DocPageTable>? orderBy,
    _is.OrderByListBuilder<DocPageTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<DocPage>(
      rows,
      orderBy: orderBy?.call(DocPage.t),
      orderByList: orderByList?.call(DocPage.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [DocPage].
  Future<DocPage> deleteRow(
    _is.DatabaseSession session,
    DocPage row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<DocPage>(
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
  Future<List<DocPage>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<DocPageTable> where,
    _is.OrderByBuilder<DocPageTable>? orderBy,
    _is.OrderByListBuilder<DocPageTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<DocPage>(
      where: where(DocPage.t),
      orderBy: orderBy?.call(DocPage.t),
      orderByList: orderByList?.call(DocPage.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<DocPageTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<DocPage>(
      where: where?.call(DocPage.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [DocPage] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<DocPageTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<DocPage>(
      where: where(DocPage.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
