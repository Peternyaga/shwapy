import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';

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
        fontFamily: 'DM Sans',
        colorScheme: ColorScheme.fromSeed(
          seedColor: _ShwapyColors.green,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: _ShwapyColors.surface,
        inputDecorationTheme: const InputDecorationTheme(
          border: UnderlineInputBorder(),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: _ShwapyColors.green, width: 1.5),
          ),
          isDense: true,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: _ShwapyColors.green,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            minimumSize: const Size.fromHeight(48),
          ),
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
              : _DashboardScreen(
                  session: _session!,
                  cameras: widget.cameras,
                  api: _api,
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

class _ShwapyColors {
  static const green = Color(0xFF00A86B);
  static const greenDark = Color(0xFF007A4D);
  static const greenLight = Color(0xFFE6F7F0);
  static const text = Color(0xFF0D1117);
  static const text2 = Color(0xFF5A6475);
  static const text3 = Color(0xFF9BA5B0);
  static const surface = Color(0xFFF4F7FB);
  static const border = Color(0x12000000);
  static const danger = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);
}

enum _DashboardTab { home, history }

enum _PaymentStage { dashboard, scan, paste, confirm, processing, success }

class _DashboardScreen extends StatefulWidget {
  const _DashboardScreen({
    required this.session,
    required this.cameras,
    required this.api,
    required this.extraction,
    required this.onLogout,
  });

  final AuthSession session;
  final List<CameraDescription> cameras;
  final ApiClient api;
  final GeminiExtractionService extraction;
  final VoidCallback onLogout;

  @override
  State<_DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<_DashboardScreen> {
  _DashboardTab _tab = _DashboardTab.home;
  _PaymentStage _stage = _PaymentStage.dashboard;
  _PaymentDraft? _draft;
  _CheckoutResult? _checkoutResult;
  String? _error;
  bool _busy = false;
  String? _profileImagePath;
  Timer? _historyTimer;

  final List<_RecentPayment> _recent = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _historyTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _loadHistory(showError: false),
    );
  }

  @override
  void dispose() {
    _historyTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadHistory({bool showError = true}) async {
    try {
      final response = await widget.api.dio.get('/payments');
      final items = (response.data['data'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => _RecentPayment.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .toList();

      _CheckoutResult? refreshedResult;
      final activeId = _checkoutResult?.transactionId;
      if (activeId != null) {
        for (final item in items) {
          if (item.id.toString() == activeId.toString()) {
            refreshedResult = _CheckoutResult(
              transactionId: item.id,
              status: item.status,
              message: item.resultDescription ?? _checkoutResult!.message,
            );
            break;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _recent
          ..clear()
          ..addAll(items);
        if (refreshedResult != null) {
          _checkoutResult = refreshedResult;
          if (refreshedResult.status == 'success' &&
              _stage == _PaymentStage.processing) {
            _stage = _PaymentStage.success;
          }
        }
      });
    } catch (error) {
      if (showError && mounted) {
        setState(() => _error = widget.api.messageFor(error));
      }
    }
  }

  void _openScan() {
    setState(() {
      _stage = _PaymentStage.scan;
      _error = null;
    });
  }

  void _openPaste() {
    setState(() {
      _stage = _PaymentStage.paste;
      _error = null;
    });
  }

  Future<void> _extractPastedText(String content) async {
    final value = content.trim();
    if (value.isEmpty) {
      setState(() => _error = 'Paste payment details before extracting.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final details = await widget.extraction.extractText(
        session: widget.session,
        content: value,
        phoneNumber: widget.session.user.phoneNumber,
      );
      _review(details);
    } catch (error) {
      setState(() => _error = widget.api.messageFor(error));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _manualPayment(String type) {
    setState(() {
      _draft = _PaymentDraft.manual(type, widget.session);
      _stage = _PaymentStage.confirm;
      _tab = _DashboardTab.home;
      _checkoutResult = null;
      _error = null;
    });
  }

  void _repeatPayment(_RecentPayment payment) {
    setState(() {
      _draft = _PaymentDraft.fromRecent(payment, widget.session);
      _stage = _PaymentStage.confirm;
      _tab = _DashboardTab.home;
      _checkoutResult = null;
      _error = null;
    });
  }

  Future<void> _showProfile() async {
    final nextImagePath = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return _ProfileSheet(
          session: widget.session,
          imagePath: _profileImagePath,
          onLogout: () {
            Navigator.of(context).pop();
            widget.onLogout();
          },
        );
      },
    );

    if (nextImagePath != null && mounted) {
      setState(() => _profileImagePath = nextImagePath);
    }
  }

  void _review(PaymentDetails details) {
    setState(() {
      _draft = _PaymentDraft.fromDetails(details, widget.session);
      _stage = _PaymentStage.confirm;
      _tab = _DashboardTab.home;
      _checkoutResult = null;
      _error = null;
    });
  }

  Future<void> _checkout(_PaymentDraft draft) async {
    final validationError = draft.validationError;
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final response = await widget.api.dio.post('/payments/checkout', data: {
        'payment_account': draft.paymentAccountPayload,
        'amount': draft.amountNumber,
        'phone_number': draft.phoneNumber,
        'extraction_confidence': draft.confidence,
        'raw_extraction': draft.rawExtraction,
      });

      final result = _CheckoutResult.fromJson(
        Map<String, dynamic>.from(response.data['data'] as Map),
      );
      setState(() {
        _draft = draft;
        _checkoutResult = result;
        _stage = _PaymentStage.processing;
      });
      await _loadHistory(showError: false);
    } catch (error) {
      setState(() => _error = widget.api.messageFor(error));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _backHome() {
    setState(() {
      _stage = _PaymentStage.dashboard;
      _tab = _DashboardTab.home;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (_stage) {
      case _PaymentStage.scan:
        return _CameraScanScreen(
          session: widget.session,
          cameras: widget.cameras,
          extraction: widget.extraction,
          onBack: _backHome,
          onExtracted: _review,
        );
      case _PaymentStage.paste:
        return _PasteTextScreen(
          busy: _busy,
          error: _error,
          onBack: _backHome,
          onExtract: _extractPastedText,
        );
      case _PaymentStage.confirm:
        return _ConfirmPaymentScreen(
          draft: _draft!,
          busy: _busy,
          error: _error,
          onBack: _backHome,
          onCheckout: _checkout,
        );
      case _PaymentStage.processing:
        return _ProcessingScreen(
          draft: _draft!,
          result: _checkoutResult,
          onHome: _backHome,
        );
      case _PaymentStage.success:
        return _SuccessScreen(
          draft: _draft!,
          result: _checkoutResult,
          onHome: _backHome,
        );
      case _PaymentStage.dashboard:
        return Scaffold(
          body: SafeArea(
            child: _tab == _DashboardTab.home
                ? _HomeDashboard(
                    session: widget.session,
                    recent: _recent,
                    busy: _busy,
                    error: _error,
                    onScan: _openScan,
                    onPaste: _openPaste,
                    onManualPaybill: () => _manualPayment('paybill'),
                    onManualTill: () => _manualPayment('till'),
                    onProfile: _showProfile,
                    profileImagePath: _profileImagePath,
                  )
                : _HistoryScreen(
                    recent: _recent,
                    onBack: _backHome,
                    onRefresh: _loadHistory,
                    onPayAgain: _repeatPayment,
                  ),
          ),
          bottomNavigationBar: _ShwapyBottomNav(
            tab: _tab,
            onChanged: (tab) => setState(() => _tab = tab),
            onScan: _openScan,
          ),
        );
    }
  }
}

class _HomeDashboard extends StatelessWidget {
  const _HomeDashboard({
    required this.session,
    required this.recent,
    required this.busy,
    required this.error,
    required this.onScan,
    required this.onPaste,
    required this.onManualPaybill,
    required this.onManualTill,
    required this.onProfile,
    required this.profileImagePath,
  });

  final AuthSession session;
  final List<_RecentPayment> recent;
  final bool busy;
  final String? error;
  final VoidCallback onScan;
  final VoidCallback onPaste;
  final VoidCallback onManualPaybill;
  final VoidCallback onManualTill;
  final VoidCallback onProfile;
  final String? profileImagePath;

  @override
  Widget build(BuildContext context) {
    final firstName = session.user.name.split(' ').first;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 12, 12, 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_greetingFor(DateTime.now())}, $firstName',
                      style: const TextStyle(
                        color: _ShwapyColors.text2,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'What would you\nlike to pay?',
                      style: TextStyle(
                        color: _ShwapyColors.text,
                        fontSize: 28,
                        height: 1.1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: onProfile,
                borderRadius: BorderRadius.circular(16),
                child: _ProfileAvatar(
                  session: session,
                  imagePath: profileImagePath,
                  size: 46,
                  showBadge: true,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _ShwapyColors.green,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'QUICK ACTION',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Scan a bill to\nextract details',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _HeroAction(
                        icon: Icons.camera_alt,
                        label: 'Scan',
                        onTap: onScan,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _HeroAction(
                        icon: Icons.content_paste,
                        label: 'Paste',
                        onTap: onPaste,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (busy)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: LinearProgressIndicator(color: _ShwapyColors.green),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: _InlineWarning(message: error!, danger: true),
          ),
        const _SectionLabel('Quick Pay'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _QuickPayCard(
                  icon: Icons.account_balance,
                  title: 'Paybill',
                  subtitle: 'Pay a business',
                  color: _ShwapyColors.greenDark,
                  background: _ShwapyColors.greenLight,
                  onTap: onManualPaybill,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickPayCard(
                  icon: Icons.phone_android,
                  title: 'Till',
                  subtitle: 'Buy goods',
                  color: const Color(0xFF185FA5),
                  background: const Color(0xFFEBF5FF),
                  onTap: onManualTill,
                ),
              ),
            ],
          ),
        ),
        const _SectionLabel('Recent Payments'),
        if (recent.isEmpty)
          const _EmptyPaymentsState()
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                for (final item in recent.take(4)) ...[
                  _TransactionTile(payment: item),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _CameraScanScreen extends StatefulWidget {
  const _CameraScanScreen({
    required this.session,
    required this.cameras,
    required this.extraction,
    required this.onBack,
    required this.onExtracted,
  });

  final AuthSession session;
  final List<CameraDescription> cameras;
  final GeminiExtractionService extraction;
  final VoidCallback onBack;
  final ValueChanged<PaymentDetails> onExtracted;

  @override
  State<_CameraScanScreen> createState() => _CameraScanScreenState();
}

class _CameraScanScreenState extends State<_CameraScanScreen> {
  final _processor = ImageProcessor();
  CameraController? _camera;
  bool _busy = false;
  String? _error;
  String? _capturedPath;

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
    try {
      await camera.initialize();
    } catch (error) {
      await camera.dispose();
      if (mounted) {
        setState(() => _error = 'Could not start the camera. Please try again.');
      }
      return;
    }

    if (mounted) {
      setState(() {
        _camera = camera;
        _capturedPath = null;
      });
    } else {
      await camera.dispose();
    }
  }

  Future<void> _capture() async {
    if (_busy) {
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      var path = _capturedPath;
      if (path == null) {
        final camera = _camera;
        if (camera == null || !camera.value.isInitialized) return;
        final file = await camera.takePicture();
        path = file.path;
        _camera = null;
        await camera.dispose();
        if (mounted) setState(() => _capturedPath = path);
      }

      final prepared = await _processor.cropAndCompress(path);
      final details = await widget.extraction.extractImage(
        session: widget.session,
        image: prepared,
        phoneNumber: widget.session.user.phoneNumber,
      );
      widget.onExtracted(details);
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _retake() async {
    if (_busy) return;
    setState(() {
      _capturedPath = null;
      _error = null;
    });
    await _initCamera();
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan bill'),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: _capturedPath != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(File(_capturedPath!), fit: BoxFit.cover),
                        Container(color: Colors.black26),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_busy)
                                  const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                else
                                  const Icon(
                                    Icons.image_outlined,
                                    color: Colors.white,
                                  ),
                                const SizedBox(width: 12),
                                Text(
                                  _busy
                                      ? 'Uploading and extracting...'
                                      : 'Photo ready to retry',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : camera == null || !camera.value.isInitialized
                      ? const Center(child: CircularProgressIndicator())
                      : Stack(
                    fit: StackFit.expand,
                    children: [
                      CameraPreview(camera),
                      const _CropOverlay(),
                    ],
                  ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  SizedBox(
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _capture,
                      icon: const Icon(Icons.camera_alt),
                      label: Text(_capturedPath != null
                          ? 'Try extraction again'
                          : 'Capture bill'),
                    ),
                  ),
                  if (_capturedPath != null && !_busy)
                    TextButton(
                      onPressed: _retake,
                      child: const Text('Retake photo'),
                    ),
                ],
              ),
            ),
          ],
        ),
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
    final shade = Paint()..color = Colors.black.withValues(alpha: 0.45);
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

class _PasteTextScreen extends StatefulWidget {
  const _PasteTextScreen({
    required this.busy,
    required this.error,
    required this.onBack,
    required this.onExtract,
  });

  final bool busy;
  final String? error;
  final VoidCallback onBack;
  final ValueChanged<String> onExtract;

  @override
  State<_PasteTextScreen> createState() => _PasteTextScreenState();
}

class _PasteTextScreenState extends State<_PasteTextScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paste Payment Details'),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: _cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Payment text',
                    style: TextStyle(
                      color: _ShwapyColors.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _controller,
                    minLines: 8,
                    maxLines: 12,
                    autofocus: true,
                    decoration: const InputDecoration(
                      alignLabelWithHint: true,
                      labelText: 'Paste bill or message',
                    ),
                  ),
                  if (widget.error != null) ...[
                    const SizedBox(height: 12),
                    _InlineWarning(message: widget.error!, danger: true),
                  ],
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: widget.busy
                        ? null
                        : () => widget.onExtract(_controller.text),
                    icon: widget.busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.auto_fix_high),
                    label: Text(
                      widget.busy ? 'Extracting details...' : 'Extract details',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmPaymentScreen extends StatefulWidget {
  const _ConfirmPaymentScreen({
    required this.draft,
    required this.busy,
    required this.error,
    required this.onBack,
    required this.onCheckout,
  });

  final _PaymentDraft draft;
  final bool busy;
  final String? error;
  final VoidCallback onBack;
  final ValueChanged<_PaymentDraft> onCheckout;

  @override
  State<_ConfirmPaymentScreen> createState() => _ConfirmPaymentScreenState();
}

class _ConfirmPaymentScreenState extends State<_ConfirmPaymentScreen> {
  late final TextEditingController _merchant;
  late final TextEditingController _paybill;
  late final TextEditingController _account;
  late final TextEditingController _till;
  late final TextEditingController _amount;
  late final TextEditingController _phone;
  late String _type;

  @override
  void initState() {
    super.initState();
    final draft = widget.draft;
    _type = draft.type == 'till' ? 'till' : 'paybill';
    _merchant = TextEditingController(text: draft.merchantName);
    _paybill = TextEditingController(text: draft.paybillNo);
    _account = TextEditingController(text: draft.accountNo);
    _till = TextEditingController(text: draft.tillNo);
    _amount = TextEditingController(text: draft.amount);
    _phone = TextEditingController(text: draft.phoneNumber);
    for (final controller in [
      _merchant,
      _paybill,
      _account,
      _till,
      _amount,
      _phone,
    ]) {
      controller.addListener(_refresh);
    }
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _merchant,
      _paybill,
      _account,
      _till,
      _amount,
      _phone,
    ]) {
      controller.removeListener(_refresh);
    }
    _merchant.dispose();
    _paybill.dispose();
    _account.dispose();
    _till.dispose();
    _amount.dispose();
    _phone.dispose();
    super.dispose();
  }

  _PaymentDraft _currentDraft() {
    return widget.draft.copyWith(
      type: _type,
      merchantName: _merchant.text.trim(),
      paybillNo: _paybill.text.trim(),
      accountNo: _account.text.trim(),
      tillNo: _till.text.trim(),
      amount: _amount.text.trim(),
      phoneNumber: _phone.text.trim(),
    );
  }

  bool get _canCheckout {
    final amount = double.tryParse(_amount.text.trim()) ?? 0;
    final hasAccount = _type == 'paybill'
        ? _paybill.text.trim().isNotEmpty && _account.text.trim().isNotEmpty
        : _till.text.trim().isNotEmpty;
    return amount > 0 && _phone.text.trim().isNotEmpty && hasAccount;
  }

  @override
  Widget build(BuildContext context) {
    final confidence = (widget.draft.confidence * 100).round();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm Payment'),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!widget.draft.isManual) ...[
            _ConfidenceCard(confidence: confidence),
            const SizedBox(height: 10),
          ],
          _MerchantBadge(
            merchant: _merchant.text.trim(),
            type: _type,
          ),
          const SizedBox(height: 10),
          _AmountCard(amount: _amount.text),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            decoration: _cardDecoration(),
            child: Column(
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'paybill', label: Text('Paybill')),
                    ButtonSegment(value: 'till', label: Text('Till')),
                  ],
                  selected: {_type},
                  onSelectionChanged: (value) {
                    setState(() => _type = value.first);
                  },
                ),
                const SizedBox(height: 8),
                _EditableField(label: 'Merchant', controller: _merchant),
                if (_type == 'paybill') ...[
                  _EditableField(label: 'Paybill no.', controller: _paybill),
                  _EditableField(label: 'Account no.', controller: _account),
                ] else
                  _EditableField(label: 'Till no.', controller: _till),
                _EditableField(
                  label: 'Phone no.',
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                ),
                _EditableField(
                  label: 'Amount',
                  controller: _amount,
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (widget.draft.missingFields.isNotEmpty)
            _InlineWarning(
              message: 'Missing: ${widget.draft.missingFields.join(', ')}',
            )
          else
            const _InlineWarning(
              message:
                  'Please verify the account number before proceeding. Incorrect account numbers may cause payment delays.',
            ),
          if (widget.error != null) ...[
            const SizedBox(height: 10),
            _InlineWarning(message: widget.error!, danger: true),
          ],
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: widget.busy || !_canCheckout
                ? null
                : () => widget.onCheckout(_currentDraft()),
            icon: widget.busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.lock),
            label: Text(widget.busy ? 'Sending STK push...' : 'Confirm & Pay'),
          ),
          TextButton(
            onPressed: widget.onBack,
            style: TextButton.styleFrom(foregroundColor: _ShwapyColors.danger),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

class _ProcessingScreen extends StatelessWidget {
  const _ProcessingScreen({
    required this.draft,
    required this.result,
    required this.onHome,
  });

  final _PaymentDraft draft;
  final _CheckoutResult? result;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final status = result?.status ?? 'processing';
    final failed = ['failed', 'cancelled', 'timeout'].contains(status);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: const BoxDecoration(
                  color: _ShwapyColors.greenLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.phone_android,
                  color: _ShwapyColors.green,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                failed
                    ? 'Payment ${status == 'cancelled' ? 'cancelled' : 'not completed'}'
                    : 'Waiting for M-Pesa\nconfirmation',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                failed
                    ? (result?.message ?? 'M-Pesa did not complete this payment.')
                    : 'Check your phone for a prompt and enter your M-Pesa PIN. Status updates automatically.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _ShwapyColors.text2,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              _MonoChip(draft.phoneNumber),
              const SizedBox(height: 8),
              _AmountChip(draft.amount),
              const SizedBox(height: 22),
              const _StepTile(done: true, label: 'Payment details confirmed'),
              _StepTile(done: true, label: result?.message ?? 'STK push sent'),
              _StepTile(
                done: failed,
                label: failed
                    ? 'M-Pesa status: $status'
                    : 'Waiting for M-Pesa callback...',
              ),
              const SizedBox(height: 22),
              TextButton(onPressed: onHome, child: const Text('Back home')),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuccessScreen extends StatelessWidget {
  const _SuccessScreen({
    required this.draft,
    required this.result,
    required this.onHome,
  });

  final _PaymentDraft draft;
  final _CheckoutResult? result;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 74,
                height: 74,
                decoration: const BoxDecoration(
                  color: _ShwapyColors.green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 38),
              ),
              const SizedBox(height: 16),
              const Text(
                'Payment successful',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Ksh ${_formatAmount(draft.amountNumber)}',
                style: const TextStyle(
                  color: _ShwapyColors.green,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                decoration: _cardDecoration(),
                child: Column(
                  children: [
                    _ReceiptRow('Merchant', draft.merchantName),
                    _ReceiptRow(
                      draft.type == 'paybill' ? 'Paybill' : 'Till',
                      draft.type == 'paybill' ? draft.paybillNo : draft.tillNo,
                    ),
                    if (draft.type == 'paybill')
                      _ReceiptRow('Account', draft.accountNo),
                    _ReceiptRow(
                      'Transaction',
                      result == null ? '-' : '#${result!.transactionId}',
                    ),
                    _ReceiptRow('Status', result?.status ?? 'completed'),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onHome,
                icon: const Icon(Icons.home),
                label: const Text('Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryScreen extends StatelessWidget {
  const _HistoryScreen({
    required this.recent,
    required this.onBack,
    required this.onRefresh,
    required this.onPayAgain,
  });

  final List<_RecentPayment> recent;
  final VoidCallback onBack;
  final Future<void> Function() onRefresh;
  final ValueChanged<_RecentPayment> onPayAgain;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(8, 8, 20, 16),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Back',
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back),
              ),
              const Text(
                'Transaction History',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: recent.isEmpty
              ? const _EmptyPaymentsState()
              : Column(
                  children: [
                    for (final item in recent) ...[
                      _TransactionTile(
                        payment: item,
                        onPayAgain: ['pending', 'processing']
                                .contains(item.status.toLowerCase())
                            ? null
                            : () => onPayAgain(item),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
        ),
        ],
      ),
    );
  }
}

class _ShwapyBottomNav extends StatelessWidget {
  const _ShwapyBottomNav({
    required this.tab,
    required this.onChanged,
    required this.onScan,
  });

  final _DashboardTab tab;
  final ValueChanged<_DashboardTab> onChanged;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      backgroundColor: Colors.white,
      indicatorColor: _ShwapyColors.greenLight,
      selectedIndex: tab == _DashboardTab.home ? 0 : 1,
      onDestinationSelected: (index) {
        if (index == 2) {
          onScan();
          return;
        }
        onChanged(index == 0 ? _DashboardTab.home : _DashboardTab.history);
      },
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
        NavigationDestination(icon: Icon(Icons.history), label: 'History'),
        NavigationDestination(
            icon: Icon(Icons.document_scanner), label: 'Scan'),
      ],
    );
  }
}

class _HeroAction extends StatelessWidget {
  const _HeroAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.session,
    required this.imagePath,
    required this.size,
    this.showBadge = false,
  });

  final AuthSession session;
  final String? imagePath;
  final double size;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    final initials = _initialsFor(session.user.name);
    final image = imagePath == null ? null : FileImage(File(imagePath!));

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: _ShwapyColors.greenLight,
            borderRadius: BorderRadius.circular(size * 0.35),
            border: Border.all(color: Colors.white, width: 2),
            image: image == null
                ? null
                : DecorationImage(image: image, fit: BoxFit.cover),
          ),
          alignment: Alignment.center,
          child: image == null
              ? Text(
                  initials,
                  style: TextStyle(
                    color: _ShwapyColors.greenDark,
                    fontSize: size * 0.34,
                    fontWeight: FontWeight.w900,
                  ),
                )
              : null,
        ),
        if (showBadge)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: _ShwapyColors.green,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 11),
            ),
          ),
      ],
    );
  }
}

class _ProfileSheet extends StatelessWidget {
  const _ProfileSheet({
    required this.session,
    required this.imagePath,
    required this.onLogout,
  });

  final AuthSession session;
  final String? imagePath;
  final VoidCallback onLogout;

  Future<void> _pickImage(BuildContext context) async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 900,
        imageQuality: 82,
      );
      if (context.mounted && image != null) {
        Navigator.of(context).pop(image.path);
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open gallery. Please try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = session.user;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: _ProfileAvatar(
                session: session,
                imagePath: imagePath,
                size: 82,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              user.name,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              user.email,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _ShwapyColors.text2),
            ),
            if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                user.phoneNumber!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _ShwapyColors.text,
                  fontFamily: 'DM Mono',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: () => _pickImage(context),
              icon: const Icon(Icons.add_a_photo),
              label: const Text('Set profile picture'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onLogout,
              style:
                  TextButton.styleFrom(foregroundColor: _ShwapyColors.danger),
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickPayCard extends StatelessWidget {
  const _QuickPayCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.background,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: _cardDecoration(),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _ShwapyColors.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _ShwapyColors.text3,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: _ShwapyColors.text3),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyPaymentsState extends StatelessWidget {
  const _EmptyPaymentsState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: _cardDecoration(),
        child: const Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              color: _ShwapyColors.green,
              size: 32,
            ),
            SizedBox(height: 8),
            Text(
              'No payments yet',
              style: TextStyle(
                color: _ShwapyColors.text,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 3),
            Text(
              'Scan, paste, or enter payment details manually.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _ShwapyColors.text2, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.payment, this.onPayAgain});

  final _RecentPayment payment;
  final VoidCallback? onPayAgain;

  @override
  Widget build(BuildContext context) {
    final success = payment.status.toLowerCase() == 'success';
    final pending = ['pending', 'processing']
        .contains(payment.status.toLowerCase());

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Row(
            children: [
              _InitialsAvatar(payment: payment),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      payment.merchant,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: _ShwapyColors.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${payment.accountType} · ${payment.account}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ShwapyColors.text3,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Ksh ${_formatAmount(payment.amount)}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: _ShwapyColors.text,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 3),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: success
                          ? _ShwapyColors.greenLight
                          : pending
                              ? const Color(0xFFFFF8E6)
                              : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _displayStatus(payment.status),
                      style: TextStyle(
                        color: success
                            ? _ShwapyColors.greenDark
                            : pending
                                ? const Color(0xFF92600A)
                                : const Color(0xFF991B1B),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (onPayAgain != null) ...[
            const Divider(height: 18),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onPayAgain,
                icon: const Icon(Icons.replay, size: 18),
                label: const Text('Pay again'),
                style: TextButton.styleFrom(
                  foregroundColor: _ShwapyColors.greenDark,
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.payment});

  final _RecentPayment payment;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: payment.background,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        payment.initials,
        style: TextStyle(
          color: payment.accent,
          fontWeight: FontWeight.w900,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: _ShwapyColors.text2,
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _ConfidenceCard extends StatelessWidget {
  const _ConfidenceCard({required this.confidence});

  final int confidence;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Extraction confidence',
                style: TextStyle(
                  color: _ShwapyColors.text2,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '$confidence%',
                style: const TextStyle(
                  color: _ShwapyColors.green,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: confidence.clamp(0, 100) / 100,
              minHeight: 6,
              color: _ShwapyColors.green,
              backgroundColor: _ShwapyColors.surface,
            ),
          ),
        ],
      ),
    );
  }
}

class _MerchantBadge extends StatelessWidget {
  const _MerchantBadge({required this.merchant, required this.type});

  final String merchant;
  final String type;

  @override
  Widget build(BuildContext context) {
    final title = merchant.trim().isEmpty ? 'Merchant' : merchant.trim();
    final payment = _RecentPayment.visualFor(title, type);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          _InitialsAvatar(payment: payment),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${type == 'paybill' ? 'Paybill' : 'Till'} payment',
                  style: const TextStyle(
                    color: _ShwapyColors.text3,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _ShwapyColors.greenLight,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'Review',
              style: TextStyle(
                color: _ShwapyColors.greenDark,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountCard extends StatelessWidget {
  const _AmountCard({required this.amount});

  final String amount;

  @override
  Widget build(BuildContext context) {
    final parsedAmount = double.tryParse(amount);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      alignment: Alignment.center,
      child: Column(
        children: [
          const Text(
            'AMOUNT TO PAY',
            style: TextStyle(
              color: _ShwapyColors.text2,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                  text: 'Ksh ',
                  style: TextStyle(
                    color: _ShwapyColors.text2,
                    fontSize: 16,
                  ),
                ),
                TextSpan(
                  text: parsedAmount == null || parsedAmount <= 0
                      ? '-'
                      : _formatAmount(parsedAmount),
                ),
              ],
            ),
            style: const TextStyle(
              color: _ShwapyColors.text,
              fontSize: 34,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _EditableField extends StatelessWidget {
  const _EditableField({
    required this.label,
    required this.controller,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final icon = switch (label) {
      'Merchant' => Icons.storefront_outlined,
      'Phone no.' => Icons.phone_outlined,
      'Amount' => Icons.payments_outlined,
      'Account no.' => Icons.tag,
      _ => Icons.account_balance_outlined,
    };

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(
          color: _ShwapyColors.text,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: _ShwapyColors.surface,
          prefixIcon: Icon(icon, size: 20, color: _ShwapyColors.greenDark),
          suffixIcon: const Icon(
            Icons.edit_outlined,
            size: 17,
            color: _ShwapyColors.text3,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _ShwapyColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
              color: _ShwapyColors.green,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineWarning extends StatelessWidget {
  const _InlineWarning({required this.message, this.danger = false});

  final String message;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: danger ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: danger ? const Color(0xFFFECACA) : const Color(0xFFFDE68A),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            danger ? Icons.error_outline : Icons.info_outline,
            color: danger ? _ShwapyColors.danger : _ShwapyColors.warning,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color:
                    danger ? const Color(0xFF991B1B) : const Color(0xFF92600A),
                height: 1.4,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonoChip extends StatelessWidget {
  const _MonoChip(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: _cardDecoration(),
      child: Text(
        value,
        style: const TextStyle(
          fontFamily: 'DM Mono',
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _AmountChip extends StatelessWidget {
  const _AmountChip(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
      decoration: BoxDecoration(
        color: _ShwapyColors.greenLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        'Ksh ${_formatAmount(double.tryParse(value) ?? 0)}',
        style: const TextStyle(
          color: _ShwapyColors.greenDark,
          fontWeight: FontWeight.w900,
          fontSize: 20,
        ),
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({required this.done, required this.label});

  final bool done;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: done ? _ShwapyColors.greenLight : _ShwapyColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle : Icons.hourglass_bottom,
            color: done ? _ShwapyColors.greenDark : _ShwapyColors.text2,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: done ? _ShwapyColors.greenDark : _ShwapyColors.text2,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _ShwapyColors.border),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: _ShwapyColors.text3, fontSize: 12),
          ),
          Flexible(
            child: Text(
              value.isEmpty ? '-' : value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontFamily: 'DM Mono',
                color: _ShwapyColors.text,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentDraft {
  const _PaymentDraft({
    required this.type,
    required this.paybillNo,
    required this.accountNo,
    required this.tillNo,
    required this.merchantName,
    required this.amount,
    required this.phoneNumber,
    required this.confidence,
    required this.rawExtraction,
    required this.missingFields,
  });

  final String type;
  final String paybillNo;
  final String accountNo;
  final String tillNo;
  final String merchantName;
  final String amount;
  final String phoneNumber;
  final double confidence;
  final Map<String, dynamic> rawExtraction;
  final List<String> missingFields;

  factory _PaymentDraft.fromDetails(
    PaymentDetails details,
    AuthSession session,
  ) {
    final account = details.account;
    return _PaymentDraft(
      type: account.type == 'till' ? 'till' : 'paybill',
      paybillNo: account.paybillNo ?? '',
      accountNo: account.accountNo ?? '',
      tillNo: account.tillNo ?? '',
      merchantName: account.merchantName ?? '',
      amount: details.amount?.toStringAsFixed(0) ?? '',
      phoneNumber: details.phoneNumber ?? session.user.phoneNumber ?? '',
      confidence: details.confidence,
      rawExtraction: details.toJson(),
      missingFields: details.missingFields,
    );
  }

  factory _PaymentDraft.manual(String type, AuthSession session) {
    return _PaymentDraft(
      type: type == 'till' ? 'till' : 'paybill',
      paybillNo: '',
      accountNo: '',
      tillNo: '',
      merchantName: '',
      amount: '',
      phoneNumber: session.user.phoneNumber ?? '',
      confidence: 0,
      rawExtraction: const {},
      missingFields: const [],
    );
  }

  factory _PaymentDraft.fromRecent(
    _RecentPayment payment,
    AuthSession session,
  ) {
    return _PaymentDraft(
      type: payment.type,
      paybillNo: payment.paybillNo,
      accountNo: payment.accountNo,
      tillNo: payment.tillNo,
      merchantName:
          payment.merchant == 'Payment details' ? '' : payment.merchant,
      amount: payment.amount.toStringAsFixed(0),
      phoneNumber: payment.phoneNumber.isNotEmpty
          ? payment.phoneNumber
          : session.user.phoneNumber ?? '',
      confidence: 0,
      rawExtraction: const {},
      missingFields: const [],
    );
  }

  _PaymentDraft copyWith({
    String? type,
    String? paybillNo,
    String? accountNo,
    String? tillNo,
    String? merchantName,
    String? amount,
    String? phoneNumber,
  }) {
    return _PaymentDraft(
      type: type ?? this.type,
      paybillNo: paybillNo ?? this.paybillNo,
      accountNo: accountNo ?? this.accountNo,
      tillNo: tillNo ?? this.tillNo,
      merchantName: merchantName ?? this.merchantName,
      amount: amount ?? this.amount,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      confidence: confidence,
      rawExtraction: rawExtraction,
      missingFields: missingFields,
    );
  }

  double get amountNumber => double.tryParse(amount) ?? 0;

  bool get isManual => rawExtraction.isEmpty;

  String? get validationError {
    if (type == 'paybill') {
      if (paybillNo.trim().isEmpty) {
        return 'Enter the paybill number before continuing.';
      }
      if (accountNo.trim().isEmpty) {
        return 'Enter the account number before continuing.';
      }
    } else if (tillNo.trim().isEmpty) {
      return 'Enter the till number before continuing.';
    }

    if (amountNumber <= 0) {
      return 'Enter a valid amount before continuing.';
    }
    if (phoneNumber.trim().isEmpty) {
      return 'Enter the phone number that should receive the STK prompt.';
    }

    return null;
  }

  Map<String, Object?> get paymentAccountPayload {
    return {
      'type': type,
      'merchant_name': merchantName.isEmpty ? null : merchantName,
      if (type == 'paybill') ...{
        'paybill_no': paybillNo,
        'account_no': accountNo,
      } else
        'till_no': tillNo,
    };
  }
}

class _CheckoutResult {
  const _CheckoutResult({
    required this.transactionId,
    required this.status,
    required this.message,
  });

  final Object? transactionId;
  final String status;
  final String message;

  factory _CheckoutResult.fromJson(Map<String, dynamic> json) {
    return _CheckoutResult(
      transactionId: json['transaction_id'],
      status: json['status']?.toString() ?? 'pending',
      message: json['message']?.toString() ?? 'STK push requested.',
    );
  }
}

class _RecentPayment {
  const _RecentPayment({
    required this.id,
    required this.merchant,
    required this.accountType,
    required this.account,
    required this.amount,
    required this.status,
    required this.initials,
    required this.accent,
    required this.background,
    this.type = 'till',
    this.paybillNo = '',
    this.accountNo = '',
    this.tillNo = '',
    this.phoneNumber = '',
    this.resultDescription,
  });

  final Object? id;
  final String merchant;
  final String accountType;
  final String account;
  final double amount;
  final String status;
  final String initials;
  final Color accent;
  final Color background;
  final String type;
  final String paybillNo;
  final String accountNo;
  final String tillNo;
  final String phoneNumber;
  final String? resultDescription;

  factory _RecentPayment.fromJson(Map<String, dynamic> json) {
    final account = Map<String, dynamic>.from(
      json['payment_account'] as Map? ?? const {},
    );
    final type = account['type']?.toString() == 'paybill' ? 'paybill' : 'till';
    final merchant = account['merchant_name']?.toString().trim() ?? '';
    final visual = _RecentPayment.visualFor(merchant, type);

    return _RecentPayment(
      id: json['id'],
      merchant: merchant.isEmpty ? 'Payment details' : merchant,
      accountType: type == 'paybill' ? 'Paybill' : 'Till',
      account: type == 'paybill'
          ? (account['account_no']?.toString() ?? '-')
          : (account['till_no']?.toString() ?? '-'),
      amount: (json['amount'] as num?)?.toDouble() ??
          double.tryParse(json['amount']?.toString() ?? '') ??
          0,
      status: json['status']?.toString() ?? 'pending',
      initials: visual.initials,
      accent: visual.accent,
      background: visual.background,
      type: type,
      paybillNo: account['paybill_no']?.toString() ?? '',
      accountNo: account['account_no']?.toString() ?? '',
      tillNo: account['till_no']?.toString() ?? '',
      phoneNumber: json['phone_number']?.toString() ?? '',
      resultDescription: json['result_description']?.toString(),
    );
  }

  factory _RecentPayment.visualFor(String merchant, String type) {
    final words = merchant
        .split(RegExp(r'\s+'))
        .where((word) => word.trim().isNotEmpty)
        .toList();
    final initials = words.isEmpty
        ? (type == 'paybill' ? 'PB' : 'TL')
        : words.take(2).map((word) => word[0].toUpperCase()).join();

    return _RecentPayment(
      id: null,
      merchant: merchant,
      accountType: type,
      account: '',
      amount: 0,
      status: '',
      initials: initials,
      accent:
          type == 'paybill' ? const Color(0xFFE65100) : const Color(0xFF185FA5),
      background:
          type == 'paybill' ? const Color(0xFFFFF3E0) : const Color(0xFFEBF5FF),
    );
  }
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(10),
    border: Border.all(color: _ShwapyColors.border),
  );
}

String _formatAmount(double value) {
  final raw = value.round().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < raw.length; index += 1) {
    final remaining = raw.length - index;
    buffer.write(raw[index]);
    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write(',');
    }
  }
  return buffer.toString();
}

String _greetingFor(DateTime localTime) {
  if (localTime.hour < 12) return 'Good morning';
  if (localTime.hour < 17) return 'Good afternoon';
  return 'Good evening';
}

String _displayStatus(String status) {
  return switch (status.toLowerCase()) {
    'success' => 'Paid',
    'processing' => 'Processing',
    'cancelled' => 'Cancelled',
    'timeout' => 'Timed out',
    'failed' => 'Failed',
    _ => 'Pending',
  };
}

String _initialsFor(String value) {
  final words = value
      .split(RegExp(r'\s+'))
      .where((word) => word.trim().isNotEmpty)
      .toList();
  if (words.isEmpty) {
    return 'U';
  }

  return words.take(2).map((word) => word[0].toUpperCase()).join();
}
