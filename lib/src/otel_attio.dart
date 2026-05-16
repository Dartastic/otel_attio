// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'otel_attio_suppression.dart';

const _tracerName = 'dartastic_otel_libs_attio';

Tracer _tracer() => OTel.tracerProvider().getTracer(_tracerName);

class AttioResult {
  const AttioResult({
    this.itemCount,
    this.objectSlug,
    this.listSlug,
    this.workspaceId,
    this.attributeCount,
    this.upsert,
    this.matchingAttribute,
    this.requestId,
    this.statusCode,
  });

  /// `data.length`.
  final int? itemCount;

  /// `people` / `companies` / `deals` / `users` / `workspaces` /
  /// custom-object slug.
  final String? objectSlug;

  /// List slug when targeting a saved list.
  final String? listSlug;

  /// Workspace id (Attio is multi-workspace).
  final String? workspaceId;

  /// Number of attributes set on the record (drives request size +
  /// fan-out to enrichment).
  final int? attributeCount;

  /// Whether this was an upsert (Attio dedupe by matching_attribute).
  final bool? upsert;

  /// Slug of the matching attribute used for upsert (`email_addresses`,
  /// `domains`, etc.).
  final String? matchingAttribute;

  /// `X-Request-Id`.
  final String? requestId;

  final int? statusCode;
}

class AttioCallResult<T> {
  const AttioCallResult({required this.value, this.result});
  final T value;
  final AttioResult? result;
}

/// Wraps an Attio API call in a CLIENT span. [operation] is one of
/// `objects.list`, `objects.get`, `records.list`, `records.get`,
/// `records.create`, `records.assert`, `records.update`,
/// `records.delete`, `lists.list`, `lists.get`,
/// `lists.entries.list`, `lists.entries.create`,
/// `attributes.list`, `attributes.options.list`, `workspaces.list`,
/// `threads.list`, `threads.create`, `comments.create`,
/// `notes.create`, `tasks.create`, `webhooks.create`.
Future<T> tracedAttio<T>({
  required String operation,
  required Future<AttioCallResult<T>> Function() invoke,
  String? objectSlug,
}) async {
  if (attioInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'rpc.system': 'attio',
    'rpc.method': operation,
    'attio.operation': operation,
  };
  if (objectSlug != null) m['attio.object.slug'] = objectSlug;

  final span = _tracer().startSpan(
    'attio $operation',
    kind: SpanKind.client,
    attributes: OTel.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.itemCount != null) {
        extras.add(OTel.attributeInt(
          'attio.item_count',
          r.result!.itemCount!,
        ));
      }
      if (r.result!.objectSlug != null) {
        extras.add(OTel.attributeString(
          'attio.object.slug',
          r.result!.objectSlug!,
        ));
      }
      if (r.result!.listSlug != null) {
        extras.add(OTel.attributeString(
          'attio.list.slug',
          r.result!.listSlug!,
        ));
      }
      if (r.result!.workspaceId != null) {
        extras.add(OTel.attributeString(
          'attio.workspace.id',
          r.result!.workspaceId!,
        ));
      }
      if (r.result!.attributeCount != null) {
        extras.add(OTel.attributeInt(
          'attio.attribute_count',
          r.result!.attributeCount!,
        ));
      }
      if (r.result!.upsert != null) {
        extras.add(OTel.attributeBool(
          'attio.upsert',
          r.result!.upsert!,
        ));
      }
      if (r.result!.matchingAttribute != null) {
        extras.add(OTel.attributeString(
          'attio.matching_attribute',
          r.result!.matchingAttribute!,
        ));
      }
      if (r.result!.requestId != null) {
        extras.add(OTel.attributeString(
          'attio.request.id',
          r.result!.requestId!,
        ));
      }
      if (r.result!.statusCode != null) {
        extras.add(OTel.attributeInt(
          'http.response.status_code',
          r.result!.statusCode!,
        ));
        if (r.result!.statusCode! >= 400) {
          span.setStatus(
            SpanStatusCode.Error,
            'Attio HTTP ${r.result!.statusCode}',
          );
        }
      }
      if (extras.isNotEmpty) span.addAttributes(OTel.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
