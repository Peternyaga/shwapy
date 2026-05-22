import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'models/payment_details.dart';
import 'models/session.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/gemini_extraction_service.dart';
import 'services/image_processor.dart';
import 'services/mobile_llm_key_service.dart';
import 'services/secure_session_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  List<CameraDescription> cameras = const [];

  try {
    cameras = await availableCameras();
  } catch (_) {
    cameras = const [];
  }

  runApp(ShwapyApp(cameras: cameras));
}

class ShwapyApp extends StatefulWidget {
  const ShwapyApp({super.key, required this.cameras});

  final List<CameraDescription> cameras;

  @override
  State<ShwapyApp> createState() => _ShwapyAppState();
}

class _ShwapyAppState extends State<ShwapyApp> {
  late final ApiClient _api;
  late final SecureSessionStore _store;
  late final AuthService _auth;
  late final MobileLlmKeyService _keyService;
  late final GeminiExtractionService _extraction;
  AuthSession? _session;
  bool _booting = true;

  @override
  void initState() {
    super.initState();
    _api = ApiClient();
    _store = SecureSessionStore(const FlutterSecureStorage());
    _auth = AuthService(_api);
    _keyService = MobileLlmKeyService(_api, _store);
    _extraction = GeminiExtractionService(_api, _keyService);
    _boot();
  }

  Future<void> _boot() async {
    final session = await _store.load();
    _api.setToken(session?.token);
    setState(() {
      _session = session;
      _booting = false;
    });
  }

  Future<void> _setSession(AuthSession session) async {
    _api.setToken(session.token);
    await _store.save(session);
    setState(() => _session = session);
  }

  Future<void> _logout() async {
    try {
      await _auth.logout();
    } catch (_) {
      // Local logout must still succeed when the network is unavailable.
    }
    _api.setToken(null);
    _keyService.clear();
    await _store.clear();
    setState(() => _session = null);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Shwapy',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0B5B4A),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F8F5),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          isDense: true,
        ),
        useMaterial3: true,
      ),
      home: _booting
          ? const _Splash()
          : _session == null
              ? AuthScreen(
                  auth: _auth,
                  api: _api,
                  onAuthenticated: _setSession,
                )
              : CaptureScreen(
                  session: _session!,
                  cameras: widget.cameras,
                  extraction: _extraction,
                  onLogout: _logout,
                ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.auth,
    required this.api,
    required this.onAuthenticated,
  });

  final AuthService auth;
  final ApiClient api;
  final ValueChanged<AuthSession> onAuthenticated;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _signup = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final session = _signup
          ? await widget.auth.register(
              name: _name.text.trim(),
              email: _email.text.trim(),
              phoneNumber: _phone.text.trim(),
              password: _password.text,
            )
          : await widget.auth.login(
              email: _email.text.trim(),
              password: _password.text,
            );
      widget.onAuthenticated(session);
    } catch (error) {
      setState(() => _error = widget.api.messageFor(error));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _google() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final session = await widget.auth.loginWithGoogle(
        phoneNumber: _phone.text.trim(),
      );
      widget.onAuthenticated(session);
    } catch (error) {
      setState(() => _error = widget.api.messageFor(error));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Shwapy',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 28),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Login')),
                      ButtonSegment(value: true, label: Text('Signup')),
                    ],
                    selected: {_signup},
                    onSelectionChanged: (value) {
                      setState(() => _signup = value.first);
                    },
                  ),
                  const SizedBox(height: 16),
                  if (_signup)
                    TextField(
                      controller: _name,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                  if (_signup) const SizedBox(height: 10),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: _signup
                          ? 'Phone number'
                          : 'Phone number for first Google signup',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                    onSubmitted: (_) => _submit(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: Text(_signup ? 'Create account' : 'Login'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _busy ? null : _google,
                    child: const Text('Continue with Google'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({
    super.key,
    required this.session,
    required this.cameras,
    required this.extraction,
    required this.onLogout,
  });

  final AuthSession session;
  final List<CameraDescription> cameras;
  final GeminiExtractionService extraction;
  final VoidCallback onLogout;

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  final _processor = ImageProcessor();
  CameraController? _camera;
  bool _busy = false;
  String? _error;
  PaymentDetails? _details;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  @override
  void dispose() {
    _camera?.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    if (widget.cameras.isEmpty) {
      setState(() => _error = 'No camera is available on this device.');
      return;
    }

    final camera = CameraController(
      widget.cameras.first,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await camera.initialize();

    if (mounted) {
      setState(() => _camera = camera);
    }
  }

  Future<void> _capture() async {
    final camera = _camera;
    if (camera == null || _busy) {
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _details = null;
    });

    try {
      final file = await camera.takePicture();
      final prepared = await _processor.cropAndCompress(file.path);
      final details = await widget.extraction.extractImage(
        session: widget.session,
        image: prepared,
        phoneNumber: widget.session.user.phoneNumber,
      );
      setState(() => _details = details);
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shwapy'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: camera == null || !camera.value.isInitialized
                ? const Center(child: CircularProgressIndicator())
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      CameraPreview(camera),
                      const _CropOverlay(),
                      if (_busy)
                        Container(
                          color: Colors.black38,
                          alignment: Alignment.center,
                          child: const CircularProgressIndicator(),
                        ),
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                if (_details != null) _Result(details: _details!),
                FilledButton.icon(
                  onPressed: _busy ? null : _capture,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Capture'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CropOverlay extends StatelessWidget {
  const _CropOverlay();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final rect = Rect.fromLTWH(
          constraints.maxWidth * ImageProcessor.captureCrop.left,
          constraints.maxHeight * ImageProcessor.captureCrop.top,
          constraints.maxWidth * ImageProcessor.captureCrop.width,
          constraints.maxHeight * ImageProcessor.captureCrop.height,
        );

        return CustomPaint(painter: _CropPainter(rect));
      },
    );
  }
}

class _CropPainter extends CustomPainter {
  const _CropPainter(this.rect);

  final Rect rect;

  @override
  void paint(Canvas canvas, Size size) {
    final shade = Paint()..color = Colors.black.withOpacity(0.45);
    final clear = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8))),
    );
    canvas.drawPath(clear, shade);

    final border = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      border,
    );
  }

  @override
  bool shouldRepaint(covariant _CropPainter oldDelegate) {
    return oldDelegate.rect != rect;
  }
}

class _Result extends StatelessWidget {
  const _Result({required this.details});

  final PaymentDetails details;

  @override
  Widget build(BuildContext context) {
    final account = details.account;
    final accountValue = account.type == 'till'
        ? account.tillNo
        : [account.paybillNo, account.accountNo]
            .whereType<String>()
            .where((value) => value.isNotEmpty)
            .join(' / ');
    final primary = accountValue == null || accountValue.isEmpty
        ? 'Unknown'
        : accountValue;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E3DB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            account.merchantName ?? 'Payment details',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text('${account.type.toUpperCase()}: $primary'),
          Text(
            'Amount: ${details.amount?.toStringAsFixed(0) ?? '-'} ${details.currency}',
          ),
          Text('Confidence: ${(details.confidence * 100).round()}%'),
          if (details.missingFields.isNotEmpty)
            Text('Missing: ${details.missingFields.join(', ')}'),
        ],
      ),
    );
  }
}
