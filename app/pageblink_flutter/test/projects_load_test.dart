import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pageblink_client/pageblink_client.dart';
import 'package:pageblink_flutter/features/projects/projects_load.dart';

Project _p(int id) => Project(
  id: id,
  name: 'P$id',
  ownerId: UuidValue.fromString('00000000-0000-4000-8000-00000000000$id'),
  createdAt: DateTime.utc(2026, 10, 16),
);

void main() {
  tearDown(() => projectsListCall = null);

  test('starts loading with an empty list', () {
    final m = ProjectsModel();
    expect(m.status.value, ProjectsLoad.loading);
    expect(m.list.value, isEmpty);
    m.dispose();
  });

  test('loading -> loaded with the projects', () async {
    final answer = Completer<List<Project>>();
    projectsListCall = () => answer.future;
    final m = ProjectsModel();
    final seen = <ProjectsLoad>[];
    m.status.addListener(() => seen.add(m.status.value));
    final done = m.load();
    expect(m.status.value, ProjectsLoad.loading);
    answer.complete([_p(1), _p(2)]);
    await done;
    expect(m.status.value, ProjectsLoad.loaded);
    expect(m.list.value.map((p) => p.name), ['P1', 'P2']);
    expect(seen, [ProjectsLoad.loaded]);
    m.dispose();
  });

  test('loading -> loaded with none is not an error', () async {
    projectsListCall = () async => [];
    final m = ProjectsModel();
    await m.load();
    expect(m.status.value, ProjectsLoad.loaded);
    expect(m.list.value, isEmpty);
    m.dispose();
  });

  test('loading -> error when the read fails', () async {
    projectsListCall = () async => throw Exception('offline');
    final m = ProjectsModel();
    await m.load();
    expect(m.status.value, ProjectsLoad.error);
    expect(m.list.value, isEmpty);
    m.dispose();
  });

  test('a retry that works goes error -> loaded', () async {
    projectsListCall = () async => throw Exception('offline');
    final m = ProjectsModel();
    await m.load();
    projectsListCall = () async => [_p(1)];
    await m.load();
    expect(m.status.value, ProjectsLoad.loaded);
    expect(m.list.value, hasLength(1));
    m.dispose();
  });

  test('a refresh that fails keeps the last list', () async {
    projectsListCall = () async => [_p(1)];
    final m = ProjectsModel();
    await m.load();
    projectsListCall = () async => throw Exception('offline');
    await m.load();
    expect(m.status.value, ProjectsLoad.error);
    expect(m.list.value, hasLength(1));
    m.dispose();
  });

  test('an answer after dispose is ignored', () async {
    final answer = Completer<List<Project>>();
    projectsListCall = () => answer.future;
    final m = ProjectsModel();
    final done = m.load();
    m.dispose();
    answer.complete([_p(1)]);
    await done; // must not touch the disposed notifiers
  });
}
