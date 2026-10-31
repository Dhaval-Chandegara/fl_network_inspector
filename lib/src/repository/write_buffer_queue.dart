import 'dart:async';

import '../models/network_record.dart';

/// Callback signature for persisting a batch of flushed [NetworkRecord]s.
typedef BatchFlushCallback = Future<void> Function(List<NetworkRecord> records);

/// In-memory debounced micro-batching write queue for network records.
///
/// Buffers records for [debounceDuration] (default 200ms per D-21), executes
/// batch writes, supports two-phase in-memory coalescing (D-22), and flushes
/// immediately upon reaching [highWaterMark] (default 20 items per D-23).
class WriteBufferQueue {
  /// The underlying sink callback invoked when buffered items are flushed.
  final BatchFlushCallback onFlush;

  /// Time window to debounce rapid consecutive enqueue operations.
  final Duration debounceDuration;

  /// Target transaction batch size.
  final int batchSize;

  /// High-water mark triggering an immediate asynchronous batch flush.
  final int highWaterMark;

  final Map<String, NetworkRecord> _buffer = {};
  Timer? _debounceTimer;
  bool _isFlushing = false;
  bool _isDisposed = false;

  /// Creates a [WriteBufferQueue].
  WriteBufferQueue({
    required this.onFlush,
    this.debounceDuration = const Duration(milliseconds: 200),
    this.batchSize = 10,
    this.highWaterMark = 20,
  });

  /// The current number of items buffered in memory awaiting flush.
  int get length => _buffer.length;

  /// Whether the buffer currently contains no pending records.
  bool get isEmpty => _buffer.isEmpty;

  /// Whether this queue has been disposed.
  bool get isDisposed => _isDisposed;

  /// Enqueues [record] into the buffer.
  ///
  /// Implements two-phase in-memory coalescing (D-22): if a record with [record.id]
  /// is already queued in memory (e.g. pending request state), it is updated
  /// in place with the latest instance, combining request and response fields
  /// before writing to disk.
  ///
  /// If the buffer size reaches or exceeds [highWaterMark] (D-23), triggers an
  /// immediate flush; otherwise reschedules the [debounceDuration] timer.
  void enqueue(NetworkRecord record) {
    if (_isDisposed) return;

    _buffer[record.id] = record;

    if (_buffer.length >= highWaterMark) {
      _debounceTimer?.cancel();
      _debounceTimer = null;
      unawaited(_triggerFlush());
    } else {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(debounceDuration, () {
        unawaited(_triggerFlush());
      });
    }
  }

  /// Immediately flushes all queued records to the underlying sink (D-24).
  Future<void> flush() async {
    if (_isDisposed) return;

    _debounceTimer?.cancel();
    _debounceTimer = null;

    while (_isFlushing) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }

    await _triggerFlush();
  }

  Future<void> _triggerFlush() async {
    if (_isFlushing || _buffer.isEmpty || _isDisposed) return;
    _isFlushing = true;

    try {
      final itemsToFlush = _buffer.values.toList();
      _buffer.clear();
      await onFlush(itemsToFlush);
    } catch (_) {
      // Defensive error isolation prevents buffer write failures from crashing app isolates
    } finally {
      _isFlushing = false;
      if (_buffer.isNotEmpty && !_isDisposed) {
        _debounceTimer = Timer(debounceDuration, () {
          unawaited(_triggerFlush());
        });
      }
    }
  }

  /// Disposes the write buffer queue, cancelling active timers and clearing RAM (D-24).
  void dispose() {
    _isDisposed = true;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _buffer.clear();
  }
}
