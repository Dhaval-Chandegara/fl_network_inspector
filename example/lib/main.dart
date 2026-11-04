import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:fl_network_inspector/fl_network_inspector.dart';
import 'package:http/http.dart' as http;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Network Inspector
  await NetworkInspector.initialize(
    config: const NetworkInspectorConfig(
      enabled: true,
      enableDatabase: true,
      enableShakeDetection: true,
      shakeThreshold: 15.0,
      shakeDebounceMs: 1500,
    ),
  );

  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return NetworkInspectorWrapper(
      child: MaterialApp(
        navigatorKey: NetworkInspector.navigatorKey,
        title: 'Network Inspector Demo',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final dio = Dio()..interceptors.add(const NetworkInspectorDioInterceptor());
  final httpClient = NetworkInspectorHttpClient();
  String _lastStatus = 'Ready. Tap any button below to trigger network activity.';
  bool _isLoading = false;

  void _setStatus(String status) {
    setState(() {
      _lastStatus = status;
      _isLoading = false;
    });
  }

  Future<void> _sendGetRequest() async {
    setState(() => _isLoading = true);
    try {
      final response = await httpClient.get(
        Uri.parse('https://jsonplaceholder.typicode.com/posts/1'),
        headers: {'Accept': 'application/json'},
      );
      _setStatus('GET Succeeded: HTTP ${response.statusCode}');
    } catch (e) {
      _setStatus('GET Failed: $e');
    }
  }

  Future<void> _sendPostDioRequest() async {
    setState(() => _isLoading = true);
    try {
      final response = await dio.post<Map<String, dynamic>>(
        'https://jsonplaceholder.typicode.com/posts',
        data: {
          'title': 'Test Post',
          'body': 'This is sample payload content.',
          'userId': 42,
          'password': 'secret_password_123', // Will be redacted
        },
        options: Options(
          headers: {'Authorization': 'Bearer super-secret-token'},
        ),
      );
      _setStatus('Dio POST Succeeded: HTTP ${response.statusCode}');
    } catch (e) {
      _setStatus('Dio POST Error: $e');
    }
  }

  Future<void> _sendMultipartRequest() async {
    setState(() => _isLoading = true);
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://httpbin.org/post'),
      );
      request.fields['description'] = 'Sample user avatar upload';
      request.files.add(
        http.MultipartFile.fromBytes(
          'avatar',
          utf8.encode('fake image bytes content'),
          filename: 'avatar.png',
        ),
      );

      final streamed = await httpClient.send(request);
      final response = await http.Response.fromStream(streamed);
      _setStatus('Multipart POST Succeeded: HTTP ${response.statusCode}');
    } catch (e) {
      _setStatus('Multipart Error: $e');
    }
  }

  Future<void> _sendError404Request() async {
    setState(() => _isLoading = true);
    try {
      final response = await httpClient.get(
        Uri.parse('https://jsonplaceholder.typicode.com/non_existent_endpoint_404'),
      );
      _setStatus('404 Request Received: HTTP ${response.statusCode}');
    } catch (e) {
      _setStatus('Request Error: $e');
    }
  }

  Future<void> _sendNetworkFailure() async {
    setState(() => _isLoading = true);
    try {
      await httpClient.get(
        Uri.parse('https://invalid-host-domain-that-does-not-exist.local/api'),
      );
      _setStatus('Unexpected Success');
    } catch (e) {
      _setStatus('Network Failure Handled: ${e.runtimeType}');
    }
  }

  Future<void> _logManualApi() async {
    await NetworkInspector.logApi(
      method: 'GRAPHQL',
      url: 'https://api.example.com/graphql',
      statusCode: 200,
      requestHeaders: {'Content-Type': 'application/json'},
      responseHeaders: {'Content-Type': 'application/json'},
      requestBody: {
        'query': 'query GetUser { user(id: "42") { id name email } }',
      },
      responseBody: {
        'data': {
          'user': {'id': '42', 'name': 'Alice Smith', 'email': 'alice@example.com'},
        },
      },
      duration: const Duration(milliseconds: 145),
    );
    _setStatus('Manual GraphQL Log Recorded!');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter Network Inspector Demo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            tooltip: 'Open Inspector',
            onPressed: () => NetworkInspector.open(context),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.vibration, color: theme.colorScheme.onPrimaryContainer),
                        const SizedBox(width: 8),
                        Text(
                          'Shake to Open Inspector',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Shake your physical device to open the inspector, or tap the bug icon in the AppBar / button below.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Last Activity Status:', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 4),
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: LinearProgressIndicator(),
                      )
                    else
                      Text(
                        _lastStatus,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => NetworkInspector.open(context),
              icon: const Icon(Icons.visibility),
              label: const Text('Open Network Inspector Screen'),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Text('Trigger HTTP Requests:', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _sendGetRequest,
              icon: const Icon(Icons.download),
              label: const Text('Send HTTP GET (package:http)'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _sendPostDioRequest,
              icon: const Icon(Icons.upload),
              label: const Text('Send JSON POST (Dio with redaction)'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _sendMultipartRequest,
              icon: const Icon(Icons.attach_file),
              label: const Text('Send Multipart Upload (Metadata only)'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _sendError404Request,
              icon: const Icon(Icons.error_outline),
              label: const Text('Send HTTP 404 Not Found Request'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _sendNetworkFailure,
              icon: const Icon(Icons.wifi_off),
              label: const Text('Simulate Network Failure (Socket Error)'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _logManualApi,
              icon: const Icon(Icons.code),
              label: const Text('Log Custom Manual Call (GraphQL)'),
            ),
          ],
        ),
      ),
    );
  }
}
