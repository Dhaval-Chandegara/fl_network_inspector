import 'package:flutter/material.dart';

import '../../models/network_status.dart';

/// Semantic color-coded badge displaying an HTTP method (GET, POST, etc.) (D-53).
class MethodBadge extends StatelessWidget {
  /// The uppercase HTTP method name (e.g. 'GET', 'POST').
  final String method;

  const MethodBadge({
    super.key,
    required this.method,
  });

  static Color getColor(String method) {
    switch (method.toUpperCase()) {
      case 'GET':
        return const Color(0xFF0284C7); // Blue
      case 'POST':
        return const Color(0xFF16A34A); // Green
      case 'PUT':
        return const Color(0xFFD97706); // Amber
      case 'DELETE':
        return const Color(0xFFDC2626); // Red
      case 'PATCH':
        return const Color(0xFF7C3AED); // Purple
      case 'HEAD':
      case 'OPTIONS':
      default:
        return const Color(0xFF64748B); // Slate
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = getColor(method);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        method.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          height: 1.33,
        ),
      ),
    );
  }
}

/// Semantic color-coded badge displaying an HTTP status code or status state (D-53).
class StatusBadge extends StatelessWidget {
  /// HTTP status code (e.g. 200, 404, 500). May be null if pending or socket failure.
  final int? statusCode;

  /// Network lifecycle status (pending, success, failed).
  final NetworkStatus status;

  const StatusBadge({
    super.key,
    this.statusCode,
    required this.status,
  });

  static Color getColor({int? statusCode, required NetworkStatus status}) {
    if (status == NetworkStatus.pending) {
      return const Color(0xFF64748B); // Slate (Pending)
    }
    if (status == NetworkStatus.failed && statusCode == null) {
      return const Color(0xFFDC2626); // Red (ERR)
    }
    if (statusCode != null) {
      if (statusCode >= 200 && statusCode < 300) {
        return const Color(0xFF16A34A); // Green
      } else if (statusCode >= 300 && statusCode < 400) {
        return const Color(0xFF2563EB); // Blue
      } else if (statusCode >= 400 && statusCode < 500) {
        return const Color(0xFFD97706); // Amber
      } else if (statusCode >= 500) {
        return const Color(0xFFDC2626); // Red
      }
    }
    return const Color(0xFF64748B);
  }

  static String getLabel({int? statusCode, required NetworkStatus status}) {
    if (status == NetworkStatus.pending) {
      return 'Pending';
    }
    if (statusCode != null) {
      return statusCode.toString();
    }
    if (status == NetworkStatus.failed) {
      return 'ERR';
    }
    return '---';
  }

  @override
  Widget build(BuildContext context) {
    final color = getColor(statusCode: statusCode, status: status);
    final label = getLabel(statusCode: statusCode, status: status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          height: 1.33,
        ),
      ),
    );
  }
}
