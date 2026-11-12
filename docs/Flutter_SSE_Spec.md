# Flutter SSE Integration Spec — Batch Processing Status

This document specifies the Server-Sent Events (SSE) endpoint contract for real-time batch processing status updates. Replaces the current 2-second polling approach.

---

## SSE Endpoint

```
GET /images/batch/{batch_id}/stream
```

**Protocol:** Server-Sent Events (SSE / `text/event-stream`)

**Auth:** The `batch_id` (UUID v4) functions as the access token for the stream. No additional JWT or cookie is required. The backend validates that the `batch_id` exists before opening the stream.

**Important:** The SSE `status` event only contains the status string (`completed`, `failed`, etc.) — **not** the full batch result payload. On a terminal event, the client must make a separate `GET /images/batch/{batch_id}` REST call to fetch face detection results, recipients, and image data.

---

## Connection

### Dart/Flutter Example

Use the [`eventsource`](https://pub.dev/packages/eventsource) package or `http` with streaming:

```dart
import 'package:eventsource/eventsource.dart';
import 'dart:convert';

class BatchStatusStream {
  EventSource? _source;
  
  /// Connect to SSE stream for batch status updates
  Future<void> connect({
    required String batchId,
    required String backendUrl,
    required Function(String status, String? message) onStatus,
    required Function() onComplete,
    required Function(String error) onError,
  }) async {
    final url = '$backendUrl/images/batch/$batchId/stream';
    
    try {
      _source = await EventSource.connect(url);
      
      _source!.listen((Event event) {
        if (event.event == 'status') {
          final data = jsonDecode(event.data ?? '{}');
          final status = data['status'] as String;
          final message = data['message'] as String?;
          
          onStatus(status, message);
          
          // Terminal states — close connection
          if (status == 'completed' || status == 'failed' || status == 'error') {
            onComplete();
            disconnect();
          }
        }
        // Ignore 'heartbeat' events — they just keep connection alive
      });
    } catch (e) {
      onError(e.toString());
      // Fallback to polling if SSE fails
    }
  }
  
  void disconnect() {
    _source?.close();
    _source = null;
  }
}
```

### Usage in Widget

```dart
final stream = BatchStatusStream();

await stream.connect(
  batchId: uploadResult.batchId,
  backendUrl: 'https://backend.prismapp.in',
  onStatus: (status, message) {
    setState(() {
      _batchStatus = status;
      _statusMessage = message ?? 'Processing...';
    });
  },
  onComplete: () async {
    // IMPORTANT: Fetch the full batch result after SSE signals completion.
    // The SSE event only contains the status field — all face data, recipients,
    // and image results come from the REST endpoint.
    final result = await _api.getBatchStatus(uploadResult.batchId);
    _handleBatchResult(result);
  },
  onError: (error) {
    // Fallback: start polling GET /images/batch/{id} every 5 seconds
    _startPollingFallback();
  },
);
```

---

## Event Types

### `status` (primary)

```json
// Processing
{"status": "processing", "message": "Connected to stream"}

// Completed  
{"status": "completed"}

// Failed
{"status": "failed", "error": "Error description"}

// Timeout (10 min)
{"status": "timeout", "message": "Stream timeout"}
```

### `heartbeat` (keep-alive)

```
event: heartbeat
data: ping
```

Sent every 2 seconds. **Ignore these** — they just prevent proxy/load balancer timeouts.

---

## State Machine

```
connecting → processing → completed ✓
                        → failed ✗
                        → error ✗
                        → timeout ⏱
```

All terminal states close the SSE connection automatically.

---

## Fallback Strategy

If SSE connection fails (network issue, proxy blocking EventSource):

1. Catch the connection error
2. Fall back to polling `GET /images/batch/{batch_id}` every **5 seconds** (not 2s — reduces backend load)
3. On terminal status from polling, still call `GET /images/batch/{batch_id}` for the full payload (same endpoint, same response):
   ```json
   {
     "status": "completed",  // or "processing", "error", "not_started"
     "images": [...],
     "recipients": [...],
     // ... full batch data
   }
   ```
4. One immediate REST check should be performed at SSE connect time in case the batch already completed before the SSE connection was established.

---

## Timeout Behavior

- SSE stream auto-closes after **10 minutes** (server-side)
- The server sends a `{"status": "timeout"}` event before closing
- Client should handle timeout by either retrying or showing an error

---

## Platform Notes

| Platform | SSE Support | Package |
|----------|-------------|---------|
| Android | ✅ Native | `eventsource` pub package |
| iOS | ✅ Native | `eventsource` pub package |
| Web | ✅ Native `EventSource` API | Built-in browser API |

> [!NOTE]
> The `eventsource` package handles reconnection automatically. If the connection drops, it will attempt to reconnect. However, for batch processing, a single connection attempt is sufficient since batches complete in 1-5 minutes.

---

## Integration Checklist

- [ ] Add `eventsource` package to `pubspec.yaml`
- [ ] Create `BatchStatusStream` service class
- [ ] Connect SSE stream after `POST /images/upload` returns `batch_id`
- [ ] Perform **one immediate REST poll** at connect time (race condition: batch may finish before SSE opens)
- [ ] Show real-time status in upload progress UI (status event `message` field)
- [ ] On terminal SSE event, call `GET /images/batch/{batch_id}` to fetch **full result payload**
- [ ] Handle all terminal states: `completed`, `failed`, `error`, `timeout`
- [ ] Implement 5-second polling fallback for SSE failure
- [ ] Disconnect SSE on screen `dispose()` to prevent memory leaks
- [ ] Filter/deduplicate recipients by `user_id` before rendering — multi-view users may appear multiple times
