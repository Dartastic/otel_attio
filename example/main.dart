// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_attio/otel_attio.dart';

/// Traces Attio calls with OpenTelemetry.
///
/// `otel_attio` depends on the OpenTelemetry API only, so the application
/// initializes an SDK once at startup. Wrap each Attio call in
/// [tracedAttio]; the `invoke` callback makes the real call and reports what
/// came back, which is recorded on the span.
Future<void> main() async {
  await OTel.initialize(serviceName: 'attio-example');

  // Wraps an Attio API call in a CLIENT span.
  final attioId = await tracedAttio<String>(
    operation: 'records.create',
    objectSlug: 'example',
    invoke: () async {
      // Make the Attio call here, then report what it returned.
      const id = 'attio_8f3a2c';
      return const AttioCallResult(
          value: id,
          result: AttioResult(
              itemCount: 3,
              objectSlug: 'people',
              listSlug: 'example',
              workspaceId: 'workspace_8f3a2c',
              attributeCount: 3,
              upsert: true,
              matchingAttribute: 'email_addresses',
              requestId: 'request_8f3a2c',
              statusCode: 201));
    },
  );
  OTelLog.info('tracedAttio records.create returned $attioId');

  // Calls that should not be traced, such as health checks, run inside
  // runWithoutAttioInstrumentationAsync.
  await runWithoutAttioInstrumentationAsync(
    () => tracedAttio<String>(
      operation: 'records.create',
      objectSlug: 'example',
      invoke: () async {
        const id = 'attio_8f3a2c';
        return const AttioCallResult(
            value: id,
            result: AttioResult(
                itemCount: 3,
                objectSlug: 'people',
                listSlug: 'example',
                workspaceId: 'workspace_8f3a2c',
                attributeCount: 3,
                upsert: true,
                matchingAttribute: 'email_addresses',
                requestId: 'request_8f3a2c',
                statusCode: 201));
      },
    ),
  );

  await OTel.shutdown();
}
