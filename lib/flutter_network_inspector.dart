/// Flutter Network Inspector
///
/// A reusable, modular, lightweight, and production-safe Flutter package
/// that captures, stores, manages, and displays HTTP network requests and
/// responses made by a Flutter application.
library flutter_network_inspector;

// Configuration
export 'src/config/network_inspector_config.dart';

// Core Facade & Constants
export 'src/core/constants.dart';
export 'src/core/network_inspector.dart';

// Repository & Storage
export 'src/repository/in_memory_network_inspector_repository.dart';
export 'src/repository/network_inspector_repository.dart';
export 'src/repository/sqlite_network_inspector_repository.dart';

// Domain Models
export 'src/models/body_type.dart';
export 'src/models/http_error_details.dart';
export 'src/models/multipart_entry.dart';
export 'src/models/network_record.dart';
export 'src/models/network_status.dart';
export 'src/models/payload_data.dart';
export 'src/models/record_filter.dart';
export 'src/models/record_sort.dart';

// Utilities
export 'src/utils/body_type_detector.dart';
export 'src/utils/payload_truncator.dart';
export 'src/utils/redaction_engine.dart';
export 'src/utils/uuid_generator.dart';

// Client Adapters
export 'src/interceptor/dio/network_inspector_dio_interceptor.dart';
export 'src/interceptor/http/network_inspector_http_client.dart';

// Manual Logging & Request Tracking
export 'src/logging/network_request_tracker.dart';
export 'src/logging/no_op_network_request_tracker.dart';

// UI Presentation & Screens (UI-01, UI-07, D-49)
export 'src/ui/network_inspector_detail_screen.dart';
export 'src/ui/network_inspector_screen.dart';

// Shake Detection & Developer Experience (SHAKE-01, DEV-01, DEV-02)
export 'src/shake/shake_detector.dart';
export 'src/ui/widgets/network_inspector_wrapper.dart';

