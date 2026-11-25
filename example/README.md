# fl_network_inspector Example

A multi-platform reference application demonstrating how to integrate and use `fl_network_inspector` across Android, iOS, Desktop (macOS, Windows, Linux), and Flutter Web.

## Features Demonstrated

The example app ([`lib/main.dart`](lib/main.dart)) showcases the complete feature set of `fl_network_inspector`:

- **GET Requests (`package:http`)**: Captured via `NetworkInspectorHttpClient` against `jsonplaceholder.typicode.com`.
- **POST Requests with Credential Redaction (`dio`)**: Captured via `NetworkInspectorDioInterceptor`, automatically redacting sensitive headers (`Authorization`) and JSON payload fields (`password`).
- **Multipart Upload Metadata Capture**: Sends an `http.MultipartRequest` and logs form fields, file name, MIME type, and byte size while discarding raw binary bytes.
- **Error Diagnostics**: Demonstrates HTTP 404 responses and socket/DNS failure capture with full exception details.
- **Manual API Logging**: Records custom protocol calls (e.g., GraphQL) directly via `NetworkInspector.logApi(...)`.
- **Cross-Platform Inspection Triggers**: Supports hardware shake-to-open via `NetworkInspectorWrapper` on physical mobile devices, as well as the AppBar bug report button (`Icons.bug_report`) and in-screen button calling `NetworkInspector.open(context)` on all platforms.

## Running the Example

### Mobile (Android & iOS)

Run the example on a connected physical device or emulator/simulator:

```bash
cd example
flutter pub get
flutter run
```

- **Inspection Trigger**: Shake your physical device to open the inspector via `NetworkInspectorWrapper` (uses `sensors_plus` with gravity isolation), or tap the `Icons.bug_report` button in the AppBar.
- **Storage**: Persists captured requests in native SQLite via `sqflite`.

### Desktop (macOS, Windows, Linux)

Run the example on your desktop target:

```bash
cd example
flutter pub get
flutter run -d macos    # or -d windows / -d linux
```

- **Storage**: Automatically initializes SQLite FFI via `sqflite_common_ffi` without extra setup.
- **Inspection Trigger**: Because desktop devices lack hardware accelerometers, use the AppBar bug report button (`Icons.bug_report`) or the **Open Network Inspector Screen** button.

### Flutter Web

Run the example in Chrome:

```bash
cd example
flutter pub get
flutter run -d chrome
```

- **Storage**: Automatically falls back to the bounded in-memory buffer (`InMemoryNetworkInspectorRepository`), since `dart:io` and native SQLite are unavailable on Web.
- **Traffic Capture**: Intercepts `Dio` (`NetworkInspectorDioInterceptor`) and `package:http` (`NetworkInspectorHttpClient`) requests.
- **Inspection Trigger**: Use the AppBar bug report button (`Icons.bug_report`) or the **Open Network Inspector Screen** button.

## Code Reference

See [`lib/main.dart`](lib/main.dart) for the complete initialization, `NetworkInspectorWrapper` setup, client adapter wiring, and request trigger implementations.
