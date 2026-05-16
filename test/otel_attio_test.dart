// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_attio/otel_attio.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_attio-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('records.assert records upsert + matching attribute', () async {
    await tracedAttio<String>(
      operation: 'records.assert',
      objectSlug: 'companies',
      invoke: () async => const AttioCallResult(
        value: 'ok',
        result: AttioResult(
          objectSlug: 'companies',
          workspaceId: 'w-1',
          attributeCount: 12,
          upsert: true,
          matchingAttribute: 'domains',
          statusCode: 200,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('attio records.assert')!);
    expect(a['attio.object.slug'], 'companies');
    expect(a['attio.workspace.id'], 'w-1');
    expect(a['attio.attribute_count'], 12);
    expect(a['attio.upsert'], true);
    expect(a['attio.matching_attribute'], 'domains');
  });

  test('suppression skips spans', () async {
    await runWithoutAttioInstrumentationAsync(() async {
      await tracedAttio<String>(
        operation: 'records.list',
        invoke: () async => const AttioCallResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('attio '), isEmpty);
  });
}
