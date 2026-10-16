import 'dart:io';

import 'package:serverpod/serverpod.dart';

import '../rag/embedding_spec.dart';

bool _truthy(String? v) =>
    const {'true', '1', 'yes', 'on'}.contains(v?.trim().toLowerCase());

/// Indexing flags, read like `DemoConfig`: password first, then environment
/// (`scloud variable set`, applied on redeploy). passwords.yaml values must
/// be strings: `reindexOnBoot: 'true'`.
class IndexConfig {
  static const _versionPassword = 'chunkerVersion';
  static const _versionEnv = 'CHUNKER_VERSION';
  static const _reindexPassword = 'reindexOnBoot';
  static const _reindexEnv = 'REINDEX_ON_BOOT';

  /// Tests only: force the flags without passwords or environment.
  static int? debugChunkerVersion;
  static bool? debugReindexOnBoot;

  /// 1 = paragraph chunker (rollback), anything else valid = 2.
  static int _version(String? raw) =>
      int.tryParse(raw?.trim() ?? '') == ChunkSpec.legacy
      ? ChunkSpec.legacy
      : ChunkSpec.latest;

  /// Chunk rules new documents are indexed with (`CHUNKER_VERSION`, 2).
  static int chunkerVersion(Session session) =>
      debugChunkerVersion ??
      _version(
        session.passwords[_versionPassword] ??
            Platform.environment[_versionEnv],
      );

  static int chunkerVersionForPod(Serverpod pod) =>
      debugChunkerVersion ??
      _version(
        pod.getPassword(_versionPassword) ?? Platform.environment[_versionEnv],
      );

  /// Whether the boot re-index job runs (`REINDEX_ON_BOOT`, off).
  static bool reindexOnBootForPod(Serverpod pod) =>
      debugReindexOnBoot ??
      _truthy(
        pod.getPassword(_reindexPassword) ?? Platform.environment[_reindexEnv],
      );
}
