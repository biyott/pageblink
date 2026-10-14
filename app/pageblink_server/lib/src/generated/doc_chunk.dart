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

/// A searchable chunk of a document with its embedding.
abstract class DocChunk
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  DocChunk._({
    this.id,
    required this.documentId,
    this.projectId,
    required this.ownerId,
    required this.page,
    required this.ordinal,
    required this.text,
    required this.contentHash,
    required this.embedding,
  });

  factory DocChunk({
    int? id,
    required int documentId,
    int? projectId,
    required _is.UuidValue ownerId,
    required int page,
    required int ordinal,
    required String text,
    required String contentHash,
    required _is.Vector embedding,
  }) = _DocChunkImpl;

  factory DocChunk.fromJson(Map<String, dynamic> jsonSerialization) {
    return DocChunk(
      id: jsonSerialization['id'] as int?,
      documentId: jsonSerialization['documentId'] as int,
      projectId: jsonSerialization['projectId'] as int?,
      ownerId: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['ownerId'],
      ),
      page: jsonSerialization['page'] as int,
      ordinal: jsonSerialization['ordinal'] as int,
      text: jsonSerialization['text'] as String,
      contentHash: jsonSerialization['contentHash'] as String,
      embedding: _is.VectorJsonExtension.fromJson(
        jsonSerialization['embedding'],
      ),
    );
  }

  static final t = DocChunkTable();

  static const db = DocChunkRepository._();

  @override
  int? id;

  int documentId;

  /// Denormalized for ACL filtering in the same query as vector search.
  int? projectId;

  _is.UuidValue ownerId;

  int page;

  int ordinal;

  String text;

  String contentHash;

  _is.Vector embedding;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [DocChunk]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  DocChunk copyWith({
    int? id,
    int? documentId,
    int? projectId,
    _is.UuidValue? ownerId,
    int? page,
    int? ordinal,
    String? text,
    String? contentHash,
    _is.Vector? embedding,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'DocChunk',
      if (id != null) 'id': id,
      'documentId': documentId,
      if (projectId != null) 'projectId': projectId,
      'ownerId': ownerId.toJson(),
      'page': page,
      'ordinal': ordinal,
      'text': text,
      'contentHash': contentHash,
      'embedding': embedding.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'DocChunk',
      if (id != null) 'id': id,
      'documentId': documentId,
      if (projectId != null) 'projectId': projectId,
      'ownerId': ownerId.toJson(),
      'page': page,
      'ordinal': ordinal,
      'text': text,
      'contentHash': contentHash,
      'embedding': embedding.toJson(),
    };
  }

  static DocChunkInclude include() {
    return DocChunkInclude._();
  }

  static DocChunkIncludeList includeList({
    _is.WhereExpressionBuilder<DocChunkTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<DocChunkTable>? orderBy,
    _is.OrderByListBuilder<DocChunkTable>? orderByList,
    DocChunkInclude? include,
  }) {
    return DocChunkIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(DocChunk.t),
      orderByList: orderByList?.call(DocChunk.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DocChunkImpl extends DocChunk {
  _DocChunkImpl({
    int? id,
    required int documentId,
    int? projectId,
    required _is.UuidValue ownerId,
    required int page,
    required int ordinal,
    required String text,
    required String contentHash,
    required _is.Vector embedding,
  }) : super._(
         id: id,
         documentId: documentId,
         projectId: projectId,
         ownerId: ownerId,
         page: page,
         ordinal: ordinal,
         text: text,
         contentHash: contentHash,
         embedding: embedding,
       );

  /// Returns a shallow copy of this [DocChunk]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  DocChunk copyWith({
    Object? id = _Undefined,
    int? documentId,
    Object? projectId = _Undefined,
    _is.UuidValue? ownerId,
    int? page,
    int? ordinal,
    String? text,
    String? contentHash,
    _is.Vector? embedding,
  }) {
    return DocChunk(
      id: id is int? ? id : this.id,
      documentId: documentId ?? this.documentId,
      projectId: projectId is int? ? projectId : this.projectId,
      ownerId: ownerId ?? this.ownerId,
      page: page ?? this.page,
      ordinal: ordinal ?? this.ordinal,
      text: text ?? this.text,
      contentHash: contentHash ?? this.contentHash,
      embedding: embedding ?? this.embedding.clone(),
    );
  }
}

class DocChunkUpdateTable extends _is.UpdateTable<DocChunkTable> {
  DocChunkUpdateTable(super.table);

  _is.ColumnValue<int, int> documentId(int value) => _is.ColumnValue(
    table.documentId,
    value,
  );

  _is.ColumnValue<int, int> projectId(int? value) => _is.ColumnValue(
    table.projectId,
    value,
  );

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> ownerId(_is.UuidValue value) =>
      _is.ColumnValue(
        table.ownerId,
        value,
      );

  _is.ColumnValue<int, int> page(int value) => _is.ColumnValue(
    table.page,
    value,
  );

  _is.ColumnValue<int, int> ordinal(int value) => _is.ColumnValue(
    table.ordinal,
    value,
  );

  _is.ColumnValue<String, String> text(String value) => _is.ColumnValue(
    table.text,
    value,
  );

  _is.ColumnValue<String, String> contentHash(String value) => _is.ColumnValue(
    table.contentHash,
    value,
  );

  _is.ColumnValue<_is.Vector, _is.Vector> embedding(_is.Vector value) =>
      _is.ColumnValue(
        table.embedding,
        value,
      );
}

class DocChunkTable extends _is.Table<int?> {
  DocChunkTable({super.tableRelation}) : super(tableName: 'doc_chunk') {
    updateTable = DocChunkUpdateTable(this);
    documentId = _is.ColumnInt(
      'documentId',
      this,
    );
    projectId = _is.ColumnInt(
      'projectId',
      this,
    );
    ownerId = _is.ColumnUuid(
      'ownerId',
      this,
    );
    page = _is.ColumnInt(
      'page',
      this,
    );
    ordinal = _is.ColumnInt(
      'ordinal',
      this,
    );
    text = _is.ColumnString(
      'text',
      this,
    );
    contentHash = _is.ColumnString(
      'contentHash',
      this,
    );
    embedding = _is.ColumnVector(
      'embedding',
      this,
      dimension: 768,
    );
  }

  late final DocChunkUpdateTable updateTable;

  late final _is.ColumnInt documentId;

  /// Denormalized for ACL filtering in the same query as vector search.
  late final _is.ColumnInt projectId;

  late final _is.ColumnUuid ownerId;

  late final _is.ColumnInt page;

  late final _is.ColumnInt ordinal;

  late final _is.ColumnString text;

  late final _is.ColumnString contentHash;

  late final _is.ColumnVector embedding;

  @override
  List<_is.Column> get columns => [
    id,
    documentId,
    projectId,
    ownerId,
    page,
    ordinal,
    text,
    contentHash,
    embedding,
  ];
}

class DocChunkInclude extends _is.IncludeObject {
  DocChunkInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => DocChunk.t;
}

class DocChunkIncludeList extends _is.IncludeList {
  DocChunkIncludeList._({
    _is.WhereExpressionBuilder<DocChunkTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(DocChunk.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => DocChunk.t;
}

class DocChunkRepository {
  const DocChunkRepository._();

  /// Returns a list of [DocChunk]s matching the given query parameters.
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
  Future<List<DocChunk>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<DocChunkTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<DocChunkTable>? orderBy,
    _is.OrderByListBuilder<DocChunkTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<DocChunk>(
      where: where?.call(DocChunk.t),
      orderBy: orderBy?.call(DocChunk.t),
      orderByList: orderByList?.call(DocChunk.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [DocChunk] matching the given query parameters.
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
  Future<DocChunk?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<DocChunkTable>? where,
    int? offset,
    _is.OrderByBuilder<DocChunkTable>? orderBy,
    _is.OrderByListBuilder<DocChunkTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<DocChunk>(
      where: where?.call(DocChunk.t),
      orderBy: orderBy?.call(DocChunk.t),
      orderByList: orderByList?.call(DocChunk.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [DocChunk] by its [id] or null if no such row exists.
  Future<DocChunk?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<DocChunk>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [DocChunk]s in the list and returns the inserted rows.
  ///
  /// The returned [DocChunk]s will have their `id` fields set.
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
  Future<List<DocChunk>> insert(
    _is.DatabaseSession session,
    List<DocChunk> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<DocChunk>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [DocChunk] and returns the inserted row.
  ///
  /// The returned [DocChunk] will have its `id` field set.
  Future<DocChunk> insertRow(
    _is.DatabaseSession session,
    DocChunk row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<DocChunk>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [DocChunk]s in the list and returns the resulting rows.
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
  /// The returned [DocChunk]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<DocChunk>> upsert(
    _is.DatabaseSession session,
    List<DocChunk> rows, {
    required _is.ColumnSelections<DocChunkTable> conflictColumns,
    _is.ColumnSelections<DocChunkTable>? updateColumns,
    _is.WhereExpressionBuilder<DocChunkTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<DocChunk>(
      rows,
      conflictColumns: conflictColumns(DocChunk.t),
      updateColumns: updateColumns?.call(DocChunk.t),
      updateWhere: updateWhere?.call(DocChunk.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [DocChunk] and returns the resulting row.
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
  /// The returned [DocChunk] will have its `id` field set.
  Future<DocChunk?> upsertRow(
    _is.DatabaseSession session,
    DocChunk row, {
    required _is.ColumnSelections<DocChunkTable> conflictColumns,
    _is.ColumnSelections<DocChunkTable>? updateColumns,
    _is.WhereExpressionBuilder<DocChunkTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<DocChunk>(
      row,
      conflictColumns: conflictColumns(DocChunk.t),
      updateColumns: updateColumns?.call(DocChunk.t),
      updateWhere: updateWhere?.call(DocChunk.t),
      transaction: transaction,
    );
  }

  /// Updates all [DocChunk]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<DocChunk>> update(
    _is.DatabaseSession session,
    List<DocChunk> rows, {
    _is.ColumnSelections<DocChunkTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<DocChunk>(
      rows,
      columns: columns?.call(DocChunk.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [DocChunk]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<DocChunk> updateRow(
    _is.DatabaseSession session,
    DocChunk row, {
    _is.ColumnSelections<DocChunkTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<DocChunk>(
      row,
      columns: columns?.call(DocChunk.t),
      transaction: transaction,
    );
  }

  /// Updates a single [DocChunk] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<DocChunk?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<DocChunkUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<DocChunk>(
      id,
      columnValues: columnValues(DocChunk.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [DocChunk]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<DocChunk>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<DocChunkUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<DocChunkTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<DocChunkTable>? orderBy,
    _is.OrderByListBuilder<DocChunkTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<DocChunk>(
      columnValues: columnValues(DocChunk.t.updateTable),
      where: where(DocChunk.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(DocChunk.t),
      orderByList: orderByList?.call(DocChunk.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [DocChunk]s in the list and returns the deleted rows.
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
  Future<List<DocChunk>> delete(
    _is.DatabaseSession session,
    List<DocChunk> rows, {
    _is.OrderByBuilder<DocChunkTable>? orderBy,
    _is.OrderByListBuilder<DocChunkTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<DocChunk>(
      rows,
      orderBy: orderBy?.call(DocChunk.t),
      orderByList: orderByList?.call(DocChunk.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [DocChunk].
  Future<DocChunk> deleteRow(
    _is.DatabaseSession session,
    DocChunk row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<DocChunk>(
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
  Future<List<DocChunk>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<DocChunkTable> where,
    _is.OrderByBuilder<DocChunkTable>? orderBy,
    _is.OrderByListBuilder<DocChunkTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<DocChunk>(
      where: where(DocChunk.t),
      orderBy: orderBy?.call(DocChunk.t),
      orderByList: orderByList?.call(DocChunk.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<DocChunkTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<DocChunk>(
      where: where?.call(DocChunk.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [DocChunk] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<DocChunkTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<DocChunk>(
      where: where(DocChunk.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
