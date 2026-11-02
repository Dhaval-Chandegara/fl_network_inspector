import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/body_type.dart';
import '../models/multipart_entry.dart';
import '../models/network_record.dart';
import '../models/network_status.dart';
import 'components/copy_button.dart';
import 'components/export_action_sheet.dart';
import 'components/json_viewer.dart';
import 'components/status_badge.dart';
import 'utils/curl_generator.dart';

/// Full-screen 4-tab inspection screen for examining HTTP request details (UI-07, D-57).
class NetworkInspectorDetailScreen extends StatelessWidget {
  final NetworkRecord record;

  static final DateFormat _timeFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

  const NetworkInspectorDetailScreen({
    super.key,
    required this.record,
  });

  String _formatHeaders(Map<String, dynamic>? headers) {
    if (headers == null || headers.isEmpty) return 'No headers';
    final buffer = StringBuffer();
    headers.forEach((k, v) {
      buffer.writeln('$k: $v');
    });
    return buffer.toString().trim();
  }

  String _formatPayloadSize() {
    final reqBytes = record.requestBody?.byteSize ?? record.requestSize;
    final resBytes = record.responseBody?.byteSize ?? record.responseSize ?? 0;
    final totalBytes = reqBytes + resBytes;
    if (totalBytes < 1024) {
      return '$totalBytes B';
    }
    return '${(totalBytes / 1024).toStringAsFixed(1)} KB';
  }

  void _copyCurl(BuildContext context) {
    final curl = CurlGenerator.fromRecord(record);
    Clipboard.setData(ClipboardData(text: curl));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied cURL to clipboard'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _shareDetails(BuildContext context) {
    ExportActionSheet.show(context, record: record);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Request Details',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.terminal_rounded),
              tooltip: 'Copy as cURL',
              onPressed: () => _copyCurl(context),
            ),
            IconButton(
              icon: const Icon(Icons.share_rounded),
              tooltip: 'Share request details',
              onPressed: () => _shareDetails(context),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Container(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              child: const TabBar(
                indicatorColor: Color(0xFF2563EB),
                labelColor: Color(0xFF2563EB),
                unselectedLabelColor: Color(0xFF64748B),
                labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                tabs: [
                  Tab(text: 'Overview'),
                  Tab(text: 'Request'),
                  Tab(text: 'Response'),
                  Tab(text: 'Error'),
                ],
              ),
            ),
          ),
        ),
        body: Column(
          children: [
            // Header Summary Card
            _buildHeaderSummaryCard(context, isDark),

            // Tab Views
            Expanded(
              child: TabBarView(
                children: [
                  _buildOverviewTab(context, isDark),
                  _buildRequestTab(context, isDark),
                  _buildResponseTab(context, isDark),
                  _buildErrorTab(context, isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSummaryCard(BuildContext context, bool isDark) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MethodBadge(method: record.method),
              const SizedBox(width: 8),
              StatusBadge(
                statusCode: record.statusCode,
                status: record.status,
              ),
              const Spacer(),
              if (record.status != NetworkStatus.pending && record.durationMs != null)
                Text(
                  '${record.durationMs} ms',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              const SizedBox(width: 8),
              Text(
                _formatPayloadSize(),
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  record.url,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              CopyButton(
                textProvider: () => record.url,
                sectionName: 'URL',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(BuildContext context, bool isDark) {
    final infoRows = <MapEntry<String, String>>[
      MapEntry('URL', record.url),
      MapEntry('Method', record.method),
      MapEntry('Status Code', record.statusCode?.toString() ?? 'Pending'),
      MapEntry('Status', record.status.name.toUpperCase()),
      MapEntry('Duration', record.durationMs != null ? '${record.durationMs} ms' : 'In-flight'),
      MapEntry('Request Time', _timeFormat.format(record.requestTimestamp)),
      if (record.responseTimestamp != null)
        MapEntry('Response Time', _timeFormat.format(record.responseTimestamp!)),
      MapEntry('Base URL', record.baseUrl),
      MapEntry('Path', record.path),
      if (record.requestContentType != null)
        MapEntry('Request Content-Type', record.requestContentType!),
      if (record.responseContentType != null)
        MapEntry('Response Content-Type', record.responseContentType!),
      MapEntry('Request Size', '${record.requestSize} bytes'),
      if (record.responseSize != null)
        MapEntry('Response Size', '${record.responseSize} bytes'),
    ];

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        if (record.error != null)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    record.error!.message,
                    style: const TextStyle(
                      color: Color(0xFF991B1B),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        _buildKeyValueTable(infoRows, isDark),
      ],
    );
  }

  Widget _buildRequestTab(BuildContext context, bool isDark) {
    final headers = record.requestHeaders;
    final queryParams = record.requestQueryParams;
    final multiparts = record.multipartEntries;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Headers
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Request Headers',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            CopyButton(
              textProvider: () => _formatHeaders(headers),
              sectionName: 'Request Headers',
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (headers.isEmpty)
          const Text('No headers', style: TextStyle(fontStyle: FontStyle.italic))
        else
          _buildKeyValueTable(
            headers.entries.map((e) => MapEntry(e.key, e.value.toString())).toList(),
            isDark,
          ),
        const SizedBox(height: 24),

        // Query parameters
        if (queryParams.isNotEmpty) ...[
          const Text(
            'Query Parameters',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          _buildKeyValueTable(
            queryParams.entries.map((e) => MapEntry(e.key, e.value.toString())).toList(),
            isDark,
          ),
          const SizedBox(height: 24),
        ],

        // Multipart entries
        if (multiparts != null && multiparts.isNotEmpty) ...[
          const Text(
            'Multipart Uploads',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ...multiparts.map((entry) => _buildMultipartCard(entry, isDark)),
          const SizedBox(height: 24),
        ],

        // Request body
        JsonViewerWidget(
          rawPayload: record.requestBody?.body,
          bodyType: record.requestBody?.bodyType ?? BodyType.empty,
          isTruncated: record.requestBody?.isTruncated ?? false,
          title: 'Request Body',
        ),
      ],
    );
  }

  Widget _buildResponseTab(BuildContext context, bool isDark) {
    final headers = record.responseHeaders;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Headers
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Response Headers',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            CopyButton(
              textProvider: () => _formatHeaders(headers),
              sectionName: 'Response Headers',
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (headers == null || headers.isEmpty)
          const Text('No headers recorded', style: TextStyle(fontStyle: FontStyle.italic))
        else
          _buildKeyValueTable(
            headers.entries.map((e) => MapEntry(e.key, e.value.toString())).toList(),
            isDark,
          ),
        const SizedBox(height: 24),

        // Response body
        JsonViewerWidget(
          rawPayload: record.responseBody?.body,
          bodyType: record.responseBody?.bodyType ?? BodyType.empty,
          isTruncated: record.responseBody?.isTruncated ?? false,
          title: 'Response Body',
        ),
      ],
    );
  }

  Widget _buildErrorTab(BuildContext context, bool isDark) {
    final error = record.error;

    if (error == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline_rounded, size: 64, color: Color(0xFF16A34A)),
              SizedBox(height: 16),
              Text(
                'No errors encountered for this request',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF16A34A),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildKeyValueTable([
          MapEntry('Error Message', error.message),
          if (error.errorType != null) MapEntry('Exception Class', error.errorType!),
          if (error.statusCode != null) MapEntry('Status Code', error.statusCode.toString()),
        ], isDark),
        const SizedBox(height: 24),

        if (error.stackTrace != null && error.stackTrace!.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Stack Trace',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              CopyButton(
                textProvider: () => error.stackTrace!,
                sectionName: 'Stack Trace',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A1B1B) : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? const Color(0xFF5A2A2A) : const Color(0xFFFCA5A5),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText(
                error.stackTrace!,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMultipartCard(MultipartEntry entry, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Field: ${entry.fieldName}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          if (entry.fileName != null)
            Text(
              'File: ${entry.fileName}',
              style: const TextStyle(fontSize: 13),
            ),
          if (entry.contentType != null)
            Text(
              'MIME: ${entry.contentType}',
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
            ),
          Text(
            'Size: ${entry.byteSize} bytes',
            style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
          ),
          if (entry.filePath != null)
            Text(
              'Path: ${entry.filePath}',
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
            ),
        ],
      ),
    );
  }

  Widget _buildKeyValueTable(List<MapEntry<String, String>> rows, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Table(
        columnWidths: const {
          0: IntrinsicColumnWidth(),
          1: FlexColumnWidth(),
        },
        border: TableBorder(
          horizontalInside: BorderSide(
            color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE5E7EB),
            width: 1,
          ),
        ),
        children: rows.map((entry) {
          return TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  entry.key,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: SelectableText(
                  entry.value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
