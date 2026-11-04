import 'dart:async';
import 'dart:typed_data';

/// Callback invoked when a stream successfully completes.
typedef StreamTapCompleteCallback = void Function(
  List<int> bufferedBytes,
  bool isTruncated,
  int totalBytes,
);

/// Callback invoked when a stream encounters an error.
typedef StreamTapErrorCallback = void Function(
  Object error,
  StackTrace stackTrace,
  List<int> partialBytes,
  int totalBytes,
);

/// Creates a non-destructive [StreamTransformer] that forwards incoming byte chunks
/// synchronously to consumer sinks while accumulating an internal copy up to [maxBodyBytes].
///
/// If [isBinary] is true, chunks are forwarded directly downstream without storing raw bytes
/// in memory, accumulating only the total byte count (D-41, D-43).
StreamTransformer<List<int>, List<int>> createStreamTapTransformer({
  required int maxBodyBytes,
  bool isBinary = false,
  required StreamTapCompleteCallback onComplete,
  required StreamTapErrorCallback onError,
}) {
  final buffer = BytesBuilder(copy: false);
  int accumulatedBytes = 0;
  int totalBytes = 0;
  bool isTruncated = false;
  bool isTerminated = false;

  return StreamTransformer<List<int>, List<int>>.fromHandlers(
    handleData: (List<int> chunk, EventSink<List<int>> sink) {
      // 1. Synchronously forward chunk downstream to host application listener (D-41)
      sink.add(chunk);

      totalBytes += chunk.length;

      // 2. Accumulate copy for network inspection buffer (bypass if binary per D-43)
      if (!isBinary) {
        if (accumulatedBytes + chunk.length <= maxBodyBytes) {
          buffer.add(chunk);
          accumulatedBytes += chunk.length;
        } else if (!isTruncated) {
          final remaining = maxBodyBytes - accumulatedBytes;
          if (remaining > 0) {
            buffer.add(chunk.sublist(0, remaining));
            accumulatedBytes += remaining;
          }
          isTruncated = true;
        }
      }
    },
    handleError:
        (Object error, StackTrace stackTrace, EventSink<List<int>> sink) {
      if (!isTerminated) {
        isTerminated = true;
        try {
          onError(error, stackTrace, buffer.takeBytes(), totalBytes);
        } catch (_) {
          // Defensive error isolation: interceptor errors must never disrupt app streams
        }
      }
      sink.addError(error, stackTrace);
    },
    handleDone: (EventSink<List<int>> sink) {
      if (!isTerminated) {
        isTerminated = true;
        try {
          onComplete(buffer.takeBytes(), isTruncated, totalBytes);
        } catch (_) {
          // Defensive error isolation: interceptor errors must never disrupt app streams
        }
      }
      sink.close();
    },
  );
}
