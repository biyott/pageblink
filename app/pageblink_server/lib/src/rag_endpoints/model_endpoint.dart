import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import '../services/llm_catalog.dart';

/// Lists answer models for the in-app model picker.
class ModelEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  Future<List<LlmModel>> list(Session session) async => LlmCatalog.models;

  Future<String> defaultModel(Session session) async =>
      session.passwords['llmModel'] ?? LlmCatalog.defaultModelId;
}
