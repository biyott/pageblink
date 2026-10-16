import 'dart:async';

import 'package:pageblink_client/pageblink_client.dart';
import 'package:serverpod_auth_idp_flutter/serverpod_auth_idp_flutter.dart';
import 'package:serverpod_flutter/serverpod_flutter.dart';

import 'features/auth/session_end.dart';
import 'features/demo/demo.dart';

// When you are running the app on a physical device, you need to set the
// server URL to the IP address of your computer. You can find the IP
// address by running `ipconfig` on Windows or `ifconfig` on Mac/Linux.
//
// You can set the variable when running or building your app like this:
// E.g. `flutter run --dart-define=SERVER_URL=https://api.example.com/`.
//
// Otherwise, the server URL is fetched from the assets/config.json file or
// defaults to http://$localhost:8080/ if not found.
final serverUrl = getServerUrl();

/// Sets up a global client object that can be used to talk to the server from
/// anywhere in our app. The client is generated from your server code
/// and is set up to connect to a Serverpod running on a local server on
/// the default port. You will need to modify this to connect to staging or
/// production servers.
/// In a larger app, you may want to use the dependency injection of your choice
/// instead of using a global client object. This is just a simple example.
late final Client client;

/// Timeout for plain (non-streaming) calls; serverpod_client defaults to 20 s.
/// `document.upload` and `reindex` index synchronously (up to ~19 embedding
/// batches of 60 s each), so 20 s reported "failed" while the server went on
/// to finish. Streaming calls (`ask`) have their own
/// `streamingConnectionTimeout` and are not affected; a call that merely
/// hangs now fails after 120 s instead of 20 s.
const unaryCallTimeout = Duration(seconds: 120);

/// The generated client, telling [onUnauthorized] about every call that was
/// sent with credentials and still got a 401 (the library has already tried
/// refreshing the token and repeating the call once). The stream of a
/// streaming call (`ask`) is watched the same way.
class AppClient extends Client {
  AppClient(
    super.host, {
    super.connectionTimeout,
    super.httpClientOverride,
    this.onUnauthorized,
  });

  final void Function()? onUnauthorized;

  @override
  Future<T> callServerEndpoint<T>(
    String endpoint,
    String method,
    Map<String, dynamic> args, {
    bool authenticated = true,
  }) async {
    try {
      return await super.callServerEndpoint<T>(
        endpoint,
        method,
        args,
        authenticated: authenticated,
      );
    } on ServerpodClientUnauthorized {
      if (authenticated) onUnauthorized?.call();
      rethrow;
    }
  }

  @override
  dynamic callStreamingServerEndpoint<T, G>(
    String endpoint,
    String method,
    Map<String, dynamic> args,
    Map<String, Stream> streams, {
    bool authenticated = true,
  }) {
    final result = super.callStreamingServerEndpoint<T, G>(
      endpoint,
      method,
      args,
      streams,
      authenticated: authenticated,
    );
    if (!authenticated || result is! Stream<G>) return result;
    return result.transform(
      StreamTransformer<G, G>.fromHandlers(
        handleError: (error, stack, sink) {
          if (error is ServerpodClientUnauthorized) onUnauthorized?.call();
          sink.addError(error, stack);
        },
      ),
    );
  }
}

Future<void> initializeClient() async {
  final guard = SessionGuard(
    isSignedIn: () => client.auth.isAuthenticated,
    validate: () => client.auth.validateAuthentication(
      timeout: const Duration(seconds: 10),
    ),
    isDemo: () => demoStatus.value?.isDemo ?? false,
  );
  client =
      AppClient(
          await serverUrl,
          connectionTimeout: unaryCallTimeout,
          onUnauthorized: () => unawaited(guard.onUnauthorized()),
        )
        ..connectivityMonitor = FlutterConnectivityMonitor()
        ..authSessionManager = FlutterAuthSessionManager();
  unawaited(client.auth.initialize());
}
