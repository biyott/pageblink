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
import 'dart:async' as _ida;
import 'package:http/http.dart' as _i85jenna;
import 'package:pageblink_client/src/protocol/answer_event.dart' as _iv9ukj64;
import 'package:pageblink_client/src/protocol/ask_admin_filter.dart'
    as _ihxjv8go;
import 'package:pageblink_client/src/protocol/ask_admin_page.dart' as _ifeoh06a;
import 'package:pageblink_client/src/protocol/ask_history_status.dart'
    as _iq117uuo;
import 'package:pageblink_client/src/protocol/ask_restore.dart' as _isr923wh;
import 'package:pageblink_client/src/protocol/ask_session_view.dart'
    as _ii1ulf7a;
import 'package:pageblink_client/src/protocol/demo_status.dart' as _ic49xm8h;
import 'package:pageblink_client/src/protocol/document.dart' as _ix72owx0;
import 'package:pageblink_client/src/protocol/greetings/greeting.dart'
    as _ibcu9c6c;
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
import 'protocol.dart' as _il2as5qe;

/// By extending [EmailIdpBaseEndpoint], the email identity provider endpoints
/// are made available on the server and enable the corresponding sign-in widget
/// on the client.
/// {@category Endpoint}
class EndpointEmailIdp extends _iaic.EndpointEmailIdpBase {
  EndpointEmailIdp(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'emailIdp';

  /// Logs in the user and returns a new session.
  ///
  /// Throws an [EmailAccountLoginException] in case of errors, with reason:
  /// - [EmailAccountLoginExceptionReason.invalidCredentials] if the email or
  ///   password is incorrect.
  /// - [EmailAccountLoginExceptionReason.tooManyAttempts] if there have been
  ///   too many failed login attempts.
  ///
  /// Throws an [AuthUserBlockedException] if the auth user is blocked.
  @override
  _ida.Future<_iacc.AuthSuccess> login({
    required String email,
    required String password,
  }) => caller.callServerEndpoint<_iacc.AuthSuccess>(
    'emailIdp',
    'login',
    {
      'email': email,
      'password': password,
    },
  );

  /// Starts the registration for a new user account with an email-based login
  /// associated to it.
  ///
  /// Upon successful completion of this method, an email will have been
  /// sent to [email] with a verification link, which the user must open to
  /// complete the registration.
  ///
  /// Always returns a account request ID, which can be used to complete the
  /// registration. If the email is already registered, the returned ID will not
  /// be valid.
  @override
  _ida.Future<_isc.UuidValue> startRegistration({required String email}) =>
      caller.callServerEndpoint<_isc.UuidValue>(
        'emailIdp',
        'startRegistration',
        {'email': email},
      );

  /// Verifies an account request code and returns a token
  /// that can be used to complete the account creation.
  ///
  /// Throws an [EmailAccountRequestException] in case of errors, with reason:
  /// - [EmailAccountRequestExceptionReason.expired] if the account request has
  ///   already expired.
  /// - [EmailAccountRequestExceptionReason.policyViolation] if the password
  ///   does not comply with the password policy.
  /// - [EmailAccountRequestExceptionReason.invalid] if no request exists
  ///   for the given [accountRequestId] or [verificationCode] is invalid.
  @override
  _ida.Future<String> verifyRegistrationCode({
    required _isc.UuidValue accountRequestId,
    required String verificationCode,
  }) => caller.callServerEndpoint<String>(
    'emailIdp',
    'verifyRegistrationCode',
    {
      'accountRequestId': accountRequestId,
      'verificationCode': verificationCode,
    },
  );

  /// Completes a new account registration, creating a new auth user with a
  /// profile and attaching the given email account to it.
  ///
  /// Throws an [EmailAccountRequestException] in case of errors, with reason:
  /// - [EmailAccountRequestExceptionReason.expired] if the account request has
  ///   already expired.
  /// - [EmailAccountRequestExceptionReason.policyViolation] if the password
  ///   does not comply with the password policy.
  /// - [EmailAccountRequestExceptionReason.invalid] if the [registrationToken]
  ///   is invalid.
  ///
  /// Throws an [AuthUserBlockedException] if the auth user is blocked.
  ///
  /// Returns a session for the newly created user.
  @override
  _ida.Future<_iacc.AuthSuccess> finishRegistration({
    required String registrationToken,
    required String password,
  }) => caller.callServerEndpoint<_iacc.AuthSuccess>(
    'emailIdp',
    'finishRegistration',
    {
      'registrationToken': registrationToken,
      'password': password,
    },
  );

  /// Requests a password reset for [email].
  ///
  /// If the email address is registered, an email with reset instructions will
  /// be send out. If the email is unknown, this method will have no effect.
  ///
  /// Always returns a password reset request ID, which can be used to complete
  /// the reset. If the email is not registered, the returned ID will not be
  /// valid.
  ///
  /// Throws an [EmailAccountPasswordResetException] in case of errors, with reason:
  /// - [EmailAccountPasswordResetExceptionReason.tooManyAttempts] if the user has
  ///   made too many attempts trying to request a password reset.
  ///
  @override
  _ida.Future<_isc.UuidValue> startPasswordReset({required String email}) =>
      caller.callServerEndpoint<_isc.UuidValue>(
        'emailIdp',
        'startPasswordReset',
        {'email': email},
      );

  /// Verifies a password reset code and returns a finishPasswordResetToken
  /// that can be used to finish the password reset.
  ///
  /// Throws an [EmailAccountPasswordResetException] in case of errors, with reason:
  /// - [EmailAccountPasswordResetExceptionReason.expired] if the password reset
  ///   request has already expired.
  /// - [EmailAccountPasswordResetExceptionReason.tooManyAttempts] if the user has
  ///   made too many attempts trying to verify the password reset.
  /// - [EmailAccountPasswordResetExceptionReason.invalid] if no request exists
  ///   for the given [passwordResetRequestId] or [verificationCode] is invalid.
  ///
  /// If multiple steps are required to complete the password reset, this endpoint
  /// should be overridden to return credentials for the next step instead
  /// of the credentials for setting the password.
  @override
  _ida.Future<String> verifyPasswordResetCode({
    required _isc.UuidValue passwordResetRequestId,
    required String verificationCode,
  }) => caller.callServerEndpoint<String>(
    'emailIdp',
    'verifyPasswordResetCode',
    {
      'passwordResetRequestId': passwordResetRequestId,
      'verificationCode': verificationCode,
    },
  );

  /// Completes a password reset request by setting a new password.
  ///
  /// The [verificationCode] returned from [verifyPasswordResetCode] is used to
  /// validate the password reset request.
  ///
  /// Throws an [EmailAccountPasswordResetException] in case of errors, with reason:
  /// - [EmailAccountPasswordResetExceptionReason.expired] if the password reset
  ///   request has already expired.
  /// - [EmailAccountPasswordResetExceptionReason.policyViolation] if the new
  ///   password does not comply with the password policy.
  /// - [EmailAccountPasswordResetExceptionReason.invalid] if no request exists
  ///   for the given [passwordResetRequestId] or [verificationCode] is invalid.
  ///
  /// Throws an [AuthUserBlockedException] if the auth user is blocked.
  @override
  _ida.Future<void> finishPasswordReset({
    required String finishPasswordResetToken,
    required String newPassword,
  }) => caller.callServerEndpoint<void>(
    'emailIdp',
    'finishPasswordReset',
    {
      'finishPasswordResetToken': finishPasswordResetToken,
      'newPassword': newPassword,
    },
  );

  @override
  _ida.Future<bool> hasAccount() => caller.callServerEndpoint<bool>(
    'emailIdp',
    'hasAccount',
    {},
  );
}

/// By extending [RefreshJwtTokensEndpoint], the JWT token refresh endpoint
/// is made available on the server and enables automatic token refresh on the client.
/// {@category Endpoint}
class EndpointJwtRefresh extends _iacc.EndpointRefreshJwtTokens {
  EndpointJwtRefresh(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'jwtRefresh';

  /// Creates a new token pair for the given [refreshToken].
  ///
  /// If [refreshToken] is omitted, cookie-mode web clients fall back to the
  /// configured HttpOnly refresh cookie. When neither source is present this
  /// throws [RefreshTokenNotFoundException], the same public "no usable refresh
  /// credential" exception used for unknown refresh tokens.
  ///
  /// Can throw the following exceptions:
  /// -[RefreshTokenMalformedException]: refresh token is malformed and could
  ///   not be parsed. Not expected to happen for tokens issued by the server.
  /// -[RefreshTokenNotFoundException]: refresh token is unknown to the server.
  ///   Either the token was deleted or generated by a different server.
  /// -[RefreshTokenExpiredException]: refresh token has expired. Will happen
  ///   only if it has not been used within configured `refreshTokenLifetime`.
  /// -[RefreshTokenInvalidSecretException]: refresh token is incorrect, meaning
  ///   it does not refer to the current secret refresh token. This indicates
  ///   either a malfunctioning client or a malicious attempt by someone who has
  ///   obtained the refresh token. In this case the underlying refresh token
  ///   will be deleted, and access to it will expire fully when the last access
  ///   token is elapsed.
  ///
  /// This endpoint is unauthenticated, meaning the client won't include any
  /// authentication information with the call.
  @override
  _ida.Future<_iacc.AuthSuccess> refreshAccessToken({String? refreshToken}) =>
      caller.callServerEndpoint<_iacc.AuthSuccess>(
        'jwtRefresh',
        'refreshAccessToken',
        {'refreshToken': refreshToken},
        authenticated: false,
      );
}

/// "Try the demo": a shared, fully working account with sample content, one
/// per language (ADR 020, plan 014, research 028). Both methods are public; with `demoEnabled` off the
/// feature does not exist (`status().enabled == false`, `signIn` refuses).
/// {@category Endpoint}
class EndpointDemo extends _isc.EndpointRef {
  EndpointDemo(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'demo';

  /// What the login screen and the demo banner need. Never throws for a
  /// disabled or broken demo: that is just `enabled: false`.
  _ida.Future<_ic49xm8h.DemoStatus> status() =>
      caller.callServerEndpoint<_ic49xm8h.DemoStatus>(
        'demo',
        'status',
        {},
      );

  /// Signs in as the demo account of [locale]'s language (`ko*` is Korean,
  /// anything else, or none, is English: what an older app sends). If that
  /// account cannot be found or created, the English one is used instead.
  /// Refused when the flag is off.
  ///
  /// The caller must not be signed in as someone else: the server then throws
  /// `SignInWhileAuthenticatedException`, so the app signs out first
  /// (`client.auth.signOutDevice()`) and then hands the result to
  /// `client.auth.updateSignedInUser`.
  _ida.Future<_iacc.AuthSuccess> signIn([String? locale]) =>
      caller.callServerEndpoint<_iacc.AuthSuccess>(
        'demo',
        'signIn',
        {'locale': locale},
      );
}

/// This is an example endpoint that returns a greeting message through
/// its [hello] method.
/// {@category Endpoint}
class EndpointGreeting extends _isc.EndpointRef {
  EndpointGreeting(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'greeting';

  /// Returns a personalized greeting message: "Hello {name}".
  _ida.Future<_ibcu9c6c.Greeting> hello(String name) =>
      caller.callServerEndpoint<_ibcu9c6c.Greeting>(
        'greeting',
        'hello',
        {'name': name},
      );
}

/// Read-only conversation list for administrators (`ADMIN_USER_IDS`). The
/// server decides who is one on every call; there is no write method.
/// {@category Endpoint}
class EndpointAskAdmin extends _isc.EndpointRef {
  EndpointAskAdmin(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'askAdmin';

  /// One page of conversations with their messages, newest first, and the
  /// answers per model over the whole filtered range. A caller who may not
  /// list gets an [AskAdminException] (a serialized answer, not a server
  /// error); the reason says which rule: history off, demo account, or not
  /// listed.
  _ida.Future<_ifeoh06a.AskAdminPage> listSessions(
    _ihxjv8go.AskAdminFilter filter,
  ) => caller.callServerEndpoint<_ifeoh06a.AskAdminPage>(
    'askAdmin',
    'listSessions',
    {'filter': filter},
  );
}

/// Retrieval + generation in one streaming call (Phase 0).
/// {@category Endpoint}
class EndpointAsk extends _isc.EndpointRef {
  EndpointAsk(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'ask';

  /// Streams an answer to [question] over the user's personal documents and
  /// the requested projects they are a member of.
  ///
  /// With Ask history on (`ASK_HISTORY_ENABLED`, design 030) the question and
  /// answer are stored, [sessionId] picks the conversation (0 = new, null =
  /// an app that does not know conversations: recorded hidden, outside the
  /// limits) and the first event is `session`. Off, nothing changes.
  /// [visitorKey] tells demo visitors apart; other users' is ignored.
  _ida.Stream<_iv9ukj64.AnswerEvent> ask(
    String question,
    List<int> projectIds,
    bool includePersonal,
    String? modelId, [
    String? locale,
    int? sessionId,
    String? visitorKey,
  ]) =>
      caller.callStreamingServerEndpoint<
        _ida.Stream<_iv9ukj64.AnswerEvent>,
        _iv9ukj64.AnswerEvent
      >(
        'ask',
        'ask',
        {
          'question': question,
          'projectIds': projectIds,
          'includePersonal': includePersonal,
          'modelId': modelId,
          'locale': locale,
          'sessionId': sessionId,
          'visitorKey': visitorKey,
        },
        {},
      );
}

/// Stored Ask conversations of the signed-in user (design 030). Every method
/// is a no-op or an empty answer while `ASK_HISTORY_ENABLED` is off. Demo
/// visitors share one account, so they send their browser's [visitorKey] and
/// only see their own conversations.
/// {@category Endpoint}
class EndpointAskHistory extends _isc.EndpointRef {
  EndpointAskHistory(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'askHistory';

  /// Whether the app shows the history UI at all, and its rules.
  _ida.Future<_iq117uuo.AskHistoryStatus> historyStatus() =>
      caller.callServerEndpoint<_iq117uuo.AskHistoryStatus>(
        'askHistory',
        'historyStatus',
        {},
      );

  /// The recent conversations and, after a reload within the resume window,
  /// the one to continue. The server decides by its own clock.
  _ida.Future<_isr923wh.AskRestore> restore([String? visitorKey]) =>
      caller.callServerEndpoint<_isr923wh.AskRestore>(
        'askHistory',
        'restore',
        {'visitorKey': visitorKey},
      );

  /// One conversation of the recent list; null when it is gone, hidden, not
  /// the caller's or past its viewing window.
  _ida.Future<_ii1ulf7a.AskSessionView?> open(
    int sessionId, [
    String? visitorKey,
  ]) => caller.callServerEndpoint<_ii1ulf7a.AskSessionView?>(
    'askHistory',
    'open',
    {
      'sessionId': sessionId,
      'visitorKey': visitorKey,
    },
  );

  /// "Delete" from the list. Only hides: the server keeps it for the
  /// retention period.
  _ida.Future<void> hide(
    int sessionId, [
    String? visitorKey,
  ]) => caller.callServerEndpoint<void>(
    'askHistory',
    'hide',
    {
      'sessionId': sessionId,
      'visitorKey': visitorKey,
    },
  );
}

/// Upload and list documents. Text is extracted on the client (ADR 003).
/// {@category Endpoint}
class EndpointDocument extends _isc.EndpointRef {
  EndpointDocument(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'document';

  /// Indexes a document from per-page text. [projectId] null = personal.
  _ida.Future<_ix72owx0.Document> upload(
    String title,
    List<_iu4vwvb3.PageText> pages,
    String contentHash,
    int? projectId,
  ) => caller.callServerEndpoint<_ix72owx0.Document>(
    'document',
    'upload',
    {
      'title': title,
      'pages': pages,
      'contentHash': contentHash,
      'projectId': projectId,
    },
  );

  /// Creates or updates a markdown note and (re)indexes it as one page.
  _ida.Future<_ix72owx0.Document> saveNote(
    int? documentId,
    String title,
    String body,
    int? projectId,
  ) => caller.callServerEndpoint<_ix72owx0.Document>(
    'document',
    'saveNote',
    {
      'documentId': documentId,
      'title': title,
      'body': body,
      'projectId': projectId,
    },
  );

  /// Sets (or clears with null) a note's card color. Metadata only: no
  /// re-index, and `updatedAt`/`version`/`status` stay as they are.
  _ida.Future<_ix72owx0.Document> setNoteColor(
    int documentId,
    int? colorIndex,
  ) => caller.callServerEndpoint<_ix72owx0.Document>(
    'document',
    'setNoteColor',
    {
      'documentId': documentId,
      'colorIndex': colorIndex,
    },
  );

  /// Localizes and indexes the sign-up sample note once (research 021 §A).
  /// Returns its id, or null when there is nothing to do (already handled,
  /// edited, deleted). Safe to call on every app start and from two tabs.
  _ida.Future<int?> ensureSample(String locale) =>
      caller.callServerEndpoint<int?>(
        'document',
        'ensureSample',
        {'locale': locale},
      );

  /// Example questions for the sample content the caller holds, in the
  /// language of that content (research 028 §4.2). A sign-up sample counts
  /// only while its note is untouched (body hash) and `ready`: before that,
  /// or after an edit or delete, its questions would find nothing. A demo
  /// account gets its pack's questions directly.
  _ida.Future<List<_ilp4f5ys.SampleHint>> sampleHints() =>
      caller.callServerEndpoint<List<_ilp4f5ys.SampleHint>>(
        'document',
        'sampleHints',
        {},
      );

  /// One document the user can read (notes are opened in the editor).
  _ida.Future<_ix72owx0.Document?> get(int documentId) =>
      caller.callServerEndpoint<_ix72owx0.Document?>(
        'document',
        'get',
        {'documentId': documentId},
      );

  /// Upload description for the original PDF of [documentId] (direct upload
  /// to cloud storage; API requests are capped at 512 KiB).
  _ida.Future<String> pdfUploadDescription(int documentId) =>
      caller.callServerEndpoint<String>(
        'document',
        'pdfUploadDescription',
        {'documentId': documentId},
      );

  /// Confirms the upload and records where the original is stored.
  _ida.Future<bool> confirmPdfUpload(int documentId) =>
      caller.callServerEndpoint<bool>(
        'document',
        'confirmPdfUpload',
        {'documentId': documentId},
      );

  /// Short-lived download URL for the original PDF, after an access check.
  _ida.Future<String?> pdfUrl(int documentId) =>
      caller.callServerEndpoint<String?>(
        'document',
        'pdfUrl',
        {'documentId': documentId},
      );

  /// Retries indexing from the stored text (failed or stale documents).
  _ida.Future<_ix72owx0.Document> reindex(int documentId) =>
      caller.callServerEndpoint<_ix72owx0.Document>(
        'document',
        'reindex',
        {'documentId': documentId},
      );

  /// Retries every failed document the user can edit. Returns how many are ready now.
  _ida.Future<int> reindexFailed() => caller.callServerEndpoint<int>(
    'document',
    'reindexFailed',
    {},
  );

  /// Personal documents plus documents of every project the user belongs to.
  _ida.Future<List<_ix72owx0.Document>> list() =>
      caller.callServerEndpoint<List<_ix72owx0.Document>>(
        'document',
        'list',
        {},
      );

  _ida.Future<void> delete(int documentId) => caller.callServerEndpoint<void>(
    'document',
    'delete',
    {'documentId': documentId},
  );
}

/// Lists answer models for the in-app model picker.
/// {@category Endpoint}
class EndpointModel extends _isc.EndpointRef {
  EndpointModel(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'model';

  _ida.Future<List<_ikmj492w.LlmModel>> list() =>
      caller.callServerEndpoint<List<_ikmj492w.LlmModel>>(
        'model',
        'list',
        {},
      );

  _ida.Future<String> defaultModel() => caller.callServerEndpoint<String>(
    'model',
    'defaultModel',
    {},
  );
}

/// Projects share documents between members.
/// {@category Endpoint}
class EndpointProject extends _isc.EndpointRef {
  EndpointProject(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'project';

  _ida.Future<_id2xbn90.Project> create(String name) =>
      caller.callServerEndpoint<_id2xbn90.Project>(
        'project',
        'create',
        {'name': name},
      );

  _ida.Future<List<_id2xbn90.Project>> list() =>
      caller.callServerEndpoint<List<_id2xbn90.Project>>(
        'project',
        'list',
        {},
      );

  /// Adds a registered user by email. Only owners can invite.
  _ida.Future<_ijtrgq11.ProjectMember> addMember(
    int projectId,
    String email,
    String role,
  ) => caller.callServerEndpoint<_ijtrgq11.ProjectMember>(
    'project',
    'addMember',
    {
      'projectId': projectId,
      'email': email,
      'role': role,
    },
  );

  _ida.Future<List<_ijtrgq11.ProjectMember>> members(int projectId) =>
      caller.callServerEndpoint<List<_ijtrgq11.ProjectMember>>(
        'project',
        'members',
        {'projectId': projectId},
      );

  /// Renames a project. Only the owner can.
  _ida.Future<_id2xbn90.Project> updateProject(
    int projectId,
    String name,
  ) => caller.callServerEndpoint<_id2xbn90.Project>(
    'project',
    'updateProject',
    {
      'projectId': projectId,
      'name': name,
    },
  );

  /// What deleting [projectId] would take with it: `notes`, `pdfs`, `members`.
  /// Any member can ask; the app shows it in the delete confirmation.
  _ida.Future<Map<String, int>> projectStats(int projectId) =>
      caller.callServerEndpoint<Map<String, int>>(
        'project',
        'projectStats',
        {'projectId': projectId},
      );

  /// Deletes a project. Only the owner can. When it still has documents this
  /// throws (`not_empty:<count>`) unless [deleteDocuments] is true, which also
  /// deletes every document, chunk, page, stored PDF and membership.
  /// Returns how many documents were deleted.
  _ida.Future<int> deleteProject(
    int projectId,
    bool deleteDocuments,
  ) => caller.callServerEndpoint<int>(
    'project',
    'deleteProject',
    {
      'projectId': projectId,
      'deleteDocuments': deleteDocuments,
    },
  );
}

class Modules {
  Modules(Client client) {
    serverpod_auth_idp = _iaic.Caller(client);
    serverpod_auth_core = _iacc.Caller(client);
  }

  late final _iaic.Caller serverpod_auth_idp;

  late final _iacc.Caller serverpod_auth_core;
}

class Client extends _isc.ServerpodClientShared {
  Client(
    String host, {
    dynamic securityContext,
    Duration? streamingConnectionTimeout,
    Duration? connectionTimeout,
    Function(
      _isc.MethodCallContext,
      Object,
      StackTrace,
    )?
    onFailedCall,
    Function(_isc.MethodCallContext)? onSucceededCall,
    bool? disconnectStreamsOnLostInternetConnection,
    _i85jenna.Client? httpClientOverride,
  }) : super(
         host,
         _il2as5qe.Protocol(),
         securityContext: securityContext,
         streamingConnectionTimeout: streamingConnectionTimeout,
         connectionTimeout: connectionTimeout,
         onFailedCall: onFailedCall,
         onSucceededCall: onSucceededCall,
         disconnectStreamsOnLostInternetConnection:
             disconnectStreamsOnLostInternetConnection,
         httpClientOverride: httpClientOverride,
       ) {
    emailIdp = EndpointEmailIdp(this);
    jwtRefresh = EndpointJwtRefresh(this);
    demo = EndpointDemo(this);
    greeting = EndpointGreeting(this);
    askAdmin = EndpointAskAdmin(this);
    ask = EndpointAsk(this);
    askHistory = EndpointAskHistory(this);
    document = EndpointDocument(this);
    model = EndpointModel(this);
    project = EndpointProject(this);
    modules = Modules(this);
  }

  late final EndpointEmailIdp emailIdp;

  late final EndpointJwtRefresh jwtRefresh;

  late final EndpointDemo demo;

  late final EndpointGreeting greeting;

  late final EndpointAskAdmin askAdmin;

  late final EndpointAsk ask;

  late final EndpointAskHistory askHistory;

  late final EndpointDocument document;

  late final EndpointModel model;

  late final EndpointProject project;

  late final Modules modules;

  @override
  Map<String, _isc.EndpointRef> get endpointRefLookup => {
    'emailIdp': emailIdp,
    'jwtRefresh': jwtRefresh,
    'demo': demo,
    'greeting': greeting,
    'askAdmin': askAdmin,
    'ask': ask,
    'askHistory': askHistory,
    'document': document,
    'model': model,
    'project': project,
  };

  @override
  Map<String, _isc.ModuleEndpointCaller> get moduleLookup => {
    'serverpod_auth_idp': modules.serverpod_auth_idp,
    'serverpod_auth_core': modules.serverpod_auth_core,
  };
}
