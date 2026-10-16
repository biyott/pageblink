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

/// A note (markdown) or an uploaded PDF. projectId null means personal.
abstract class Document
    implements _is.TableRow<int?>, _is.ProtocolSerialization {
  Document._({
    this.id,
    required this.ownerId,
    this.projectId,
    String? kind,
    required this.title,
    this.body,
    required this.contentHash,
    required this.version,
    required this.pageCount,
    this.storagePath,
    required this.status,
    this.preview,
    this.lastError,
    required this.embeddingModel,
    this.colorIndex,
    required this.createdAt,
    required this.updatedAt,
  }) : kind = kind ?? 'pdf';

  factory Document({
    int? id,
    required _is.UuidValue ownerId,
    int? projectId,
    String? kind,
    required String title,
    String? body,
    required String contentHash,
    required int version,
    required int pageCount,
    String? storagePath,
    required String status,
    String? preview,
    String? lastError,
    required String embeddingModel,
    int? colorIndex,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _DocumentImpl;

  factory Document.fromJson(Map<String, dynamic> jsonSerialization) {
    return Document(
      id: jsonSerialization['id'] as int?,
      ownerId: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['ownerId'],
      ),
      projectId: jsonSerialization['projectId'] as int?,
      kind: jsonSerialization['kind'] as String?,
      title: jsonSerialization['title'] as String,
      body: jsonSerialization['body'] as String?,
      contentHash: jsonSerialization['contentHash'] as String,
      version: jsonSerialization['version'] as int,
      pageCount: jsonSerialization['pageCount'] as int,
      storagePath: jsonSerialization['storagePath'] as String?,
      status: jsonSerialization['status'] as String,
      preview: jsonSerialization['preview'] as String?,
      lastError: jsonSerialization['lastError'] as String?,
      embeddingModel: jsonSerialization['embeddingModel'] as String,
      colorIndex: jsonSerialization['colorIndex'] as int?,
      createdAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      updatedAt: _is.DateTimeJsonExtension.fromJson(
        jsonSerialization['updatedAt'],
      ),
    );
  }

  static final t = DocumentTable();

  static const db = DocumentRepository._();

  @override
  int? id;

  _is.UuidValue ownerId;

  int? projectId;

  /// note | pdf
  String kind;

  String title;

  /// Markdown body for notes; null for PDFs.
  String? body;

  String contentHash;

  int version;

  int pageCount;

  String? storagePath;

  /// uploaded | indexing | ready | failed
  String status;

  /// PDF card text: the start of the first page with real text (about 240
  /// characters). null = not computed yet, '' = tried, nothing readable. Notes: null.
  String? preview;

  /// Why the last indexing failed (shown in the app, cleared on success).
  String? lastError;

  String embeddingModel;

  /// Chosen note card color: index into the app palette (0..7 solid, 8 rainbow), null = auto.
  int? colorIndex;

  DateTime createdAt;

  DateTime updatedAt;

  @override
  _is.Table<int?> get table => t;

  /// Returns a shallow copy of this [Document]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  Document copyWith({
    int? id,
    _is.UuidValue? ownerId,
    int? projectId,
    String? kind,
    String? title,
    String? body,
    String? contentHash,
    int? version,
    int? pageCount,
    String? storagePath,
    String? status,
    String? preview,
    String? lastError,
    String? embeddingModel,
    int? colorIndex,
    DateTime? createdAt,
    DateTime? updatedAt,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Document',
      if (id != null) 'id': id,
      'ownerId': ownerId.toJson(),
      if (projectId != null) 'projectId': projectId,
      'kind': kind,
      'title': title,
      if (body != null) 'body': body,
      'contentHash': contentHash,
      'version': version,
      'pageCount': pageCount,
      if (storagePath != null) 'storagePath': storagePath,
      'status': status,
      if (preview != null) 'preview': preview,
      if (lastError != null) 'lastError': lastError,
      'embeddingModel': embeddingModel,
      if (colorIndex != null) 'colorIndex': colorIndex,
      'createdAt': createdAt.toJson(),
      'updatedAt': updatedAt.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'Document',
      if (id != null) 'id': id,
      'ownerId': ownerId.toJson(),
      if (projectId != null) 'projectId': projectId,
      'kind': kind,
      'title': title,
      if (body != null) 'body': body,
      'contentHash': contentHash,
      'version': version,
      'pageCount': pageCount,
      if (storagePath != null) 'storagePath': storagePath,
      'status': status,
      if (preview != null) 'preview': preview,
      if (lastError != null) 'lastError': lastError,
      'embeddingModel': embeddingModel,
      if (colorIndex != null) 'colorIndex': colorIndex,
      'createdAt': createdAt.toJson(),
      'updatedAt': updatedAt.toJson(),
    };
  }

  static DocumentInclude include() {
    return DocumentInclude._();
  }

  static DocumentIncludeList includeList({
    _is.WhereExpressionBuilder<DocumentTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<DocumentTable>? orderBy,
    _is.OrderByListBuilder<DocumentTable>? orderByList,
    DocumentInclude? include,
  }) {
    return DocumentIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Document.t),
      orderByList: orderByList?.call(Document.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _DocumentImpl extends Document {
  _DocumentImpl({
    int? id,
    required _is.UuidValue ownerId,
    int? projectId,
    String? kind,
    required String title,
    String? body,
    required String contentHash,
    required int version,
    required int pageCount,
    String? storagePath,
    required String status,
    String? preview,
    String? lastError,
    required String embeddingModel,
    int? colorIndex,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : super._(
         id: id,
         ownerId: ownerId,
         projectId: projectId,
         kind: kind,
         title: title,
         body: body,
         contentHash: contentHash,
         version: version,
         pageCount: pageCount,
         storagePath: storagePath,
         status: status,
         preview: preview,
         lastError: lastError,
         embeddingModel: embeddingModel,
         colorIndex: colorIndex,
         createdAt: createdAt,
         updatedAt: updatedAt,
       );

  /// Returns a shallow copy of this [Document]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  @override
  Document copyWith({
    Object? id = _Undefined,
    _is.UuidValue? ownerId,
    Object? projectId = _Undefined,
    String? kind,
    String? title,
    Object? body = _Undefined,
    String? contentHash,
    int? version,
    int? pageCount,
    Object? storagePath = _Undefined,
    String? status,
    Object? preview = _Undefined,
    Object? lastError = _Undefined,
    String? embeddingModel,
    Object? colorIndex = _Undefined,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Document(
      id: id is int? ? id : this.id,
      ownerId: ownerId ?? this.ownerId,
      projectId: projectId is int? ? projectId : this.projectId,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      body: body is String? ? body : this.body,
      contentHash: contentHash ?? this.contentHash,
      version: version ?? this.version,
      pageCount: pageCount ?? this.pageCount,
      storagePath: storagePath is String? ? storagePath : this.storagePath,
      status: status ?? this.status,
      preview: preview is String? ? preview : this.preview,
      lastError: lastError is String? ? lastError : this.lastError,
      embeddingModel: embeddingModel ?? this.embeddingModel,
      colorIndex: colorIndex is int? ? colorIndex : this.colorIndex,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class DocumentUpdateTable extends _is.UpdateTable<DocumentTable> {
  DocumentUpdateTable(super.table);

  _is.ColumnValue<_is.UuidValue, _is.UuidValue> ownerId(_is.UuidValue value) =>
      _is.ColumnValue(
        table.ownerId,
        value,
      );

  _is.ColumnValue<int, int> projectId(int? value) => _is.ColumnValue(
    table.projectId,
    value,
  );

  _is.ColumnValue<String, String> kind(String value) => _is.ColumnValue(
    table.kind,
    value,
  );

  _is.ColumnValue<String, String> title(String value) => _is.ColumnValue(
    table.title,
    value,
  );

  _is.ColumnValue<String, String> body(String? value) => _is.ColumnValue(
    table.body,
    value,
  );

  _is.ColumnValue<String, String> contentHash(String value) => _is.ColumnValue(
    table.contentHash,
    value,
  );

  _is.ColumnValue<int, int> version(int value) => _is.ColumnValue(
    table.version,
    value,
  );

  _is.ColumnValue<int, int> pageCount(int value) => _is.ColumnValue(
    table.pageCount,
    value,
  );

  _is.ColumnValue<String, String> storagePath(String? value) => _is.ColumnValue(
    table.storagePath,
    value,
  );

  _is.ColumnValue<String, String> status(String value) => _is.ColumnValue(
    table.status,
    value,
  );

  _is.ColumnValue<String, String> preview(String? value) => _is.ColumnValue(
    table.preview,
    value,
  );

  _is.ColumnValue<String, String> lastError(String? value) => _is.ColumnValue(
    table.lastError,
    value,
  );

  _is.ColumnValue<String, String> embeddingModel(String value) =>
      _is.ColumnValue(
        table.embeddingModel,
        value,
      );

  _is.ColumnValue<int, int> colorIndex(int? value) => _is.ColumnValue(
    table.colorIndex,
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

class DocumentTable extends _is.Table<int?> {
  DocumentTable({super.tableRelation}) : super(tableName: 'document') {
    updateTable = DocumentUpdateTable(this);
    ownerId = _is.ColumnUuid(
      'ownerId',
      this,
    );
    projectId = _is.ColumnInt(
      'projectId',
      this,
    );
    kind = _is.ColumnString(
      'kind',
      this,
      hasDefault: true,
    );
    title = _is.ColumnString(
      'title',
      this,
    );
    body = _is.ColumnString(
      'body',
      this,
    );
    contentHash = _is.ColumnString(
      'contentHash',
      this,
    );
    version = _is.ColumnInt(
      'version',
      this,
    );
    pageCount = _is.ColumnInt(
      'pageCount',
      this,
    );
    storagePath = _is.ColumnString(
      'storagePath',
      this,
    );
    status = _is.ColumnString(
      'status',
      this,
    );
    preview = _is.ColumnString(
      'preview',
      this,
    );
    lastError = _is.ColumnString(
      'lastError',
      this,
    );
    embeddingModel = _is.ColumnString(
      'embeddingModel',
      this,
    );
    colorIndex = _is.ColumnInt(
      'colorIndex',
      this,
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

  late final DocumentUpdateTable updateTable;

  late final _is.ColumnUuid ownerId;

  late final _is.ColumnInt projectId;

  /// note | pdf
  late final _is.ColumnString kind;

  late final _is.ColumnString title;

  /// Markdown body for notes; null for PDFs.
  late final _is.ColumnString body;

  late final _is.ColumnString contentHash;

  late final _is.ColumnInt version;

  late final _is.ColumnInt pageCount;

  late final _is.ColumnString storagePath;

  /// uploaded | indexing | ready | failed
  late final _is.ColumnString status;

  /// PDF card text: the start of the first page with real text (about 240
  /// characters). null = not computed yet, '' = tried, nothing readable. Notes: null.
  late final _is.ColumnString preview;

  /// Why the last indexing failed (shown in the app, cleared on success).
  late final _is.ColumnString lastError;

  late final _is.ColumnString embeddingModel;

  /// Chosen note card color: index into the app palette (0..7 solid, 8 rainbow), null = auto.
  late final _is.ColumnInt colorIndex;

  late final _is.ColumnDateTime createdAt;

  late final _is.ColumnDateTime updatedAt;

  @override
  List<_is.Column> get columns => [
    id,
    ownerId,
    projectId,
    kind,
    title,
    body,
    contentHash,
    version,
    pageCount,
    storagePath,
    status,
    preview,
    lastError,
    embeddingModel,
    colorIndex,
    createdAt,
    updatedAt,
  ];
}

class DocumentInclude extends _is.IncludeObject {
  DocumentInclude._();

  @override
  Map<String, _is.Include?> get includes => {};

  @override
  _is.Table<int?> get table => Document.t;
}

class DocumentIncludeList extends _is.IncludeList {
  DocumentIncludeList._({
    _is.WhereExpressionBuilder<DocumentTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(Document.t);
  }

  @override
  Map<String, _is.Include?> get includes => include?.includes ?? {};

  @override
  _is.Table<int?> get table => Document.t;
}

class DocumentRepository {
  const DocumentRepository._();

  /// Returns a list of [Document]s matching the given query parameters.
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
  Future<List<Document>> find(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<DocumentTable>? where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<DocumentTable>? orderBy,
    _is.OrderByListBuilder<DocumentTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.find<Document>(
      where: where?.call(Document.t),
      orderBy: orderBy?.call(Document.t),
      orderByList: orderByList?.call(Document.t),
      limit: limit,
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Returns the first matching [Document] matching the given query parameters.
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
  Future<Document?> findFirstRow(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<DocumentTable>? where,
    int? offset,
    _is.OrderByBuilder<DocumentTable>? orderBy,
    _is.OrderByListBuilder<DocumentTable>? orderByList,
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findFirstRow<Document>(
      where: where?.call(Document.t),
      orderBy: orderBy?.call(Document.t),
      orderByList: orderByList?.call(Document.t),
      offset: offset,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Finds a single [Document] by its [id] or null if no such row exists.
  Future<Document?> findById(
    _is.DatabaseSession session,
    int id, {
    _is.Transaction? transaction,
    _is.LockMode? lockMode,
    _is.LockBehavior? lockBehavior,
  }) async {
    return session.db.findById<Document>(
      id,
      transaction: transaction,
      lockMode: lockMode,
      lockBehavior: lockBehavior,
    );
  }

  /// Inserts all [Document]s in the list and returns the inserted rows.
  ///
  /// The returned [Document]s will have their `id` fields set.
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
  Future<List<Document>> insert(
    _is.DatabaseSession session,
    List<Document> rows, {
    _is.Transaction? transaction,
    bool ignoreConflicts = false,
    bool noReturn = false,
  }) async {
    return session.db.insert<Document>(
      rows,
      transaction: transaction,
      ignoreConflicts: ignoreConflicts,
      noReturn: noReturn,
    );
  }

  /// Inserts a single [Document] and returns the inserted row.
  ///
  /// The returned [Document] will have its `id` field set.
  Future<Document> insertRow(
    _is.DatabaseSession session,
    Document row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.insertRow<Document>(
      row,
      transaction: transaction,
    );
  }

  /// Upserts all [Document]s in the list and returns the resulting rows.
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
  /// The returned [Document]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails,
  /// none of the rows will be affected.
  ///
  /// If [noReturn] is set to `true`, the resulting rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Document>> upsert(
    _is.DatabaseSession session,
    List<Document> rows, {
    required _is.ColumnSelections<DocumentTable> conflictColumns,
    _is.ColumnSelections<DocumentTable>? updateColumns,
    _is.WhereExpressionBuilder<DocumentTable>? updateWhere,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.upsert<Document>(
      rows,
      conflictColumns: conflictColumns(Document.t),
      updateColumns: updateColumns?.call(Document.t),
      updateWhere: updateWhere?.call(Document.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Upserts a single [Document] and returns the resulting row.
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
  /// The returned [Document] will have its `id` field set.
  Future<Document?> upsertRow(
    _is.DatabaseSession session,
    Document row, {
    required _is.ColumnSelections<DocumentTable> conflictColumns,
    _is.ColumnSelections<DocumentTable>? updateColumns,
    _is.WhereExpressionBuilder<DocumentTable>? updateWhere,
    _is.Transaction? transaction,
  }) async {
    return session.db.upsertRow<Document>(
      row,
      conflictColumns: conflictColumns(Document.t),
      updateColumns: updateColumns?.call(Document.t),
      updateWhere: updateWhere?.call(Document.t),
      transaction: transaction,
    );
  }

  /// Updates all [Document]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Document>> update(
    _is.DatabaseSession session,
    List<Document> rows, {
    _is.ColumnSelections<DocumentTable>? columns,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.update<Document>(
      rows,
      columns: columns?.call(Document.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Updates a single [Document]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<Document> updateRow(
    _is.DatabaseSession session,
    Document row, {
    _is.ColumnSelections<DocumentTable>? columns,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateRow<Document>(
      row,
      columns: columns?.call(Document.t),
      transaction: transaction,
    );
  }

  /// Updates a single [Document] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<Document?> updateById(
    _is.DatabaseSession session,
    int id, {
    required _is.ColumnValueListBuilder<DocumentUpdateTable> columnValues,
    _is.Transaction? transaction,
  }) async {
    return session.db.updateById<Document>(
      id,
      columnValues: columnValues(Document.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [Document]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  ///
  /// If [noReturn] is set to `true`, the updated rows are not read back from
  /// the database and an empty list is returned. This avoids the overhead of
  /// transferring and deserializing the rows when the result is not needed.
  Future<List<Document>> updateWhere(
    _is.DatabaseSession session, {
    required _is.ColumnValueListBuilder<DocumentUpdateTable> columnValues,
    required _is.WhereExpressionBuilder<DocumentTable> where,
    int? limit,
    int? offset,
    _is.OrderByBuilder<DocumentTable>? orderBy,
    _is.OrderByListBuilder<DocumentTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.updateWhere<Document>(
      columnValues: columnValues(Document.t.updateTable),
      where: where(Document.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Document.t),
      orderByList: orderByList?.call(Document.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes all [Document]s in the list and returns the deleted rows.
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
  Future<List<Document>> delete(
    _is.DatabaseSession session,
    List<Document> rows, {
    _is.OrderByBuilder<DocumentTable>? orderBy,
    _is.OrderByListBuilder<DocumentTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.delete<Document>(
      rows,
      orderBy: orderBy?.call(Document.t),
      orderByList: orderByList?.call(Document.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Deletes a single [Document].
  Future<Document> deleteRow(
    _is.DatabaseSession session,
    Document row, {
    _is.Transaction? transaction,
  }) async {
    return session.db.deleteRow<Document>(
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
  Future<List<Document>> deleteWhere(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<DocumentTable> where,
    _is.OrderByBuilder<DocumentTable>? orderBy,
    _is.OrderByListBuilder<DocumentTable>? orderByList,
    _is.Transaction? transaction,
    bool noReturn = false,
  }) async {
    return session.db.deleteWhere<Document>(
      where: where(Document.t),
      orderBy: orderBy?.call(Document.t),
      orderByList: orderByList?.call(Document.t),
      transaction: transaction,
      noReturn: noReturn,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _is.DatabaseSession session, {
    _is.WhereExpressionBuilder<DocumentTable>? where,
    int? limit,
    _is.Transaction? transaction,
  }) async {
    return session.db.count<Document>(
      where: where?.call(Document.t),
      limit: limit,
      transaction: transaction,
    );
  }

  /// Acquires row-level locks on [Document] rows matching the [where] expression.
  Future<void> lockRows(
    _is.DatabaseSession session, {
    required _is.WhereExpressionBuilder<DocumentTable> where,
    required _is.LockMode lockMode,
    required _is.Transaction transaction,
    _is.LockBehavior lockBehavior = _is.LockBehavior.wait,
  }) async {
    return session.db.lockRows<Document>(
      where: where(Document.t),
      lockMode: lockMode,
      lockBehavior: lockBehavior,
      transaction: transaction,
    );
  }
}
