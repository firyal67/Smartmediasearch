// dart:io supprimé → non compatible Web/Chrome
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

// ══════════════════════════════════════════
//  CONFIGURATION — changez l'URL ici
//  Émulateur Android : 'http://10.0.2.2:5000'
//  Vrai téléphone    : 'http://192.168.X.X:5000'
//  Chrome / Web      : 'http://localhost:5000'
// ══════════════════════════════════════════
const String baseUrl = 'http://192.168.100.208:5000';

// ══════════════════════════════════════════
//  DESIGN TOKENS
// ══════════════════════════════════════════
class AppColors {
  static const primary    = Color(0xFF6C63FF);
  static const secondary  = Color(0xFF3ECFCF);
  static const accent     = Color(0xFFFF6584);
  static const dark       = Color(0xFF1A1A2E);
  static const darkCard   = Color(0xFF16213E);
  static const surface    = Color(0xFF0F3460);
  static const textLight  = Color(0xFFE0E0E0);
  static const textMuted  = Color(0xFF9E9E9E);
  static const success    = Color(0xFF4CAF50);
  static const warning    = Color(0xFFFF9800);
  static const gradStart  = Color(0xFF6C63FF);
  static const gradEnd    = Color(0xFF3ECFCF);
}

class AppTextStyles {
  static const headline = TextStyle(
    fontFamily: 'Roboto',
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: Colors.white,
    letterSpacing: -0.5,
  );
  static const title = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: Colors.white,
    letterSpacing: 0.2,
  );
  static const body = TextStyle(
    fontSize: 14,
    color: AppColors.textLight,
  );
  static const caption = TextStyle(
    fontSize: 12,
    color: AppColors.textMuted,
  );
}

// ══════════════════════════════════════════
//  MAIN
// ══════════════════════════════════════════
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(SmartMediaApp());
}

class SmartMediaApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartMedia Search',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.dark,
        primaryColor: AppColors.primary,
        colorScheme: ColorScheme.dark(
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          surface: AppColors.darkCard,
        ),
        fontFamily: 'Roboto',
        cardTheme: CardThemeData(
          color: AppColors.darkCard,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.darkCard,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white10),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppColors.primary, width: 2),
          ),
          hintStyle: TextStyle(color: AppColors.textMuted),
          prefixIconColor: AppColors.primary,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppColors.darkCard,
          contentTextStyle: TextStyle(color: Colors.white),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      home: AuthCheck(),
    );
  }
}

// ══════════════════════════════════════════
//  AUTH CHECK
// ══════════════════════════════════════════
class AuthCheck extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Scaffold(
            backgroundColor: AppColors.dark,
            body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          );
        }
        if (snapshot.data!.getString('token') != null) return Dashboard();
        return LoginPage();
      },
    );
  }
}

// ══════════════════════════════════════════
//  LOGIN PAGE
// ══════════════════════════════════════════
class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final _emailCtrl    = TextEditingController(text: 'demo@smartmedia.com');
  final _passCtrl     = TextEditingController(text: 'demo123');
  bool _loading       = false;
  bool _obscure       = true;
  bool _rememberMe    = false;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: Duration(milliseconds: 900));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      _showSnack('Veuillez remplir tous les champs', isError: true);
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': _emailCtrl.text.trim(), 'password': _passCtrl.text}),
      ).timeout(Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['token']);
        await prefs.setString('user', jsonEncode(data['user']));
        final role = data['user']['role'] ?? 'user';
        if (role == 'admin') {
          Navigator.pushReplacement(context, _slideRoute(AdminDashboard()));
        } else {
          Navigator.pushReplacement(context, _slideRoute(Dashboard()));
        }
      } else {
        _showSnack('Email ou mot de passe incorrect', isError: true);
      }
    } catch (e) {
      _showSnack('Erreur de connexion. Vérifiez l\'URL du serveur.', isError: true);
    }
    setState(() => _loading = false);
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(isError ? Icons.error_outline : Icons.check_circle, color: isError ? AppColors.accent : AppColors.success, size: 20),
        SizedBox(width: 10),
        Expanded(child: Text(msg)),
      ]),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.dark, AppColors.surface, AppColors.darkCard],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 28, vertical: 40),
                child: Column(children: [
                  // LOGO
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [AppColors.primary, AppColors.secondary]),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 20, offset: Offset(0, 8))],
                    ),
                    child: Icon(Icons.auto_awesome, color: Colors.white, size: 40),
                  ),
                  SizedBox(height: 24),
                  Text('SmartMedia', style: AppTextStyles.headline),
                  Text('Search', style: AppTextStyles.headline.copyWith(
                    foreground: Paint()..shader = LinearGradient(
                      colors: [AppColors.primary, AppColors.secondary],
                    ).createShader(Rect.fromLTWH(0, 0, 200, 70)),
                    fontSize: 32,
                  )),
                  SizedBox(height: 8),
                  Text('Votre médiathèque intelligente', style: AppTextStyles.caption.copyWith(fontSize: 14)),
                  SizedBox(height: 40),

                  // FORM CARD
                  Container(
                    padding: EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: AppColors.darkCard.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(children: [
                      TextField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Email',
                          labelStyle: TextStyle(color: AppColors.textMuted),
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                      SizedBox(height: 16),
                      TextField(
                        controller: _passCtrl,
                        obscureText: _obscure,
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Mot de passe',
                          labelStyle: TextStyle(color: AppColors.textMuted),
                          prefixIcon: Icon(Icons.lock_outlined),
                          suffixIcon: IconButton(
                            icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppColors.textMuted),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        onSubmitted: (_) => _login(),
                      ),
                      SizedBox(height: 8),
                      Row(children: [
                        Transform.scale(
                          scale: 0.9,
                          child: Switch(
                            value: _rememberMe,
                            onChanged: (v) => setState(() => _rememberMe = v),
                            activeColor: AppColors.primary,
                          ),
                        ),
                        Text('Se souvenir de moi', style: AppTextStyles.caption),
                        Spacer(),
                        TextButton(
                          onPressed: () {},
                          child: Text('Oublié ?', style: TextStyle(color: AppColors.secondary, fontSize: 13)),
                        ),
                      ]),
                      SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: _loading
                            ? Center(child: CircularProgressIndicator(color: AppColors.primary))
                            : ElevatedButton(
                                onPressed: _login,
                                child: Text('Se connecter'),
                              ),
                      ),
                    ]),
                  ),

                  SizedBox(height: 24),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('Pas encore de compte ? ', style: AppTextStyles.caption),
                    GestureDetector(
                      onTap: () => Navigator.push(context, _slideRoute(RegisterPage())),
                      child: Text('Créer un compte', style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                  ]),
                  SizedBox(height: 16),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.lock_outlined, size: 14, color: AppColors.textMuted),
                    SizedBox(width: 6),
                    Text('Données chiffrées • IA locale', style: AppTextStyles.caption),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════
//  REGISTER PAGE
// ══════════════════════════════════════════
class RegisterPage extends StatefulWidget {
  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  final _nameCtrl  = TextEditingController();
  bool _loading    = false;
  bool _obscure    = true;

  Future<void> _register() async {
    if (_emailCtrl.text.isEmpty || _passCtrl.text.isEmpty) {
      _showSnack('Veuillez remplir tous les champs', isError: true);
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': _nameCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'password': _passCtrl.text,
        }),
      ).timeout(Duration(seconds: 15));

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['token']);
        await prefs.setString('user', jsonEncode(data['user']));
        Navigator.pushReplacement(context, _slideRoute(Dashboard()));
      } else {
        _showSnack('Inscription échouée: ${res.body}', isError: true);
      }
    } catch (e) {
      _showSnack('Erreur réseau: $e', isError: true);
    }
    setState(() => _loading = false);
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.dark, AppColors.surface, AppColors.darkCard],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 28, vertical: 40),
            child: Column(children: [
              Row(children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ]),
              SizedBox(height: 20),
              Container(
                width: 70, height: 70,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.secondary, AppColors.primary]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(Icons.person_add_outlined, color: Colors.white, size: 34),
              ),
              SizedBox(height: 20),
              Text('Créer un compte', style: AppTextStyles.headline.copyWith(fontSize: 26)),
              SizedBox(height: 8),
              Text('Rejoignez SmartMedia Search', style: AppTextStyles.caption.copyWith(fontSize: 14)),
              SizedBox(height: 36),
              Container(
                padding: EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: AppColors.darkCard.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(children: [
                  TextField(
                    controller: _nameCtrl,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Nom complet',
                      labelStyle: TextStyle(color: AppColors.textMuted),
                      prefixIcon: Icon(Icons.person_outlined),
                    ),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Email',
                      labelStyle: TextStyle(color: AppColors.textMuted),
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _passCtrl,
                    obscureText: _obscure,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Mot de passe',
                      labelStyle: TextStyle(color: AppColors.textMuted),
                      prefixIcon: Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppColors.textMuted),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: _loading
                        ? Center(child: CircularProgressIndicator(color: AppColors.primary))
                        : ElevatedButton(
                            onPressed: _register,
                            child: Text('Créer mon compte'),
                          ),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════
//  DASHBOARD (PAGE PRINCIPALE)
// ══════════════════════════════════════════
class Dashboard extends StatefulWidget {
  @override
  _DashboardState createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> with TickerProviderStateMixin {
  Map<String, dynamic> _stats = {};
  List _allMedias   = [];
  bool _loading     = true;
  bool _uploading   = false;
  String _search    = '';
  String _filter    = 'Tous';
  int _currentTab   = 0;

  // Recherche sémantique FAISS
  List _searchResults    = [];
  bool _searchLoading    = false;
  bool _semanticMode     = false; // false = local, true = FAISS

  late TabController _tabCtrl;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() => setState(() => _currentTab = _tabCtrl.index));
    _fetchAll();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchAll() async {
    setState(() => _loading = true);
    await Future.wait([_fetchDashboard(), _fetchMedias()]);
    setState(() => _loading = false);
  }

  Future<void> _fetchDashboard() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final res = await http.get(
        Uri.parse('$baseUrl/api/media/dashboard'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(Duration(seconds: 10));
      if (res.statusCode == 200) {
        setState(() => _stats = jsonDecode(res.body));
      }
    } catch (_) {}
  }

  Future<void> _fetchMedias() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final res = await http.get(
        Uri.parse('$baseUrl/api/media'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(Duration(seconds: 10));
      if (res.statusCode == 200) {
        setState(() => _allMedias = jsonDecode(res.body));
      }
    } catch (_) {}
  }

  // ─── RECHERCHE SÉMANTIQUE FAISS ─────────
  Future<void> _semanticSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() { _searchResults = []; _searchLoading = false; });
      return;
    }
    setState(() => _searchLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final uri = Uri.parse('$baseUrl/api/media/search').replace(queryParameters: {'q': query});
      final res = await http.get(uri, headers: {'Authorization': 'Bearer $token'})
          .timeout(Duration(seconds: 20));
      if (res.statusCode == 200) {
        setState(() => _searchResults = jsonDecode(res.body));
      }
    } catch (e) {
      _showSnack('Erreur recherche: $e', isError: true);
    }
    setState(() => _searchLoading = false);
  }

  // ─── UPLOAD ─────────────────────────────
  // Utilise fromBytes() → compatible Web (Chrome) + Mobile + Desktop
  Future<void> _uploadFileBytes(Uint8List bytes, String fileName, String mimeType) async {
    setState(() => _uploading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      var req = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/media/upload'));
      req.headers['Authorization'] = 'Bearer $token';
      req.files.add(http.MultipartFile.fromBytes(
        'media',
        bytes,
        filename: fileName,
        contentType: MediaType.parse(mimeType),
      ));
      final streamed = await req.send().timeout(Duration(seconds: 60));
      final res = await http.Response.fromStream(streamed);
      if (res.statusCode == 200 || res.statusCode == 201) {
        _showSnack('Fichier uploadé avec succès ✓', isError: false);
        await _fetchAll();
      } else {
        _showSnack('Erreur upload: ${res.statusCode}', isError: true);
      }
    } catch (e) {
      _showSnack('Erreur: $e', isError: true);
    }
    setState(() => _uploading = false);
  }

  void _showUploadDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _UploadSheet(
        onPickImage: () async {
          Navigator.pop(context);
          try {
            final picker = ImagePicker();
            final xFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
            if (xFile != null) {
              final bytes = await xFile.readAsBytes();
              await _uploadFileBytes(bytes, xFile.name, xFile.mimeType ?? 'image/jpeg');
            }
          } catch (e) {
            _showSnack('Impossible d\'accéder à la galerie: $e', isError: true);
          }
        },
        onPickCamera: () async {
          Navigator.pop(context);
          try {
            final picker = ImagePicker();
            final xFile = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
            if (xFile != null) {
              final bytes = await xFile.readAsBytes();
              await _uploadFileBytes(bytes, xFile.name, xFile.mimeType ?? 'image/jpeg');
            }
          } catch (e) {
            _showSnack('Impossible d\'accéder à la caméra: $e', isError: true);
          }
        },
        onPickVideo: () async {
          Navigator.pop(context);
          try {
            final picker = ImagePicker();
            final xFile = await picker.pickVideo(source: ImageSource.gallery);
            if (xFile != null) {
              final bytes = await xFile.readAsBytes();
              await _uploadFileBytes(bytes, xFile.name, 'video/mp4');
            }
          } catch (e) {
            _showSnack('Impossible d\'accéder aux vidéos: $e', isError: true);
          }
        },
        onPickDoc: () async {
          Navigator.pop(context);
          try {
            final result = await FilePicker.platform.pickFiles(
              type: FileType.custom,
              allowedExtensions: ['pdf', 'docx', 'txt', 'doc', 'xlsx', 'pptx'],
              withData: true, // nécessaire sur Web pour avoir les bytes
            );
            if (result != null) {
              final f = result.files.single;
              final bytes = f.bytes ?? Uint8List(0);
              if (bytes.isNotEmpty) {
                await _uploadFileBytes(bytes, f.name, _docMime(f.extension ?? 'pdf'));
              }
            }
          } catch (e) {
            _showSnack('Impossible de choisir un document: $e', isError: true);
          }
        },
        onPickAudio: () async {
          Navigator.pop(context);
          try {
            final result = await FilePicker.platform.pickFiles(
              type: FileType.audio,
              withData: true, // nécessaire sur Web pour avoir les bytes
            );
            if (result != null) {
              final f = result.files.single;
              final bytes = f.bytes ?? Uint8List(0);
              if (bytes.isNotEmpty) {
                await _uploadFileBytes(bytes, f.name, 'audio/mpeg');
              }
            }
          } catch (e) {
            _showSnack('Impossible d\'accéder aux audios: $e', isError: true);
          }
        },
      ),
    );
  }

  String _docMime(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':  return 'application/pdf';
      case 'docx': return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xlsx': return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      default:     return 'text/plain';
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(isError ? Icons.error_outline : Icons.check_circle_outline,
            color: isError ? AppColors.accent : AppColors.success, size: 20),
        SizedBox(width: 8),
        Expanded(child: Text(msg, style: TextStyle(color: Colors.white))),
      ]),
      duration: Duration(seconds: 3),
    ));
  }

  List _filteredMedias() {
    List list = List.from(_allMedias);
    if (_filter == 'Images')    list = list.where((m) => m['type'] == 'image').toList();
    if (_filter == 'Vidéos')    list = list.where((m) => m['type'] == 'video').toList();
    if (_filter == 'Audio')     list = list.where((m) => m['type'] == 'audio').toList();
    if (_filter == 'Docs')      list = list.where((m) => m['type'] == 'document').toList();
    if (_filter == 'Favoris')   list = list.where((m) => m['favorite'] == true).toList();
    if (_filter == 'Analysés')  list = list.where((m) => m['analyzed'] == true).toList();
    if (_filter == 'Récents')   list = list.take(6).toList();
    if (_search.isNotEmpty) {
      list = list.where((m) {
        final name = (m['originalName'] ?? '').toLowerCase();
        final tags = (m['tags'] ?? []).join(' ').toLowerCase();
        final desc = (m['description'] ?? '').toLowerCase();
        final objs = (m['aiObjects'] ?? []).join(' ').toLowerCase();
        final q    = _search.toLowerCase();
        return name.contains(q) || tags.contains(q) || desc.contains(q) || objs.contains(q);
      }).toList();
    }
    return list;
  }

  Future<void> _toggleFavorite(Map m) async {
    final mediaId = (m['_id'] ?? m['id'] ?? '').toString();
    if (mediaId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final res = await http.patch(
        Uri.parse('$baseUrl/api/media/$mediaId/favorite'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(Duration(seconds: 10));
      if (res.statusCode == 200) {
        final updated = jsonDecode(res.body);
        setState(() {
          final idx = _allMedias.indexWhere((e) => (e['_id'] ?? e['id']).toString() == mediaId);
          if (idx != -1) _allMedias[idx] = updated;
        });
        _showSnack(updated['favorite'] == true ? '⭐ Ajouté aux favoris' : 'Retiré des favoris');
      }
    } catch (e) {
      _showSnack('Erreur: $e', isError: true);
    }
  }

  Future<void> _deleteMedia(String id) async {
    if (id.isEmpty) {
      _showSnack('Identifiant introuvable', isError: true);
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final res = await http.delete(
        Uri.parse('$baseUrl/api/media/$id'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(Duration(seconds: 15));
      if (!mounted) return;
      if (res.statusCode == 200 || res.statusCode == 204) {
        setState(() => _allMedias.removeWhere((m) =>
            (m['_id'] ?? m['id'] ?? '') == id));
        _showSnack('Média supprimé avec succès ✓');
        _fetchAll();
      } else {
        _showSnack('Erreur ${res.statusCode}: ${res.body}', isError: true);
      }
    } catch (e) {
      if (mounted) _showSnack('Erreur réseau: $e', isError: true);
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.pushReplacement(context, _fadeRoute(LoginPage()));
  }

  // ─── BUILD ──────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dark,
      body: _loading
          ? _buildLoader()
          : IndexedStack(
              index: _currentTab,
              children: [
                _buildHomeTab(),
                _buildSearchTab(),
                _buildChatbotTab(),
              ],
            ),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: _currentTab == 0
          ? _buildFAB()
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildLoader() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3),
        SizedBox(height: 16),
        Text('Chargement...', style: AppTextStyles.caption),
      ]),
    );
  }

  // ─── HOME TAB ───────────────────────────
  Widget _buildHomeTab() {
    final medias = _filteredMedias();
    return CustomScrollView(
      slivers: [
        _buildAppBar(),
        SliverToBoxAdapter(child: _buildStatsRow()),
        SliverToBoxAdapter(child: _buildFilterChips()),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Row(children: [
              Text(
                medias.isEmpty ? 'Aucun média' : '${medias.length} média${medias.length > 1 ? 's' : ''}',
                style: AppTextStyles.title.copyWith(fontSize: 16),
              ),
              Spacer(),
              if (_uploading)
                SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
                ),
            ]),
          ),
        ),
        medias.isEmpty
            ? SliverFillRemaining(child: _buildEmptyState())
            : SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 100),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _buildMediaCard(medias[i]),
                    childCount: medias.length,
                  ),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.85,
                  ),
                ),
              ),
      ],
    );
  }

  SliverAppBar _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 140,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.dark,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.surface, AppColors.dark],
            ),
          ),
          padding: EdgeInsets.fromLTRB(20, 60, 20, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
                  Text('SmartMedia', style: AppTextStyles.headline.copyWith(fontSize: 26)),
                  Text('Search', style: AppTextStyles.headline.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: AppColors.secondary,
                  )),
                ]),
              ),
              Row(children: [
                IconButton(
                  icon: Icon(Icons.notifications_outlined, color: Colors.white),
                  onPressed: () {},
                ),
                GestureDetector(
                  onTap: () => _showProfileSheet(),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primary,
                    child: Icon(Icons.person, color: Colors.white, size: 20),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
      actions: [],
    );
  }

  Widget _buildStatsRow() {
    final total    = _stats['totalMedias'] ?? _allMedias.length;
    final analyzed = _stats['analyzedMedias'] ?? 0;
    final storage  = _stats['totalStorage'] ?? '0.00 GB';
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(children: [
        Expanded(child: _statCard(Icons.photo_library_outlined, '$total', 'Total médias', AppColors.primary)),
        SizedBox(width: 12),
        Expanded(child: _statCard(Icons.auto_awesome_outlined, '$analyzed', 'IA analysés', AppColors.secondary)),
        SizedBox(width: 12),
        Expanded(child: _statCard(Icons.storage_outlined, '$storage', 'Stockage', AppColors.accent)),
      ]),
    );
  }

  Widget _statCard(IconData icon, String value, String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        SizedBox(height: 10),
        Text(value, style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
        Text(label, style: AppTextStyles.caption.copyWith(fontSize: 11)),
      ]),
    );
  }

  Widget _buildFilterChips() {
    final filters = ['Tous', 'Images', 'Vidéos', 'Audio', 'Docs', 'Favoris', 'Analysés', 'Récents'];
    return Container(
      height: 52,
      margin: EdgeInsets.only(top: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        itemBuilder: (_, i) {
          final f = filters[i];
          final selected = _filter == f;
          return GestureDetector(
            onTap: () => setState(() => _filter = f),
            child: AnimatedContainer(
              duration: Duration(milliseconds: 250),
              margin: EdgeInsets.only(right: 10),
              padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                gradient: selected
                    ? LinearGradient(colors: [AppColors.primary, AppColors.secondary])
                    : null,
                color: selected ? null : AppColors.darkCard,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: selected ? Colors.transparent : Colors.white12),
              ),
              child: Text(
                f,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.textMuted,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Construit l'URL de prévisualisation d'un média
  String? _previewUrl(Map m) {
    final filename = m['filename'];
    if (filename == null || filename.toString().isEmpty) return null;
    return '$baseUrl/uploads/$filename';
  }

  Widget _buildMediaCard(Map m) {
    final type        = m['type'] ?? 'document';
    final name        = m['originalName'] ?? 'Sans nom';
    final objects     = (m['aiObjects'] as List? ?? []);
    final tags        = (m['tags'] as List? ?? []);
    final analyzed    = m['analyzed'] == true;
    final displayTags = objects.isNotEmpty ? objects : tags;
    final previewUrl  = _previewUrl(m);
    final isImage     = type == 'image';
    final mediaId     = (m['_id'] ?? m['id'] ?? '').toString();

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(fit: StackFit.expand, children: [

        // ── Image / icône plein cadre ──────────
        isImage && previewUrl != null
            ? Image.network(
                previewUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fullIconPreview(type),
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : Container(
                        color: AppColors.surface,
                        child: Center(child: CircularProgressIndicator(
                          color: AppColors.primary, strokeWidth: 2,
                          value: progress.expectedTotalBytes != null
                              ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                              : null,
                        )),
                      ),
              )
            : _fullIconPreview(type),

        // ── Dégradé bas ───────────────────────
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(10, 24, 10, 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black.withOpacity(0.85), Colors.transparent],
              ),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
              SizedBox(height: 4),
              if ((m['description'] ?? '').toString().isNotEmpty)
                Text(m['description'], maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.secondary, fontSize: 10)),
              Row(children: [
                Icon(Icons.circle, size: 7, color: analyzed ? AppColors.success : AppColors.warning),
                SizedBox(width: 4),
                Text(analyzed ? 'Analysé' : 'En attente',
                    style: TextStyle(color: Colors.white70, fontSize: 10)),
                if (displayTags.isNotEmpty) ...[
                  SizedBox(width: 6),
                  Expanded(child: Text(
                    displayTags.take(1).map((t) => '#$t').join(' '),
                    style: TextStyle(color: AppColors.secondary, fontSize: 10),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  )),
                ],
              ]),
            ]),
          ),
        ),

        // ── Badge type (non-image) ────────────
        if (!isImage)
          Positioned(
            top: 8, left: 8,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_typeIcon(type), color: Colors.white, size: 12),
                SizedBox(width: 4),
                Text(type, style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),

        // ── Boutons supprimer / description / favori ───
        Positioned(
          top: 6, right: 6,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _confirmDelete(context, m, mediaId),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.accent.withOpacity(0.7)),
                  ),
                  child: Icon(Icons.delete_outline, color: AppColors.accent, size: 16),
                ),
              ),
            ),
            SizedBox(height: 4),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showDescriptionDialog(m),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.secondary.withOpacity(0.7)),
                  ),
                  child: Icon(Icons.edit_note, color: AppColors.secondary, size: 16),
                ),
              ),
            ),
            SizedBox(height: 4),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _toggleFavorite(m),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.withOpacity(0.7)),
                  ),
                  child: Icon(
                    m['favorite'] == true ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 16,
                  ),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _actionBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }

  void _showMediaOptions(Map m) {
    final mediaId = (m['_id'] ?? m['id'] ?? '').toString();
    final ctx = context;
    showModalBottomSheet(
      context: ctx,
      backgroundColor: AppColors.darkCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            SizedBox(height: 16),
            Text(m['originalName'] ?? '', style: AppTextStyles.title.copyWith(fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
            SizedBox(height: 20),
            _optionTile(Icons.info_outline, 'Détails', () {
              Navigator.pop(sheetCtx);
              _showMediaDetails(m);
            }),
            _optionTile(Icons.edit_note, 'Ajouter / modifier une description', () {
              Navigator.pop(sheetCtx);
              _showDescriptionDialog(m);
            }, color: AppColors.secondary),
            _optionTile(Icons.delete_outline, 'Supprimer', () {
              Navigator.pop(sheetCtx);
              _confirmDelete(ctx, m, mediaId);
            }, color: AppColors.accent),
          ]),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext ctx, Map m, String mediaId) {
    showDialog(
      context: ctx,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: AppColors.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Supprimer le média ?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Voulez-vous vraiment supprimer "${m['originalName'] ?? 'ce fichier'}" ? Cette action est irréversible.',
          style: TextStyle(color: AppColors.textLight),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: Text('Annuler', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () {
              Navigator.pop(dlgCtx);
              _deleteMedia(mediaId);
            },
            child: Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  void _showDescriptionDialog(Map m) {
    final mediaId = (m['_id'] ?? m['id'] ?? '').toString();
    final ctrl = TextEditingController(text: m['description'] ?? '');
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: AppColors.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(Icons.edit_note, color: AppColors.secondary, size: 22),
          SizedBox(width: 8),
          Text('Description', style: TextStyle(color: Colors.white)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            'Décrivez le contenu pour améliorer la recherche IA.\nEx: "chien noir qui court dans un parc"',
            style: AppTextStyles.caption.copyWith(fontSize: 12),
          ),
          SizedBox(height: 14),
          TextField(
            controller: ctrl,
            maxLines: 3,
            autofocus: true,
            style: TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Décrivez ce média…',
              hintStyle: TextStyle(color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.secondary.withOpacity(0.4)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.secondary, width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white12),
              ),
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: Text('Annuler', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
            onPressed: () async {
              Navigator.pop(dlgCtx);
              await _saveDescription(mediaId, ctrl.text.trim());
            },
            child: Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveDescription(String mediaId, String description) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final res = await http.patch(
        Uri.parse('$baseUrl/api/media/$mediaId/description'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode({'description': description}),
      ).timeout(Duration(seconds: 10));
      if (res.statusCode == 200) {
        _showSnack('Description enregistrée ✓', isError: false);
        await _fetchMedias();
      } else {
        _showSnack('Erreur: ${res.statusCode}', isError: true);
      }
    } catch (e) {
      _showSnack('Erreur réseau: $e', isError: true);
    }
  }

  Widget _optionTile(IconData icon, String label, VoidCallback onTap, {Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppColors.textLight),
      title: Text(label, style: TextStyle(color: color ?? Colors.white)),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  void _showMediaDetails(Map m) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Détails du média', style: TextStyle(color: Colors.white)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          _detailRow('Nom', m['originalName'] ?? '-'),
          _detailRow('Type', m['type'] ?? '-'),
          _detailRow('Taille', _formatSize(m['size'] ?? 0)),
          _detailRow('Analysé', m['analyzed'] == true ? 'Oui ✓' : 'Non'),
          _detailRow('Objets IA', (m['aiObjects'] as List? ?? []).join(', ')),
          if ((m['aiConfidence'] ?? 0.0) > 0)
            _detailRow('Confiance IA', '${((m['aiConfidence'] as num).toDouble() * 100).toStringAsFixed(1)}%'),
          if ((m['description'] ?? '').toString().isNotEmpty)
            _detailRow('Description', m['description']),
          _detailRow('Tags', (m['tags'] as List? ?? []).join(', ')),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Fermer', style: TextStyle(color: AppColors.primary)),
          ),
          TextButton(
            onPressed: () { Navigator.pop(context); _showDescriptionDialog(m); },
            child: Text('Modifier description', style: TextStyle(color: AppColors.secondary)),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String k, String v) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$k: ', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        Expanded(child: Text(v, style: TextStyle(color: Colors.white, fontSize: 13))),
      ]),
    );
  }

  String _formatSize(dynamic bytes) {
    if (bytes == null) return '-';
    final b = (bytes is int) ? bytes : int.tryParse('$bytes') ?? 0;
    if (b < 1024) return '$b B';
    if (b < 1048576) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '${(b / 1048576).toStringAsFixed(2)} MB';
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.cloud_upload_outlined, size: 56, color: AppColors.primary),
        ),
        SizedBox(height: 20),
        Text('Aucun média', style: AppTextStyles.title),
        SizedBox(height: 8),
        Text('Appuyez sur + pour ajouter votre premier fichier', style: AppTextStyles.caption, textAlign: TextAlign.center),
      ]),
    );
  }

  // ─── SEARCH TAB ─────────────────────────
  Widget _buildSearchTab() {
    final localMedias = _filteredMedias();
    final displayList = (_semanticMode && _search.isNotEmpty) ? _searchResults : localMedias;

    return SafeArea(
      child: Column(children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Recherche IA', style: AppTextStyles.headline.copyWith(fontSize: 24)),
            SizedBox(height: 4),
            Text('Recherche sémantique par CLIP + FAISS', style: AppTextStyles.caption),
            SizedBox(height: 16),
            // Toggle mode
            Row(children: [
              GestureDetector(
                onTap: () => setState(() => _semanticMode = true),
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: _semanticMode ? LinearGradient(colors: [AppColors.primary, AppColors.secondary]) : null,
                    color: _semanticMode ? null : AppColors.darkCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _semanticMode ? Colors.transparent : Colors.white12),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.auto_awesome, size: 14, color: _semanticMode ? Colors.white : AppColors.textMuted),
                    SizedBox(width: 6),
                    Text('IA Sémantique', style: TextStyle(
                      color: _semanticMode ? Colors.white : AppColors.textMuted,
                      fontSize: 12, fontWeight: FontWeight.w600,
                    )),
                  ]),
                ),
              ),
              SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() => _semanticMode = false),
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: !_semanticMode ? AppColors.darkCard.withOpacity(0.9) : AppColors.darkCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: !_semanticMode ? AppColors.secondary.withOpacity(0.6) : Colors.white12),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.filter_list, size: 14, color: !_semanticMode ? AppColors.secondary : AppColors.textMuted),
                    SizedBox(width: 6),
                    Text('Filtre local', style: TextStyle(
                      color: !_semanticMode ? AppColors.secondary : AppColors.textMuted,
                      fontSize: 12, fontWeight: FontWeight.w600,
                    )),
                  ]),
                ),
              ),
            ]),
            SizedBox(height: 12),
            TextField(
              controller: _searchCtrl,
              autofocus: false,
              onChanged: (v) {
                setState(() => _search = v);
                if (_semanticMode) _semanticSearch(v);
              },
              onSubmitted: (v) { if (_semanticMode) _semanticSearch(v); },
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: _semanticMode ? 'Ex: chien qui court, match de football…' : 'Nom, tag, type…',
                prefixIcon: Icon(Icons.search),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: AppColors.textMuted),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() { _search = ''; _searchResults = []; });
                        },
                      )
                    : null,
              ),
            ),
          ]),
        ),
        if (!_semanticMode) ...[
          _buildFilterChips(),
          SizedBox(height: 8),
        ] else
          SizedBox(height: 12),
        // Résultats
        Expanded(
          child: _searchLoading
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 12),
                  Text('Recherche sémantique en cours…', style: AppTextStyles.caption),
                ]))
              : displayList.isEmpty
                  ? _buildSearchEmptyState()
                  : ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      itemCount: displayList.length,
                      itemBuilder: (_, i) => _buildSearchResultTile(displayList[i]),
                    ),
        ),
      ]),
    );
  }

  Widget _buildSearchEmptyState() {
    if (_search.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.image_search, size: 56, color: AppColors.primary.withOpacity(0.5)),
        SizedBox(height: 16),
        Text('Recherche intelligente', style: AppTextStyles.title),
        SizedBox(height: 8),
        Text(
          _semanticMode
              ? 'Décrivez ce que vous cherchez\nEx: "chien noir", "coucher de soleil"'
              : 'Tapez un nom ou un tag',
          style: AppTextStyles.caption, textAlign: TextAlign.center,
        ),
      ]));
    }
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.search_off, size: 48, color: AppColors.textMuted),
      SizedBox(height: 12),
      Text('Aucun résultat pour "$_search"', style: AppTextStyles.caption),
    ]));
  }

  Widget _buildSearchResultTile(Map m) {
    final type       = m['type'] ?? 'document';
    final name       = m['originalName'] ?? 'Sans nom';
    final analyzed   = m['analyzed'] == true;
    final score      = m['similarityScore'] as double?;
    final objects    = (m['aiObjects'] as List? ?? []);
    final confidence = (m['aiConfidence'] as num?)?.toDouble() ?? 0.0;
    final previewUrl = _previewUrl(m);
    final isImage    = type == 'image';

    return GestureDetector(
      onLongPress: () => _showMediaOptions(m),
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: score != null ? AppColors.primary.withOpacity(score.clamp(0.0, 1.0)) : Colors.white.withOpacity(0.06),
          ),
        ),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: isImage && previewUrl != null
                ? Image.network(previewUrl, width: 64, height: 64, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _thumbIcon(type))
                : _thumbIcon(type),
          ),
          SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            SizedBox(height: 4),
            Row(children: [
              Icon(Icons.circle, size: 7, color: analyzed ? AppColors.success : AppColors.warning),
              SizedBox(width: 5),
              Text(analyzed ? 'Analysé' : 'En attente', style: AppTextStyles.caption.copyWith(fontSize: 11)),
              if (objects.isNotEmpty) ...[
                SizedBox(width: 8),
                Expanded(child: Text(objects.take(2).join(', '),
                    style: AppTextStyles.caption.copyWith(fontSize: 10, color: AppColors.secondary),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ]),
            if (confidence > 0)
              Text('IA: ${(confidence * 100).toStringAsFixed(0)}%',
                  style: AppTextStyles.caption.copyWith(fontSize: 10, color: AppColors.warning)),
          ])),
          if (score != null)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary.withOpacity(0.4)),
              ),
              child: Column(children: [
                Text('${(score * 100).toStringAsFixed(0)}%',
                    style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w800)),
                Text('match', style: AppTextStyles.caption.copyWith(fontSize: 9)),
              ]),
            ),
        ]),
      ),
    );
  }

  Widget _iconPreview(String type, {double height = 120}) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _typeGradient(type).map((c) => c.withOpacity(0.3)).toList(),
        ),
      ),
      child: Icon(_typeIcon(type), color: Colors.white54, size: height * 0.35),
    );
  }

  Widget _fullIconPreview(String type) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: _typeGradient(type).map((c) => c.withOpacity(0.5)).toList(),
        ),
      ),
      child: Center(child: Icon(_typeIcon(type), color: Colors.white70, size: 56)),
    );
  }

  Widget _thumbIcon(String type) {
    return Container(
      width: 64, height: 64,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: _typeGradient(type)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(_typeIcon(type), color: Colors.white, size: 28),
    );
  }

  Widget _buildListTile(Map m) {
    final type       = m['type'] ?? 'document';
    final name       = m['originalName'] ?? 'Sans nom';
    final analyzed   = m['analyzed'] == true;
    final previewUrl = _previewUrl(m);
    final isImage    = type == 'image';

    return GestureDetector(
      onLongPress: () => _showMediaOptions(m),
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Row(children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: isImage && previewUrl != null
                ? Image.network(
                    previewUrl,
                    width: 64, height: 64, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _thumbIcon(type),
                  )
                : _thumbIcon(type),
          ),
          SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            SizedBox(height: 4),
            Row(children: [
              Icon(Icons.circle, size: 7, color: analyzed ? AppColors.success : AppColors.warning),
              SizedBox(width: 5),
              Text(analyzed ? 'Analysé par IA' : 'En attente d\'analyse',
                  style: AppTextStyles.caption.copyWith(fontSize: 11)),
              SizedBox(width: 10),
              Text(_formatSize(m['size']), style: AppTextStyles.caption.copyWith(fontSize: 11)),
            ]),
          ])),
          Icon(Icons.chevron_right, color: AppColors.textMuted),
        ]),
      ),
    );
  }

  // ─── CHATBOT TAB ────────────────────────
  Widget _buildChatbotTab() => ChatbotPage(medias: _allMedias);

  // ─── BOTTOM NAV ─────────────────────────
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: SafeArea(
        child: TabBar(
          controller: _tabCtrl,
          indicatorColor: Colors.transparent,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          labelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          tabs: [
            Tab(icon: Icon(Icons.home_outlined), text: 'Accueil'),
            Tab(icon: Icon(Icons.search_rounded), text: 'Recherche'),
            Tab(icon: Icon(Icons.smart_toy_outlined), text: 'Assistant IA'),
          ],
        ),
      ),
    );
  }

  // ─── FAB ────────────────────────────────
  Widget _buildFAB() {
    return FloatingActionButton.extended(
      backgroundColor: AppColors.primary,
      onPressed: _uploading ? null : _showUploadDialog,
      icon: _uploading
          ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : Icon(Icons.add_rounded),
      label: Text(_uploading ? 'Upload...' : 'Ajouter', style: TextStyle(fontWeight: FontWeight.w700)),
      elevation: 4,
    );
  }

  void _showProfileSheet() {
    // Lire l'email depuis les prefs
    SharedPreferences.getInstance().then((prefs) {
      final userJson = prefs.getString('user');
      final userMap  = userJson != null ? jsonDecode(userJson) as Map : {};
      final email    = userMap['email'] ?? 'Utilisateur';
      final role     = userMap['role'] ?? 'user';

      showModalBottomSheet(
        context: context,
        backgroundColor: AppColors.darkCard,
        isScrollControlled: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        builder: (_) => SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              SizedBox(height: 20),
              CircleAvatar(radius: 36, backgroundColor: AppColors.primary, child: Icon(Icons.person, color: Colors.white, size: 36)),
              SizedBox(height: 12),
              Text('Mon Compte', style: AppTextStyles.title),
              SizedBox(height: 4),
              Text(email, style: AppTextStyles.caption),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: role == 'admin' ? AppColors.accent.withOpacity(0.2) : AppColors.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(role == 'admin' ? '👑 Admin' : '👤 Utilisateur',
                    style: TextStyle(color: role == 'admin' ? AppColors.accent : AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
              SizedBox(height: 20),
              Divider(color: Colors.white12),
              _optionTile(Icons.swap_horiz_rounded, 'Changer de compte', () {
                Navigator.pop(context);
                _showSwitchAccountDialog();
              }, color: AppColors.secondary),
              if (role == 'admin')
                _optionTile(Icons.admin_panel_settings, 'Tableau de bord Admin', () {
                  Navigator.pop(context);
                  Navigator.push(context, _slideRoute(AdminDashboard()));
                }, color: AppColors.warning),
              _optionTile(Icons.logout, 'Se déconnecter', () {
                Navigator.pop(context);
                _logout();
              }, color: AppColors.accent),
            ]),
          ),
        ),
      );
    });
  }

  void _showSwitchAccountDialog() {
    final emailCtrl = TextEditingController();
    final passCtrl  = TextEditingController();
    bool obscure    = true;
    bool loading    = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppColors.darkCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            Icon(Icons.swap_horiz_rounded, color: AppColors.secondary),
            SizedBox(width: 8),
            Text('Changer de compte', style: TextStyle(color: Colors.white, fontSize: 16)),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: emailCtrl,
              style: TextStyle(color: Colors.white),
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email',
                labelStyle: TextStyle(color: AppColors.textMuted),
                prefixIcon: Icon(Icons.email_outlined, color: AppColors.primary),
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: passCtrl,
              obscureText: obscure,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Mot de passe',
                labelStyle: TextStyle(color: AppColors.textMuted),
                prefixIcon: Icon(Icons.lock_outlined, color: AppColors.primary),
                suffixIcon: IconButton(
                  icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppColors.textMuted),
                  onPressed: () => setS(() => obscure = !obscure),
                ),
              ),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Annuler', style: TextStyle(color: AppColors.textMuted))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
              onPressed: loading ? null : () async {
                if (emailCtrl.text.isEmpty || passCtrl.text.isEmpty) return;
                setS(() => loading = true);
                try {
                  final res = await http.post(
                    Uri.parse('$baseUrl/api/auth/login'),
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode({'email': emailCtrl.text.trim(), 'password': passCtrl.text}),
                  ).timeout(Duration(seconds: 15));
                  if (res.statusCode == 200) {
                    final data  = jsonDecode(res.body);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('token', data['token']);
                    await prefs.setString('user', jsonEncode(data['user']));
                    final role = data['user']['role'] ?? 'user';
                    Navigator.pop(ctx);
                    if (role == 'admin') {
                      Navigator.pushReplacement(context, _slideRoute(AdminDashboard()));
                    } else {
                      Navigator.pushReplacement(context, _slideRoute(Dashboard()));
                    }
                  } else {
                    setS(() => loading = false);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Email ou mot de passe incorrect')));
                  }
                } catch (e) {
                  setS(() => loading = false);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur de connexion')));
                }
              },
              child: loading ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text('Se connecter'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── HELPERS ────────────────────────────
  IconData _typeIcon(String type) {
    switch (type) {
      case 'image':    return Icons.image_outlined;
      case 'video':    return Icons.videocam_outlined;
      case 'audio':    return Icons.audiotrack_outlined;
      default:         return Icons.insert_drive_file_outlined;
    }
  }

  List<Color> _typeGradient(String type) {
    switch (type) {
      case 'image':    return [Color(0xFF6C63FF), Color(0xFF9C63FF)];
      case 'video':    return [Color(0xFFFF6584), Color(0xFFFF8C69)];
      case 'audio':    return [Color(0xFF3ECFCF), Color(0xFF3E9FCF)];
      default:         return [Color(0xFF4CAF50), Color(0xFF81C784)];
    }
  }
}

// ══════════════════════════════════════════
//  UPLOAD SHEET WIDGET
// ══════════════════════════════════════════
class _UploadSheet extends StatelessWidget {
  final VoidCallback onPickImage;
  final VoidCallback onPickCamera;
  final VoidCallback onPickVideo;
  final VoidCallback onPickDoc;
  final VoidCallback onPickAudio;

  const _UploadSheet({
    required this.onPickImage,
    required this.onPickCamera,
    required this.onPickVideo,
    required this.onPickDoc,
    required this.onPickAudio,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          SizedBox(height: 20),
          Text('Ajouter un média', style: AppTextStyles.title),
          SizedBox(height: 24),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _UploadOption(icon: Icons.photo_library_outlined, label: 'Galerie', color: Color(0xFF6C63FF), onTap: onPickImage),
            _UploadOption(icon: Icons.camera_alt_outlined, label: 'Caméra', color: Color(0xFF3ECFCF), onTap: onPickCamera),
            _UploadOption(icon: Icons.videocam_outlined, label: 'Vidéo', color: Color(0xFFFF6584), onTap: onPickVideo),
            _UploadOption(icon: Icons.audiotrack_outlined, label: 'Audio', color: Color(0xFF4CAF50), onTap: onPickAudio),
            _UploadOption(icon: Icons.description_outlined, label: 'Document', color: Color(0xFFFF9800), onTap: onPickDoc),
          ]),
          SizedBox(height: 20),
        ]),
      ),
    );
  }
}

class _UploadOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _UploadOption({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Icon(icon, color: color, size: 26),
        ),
        SizedBox(height: 8),
        Text(label, style: TextStyle(color: AppColors.textLight, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ══════════════════════════════════════════
//  CHATBOT PAGE
// ══════════════════════════════════════════
class ChatbotPage extends StatefulWidget {
  final List medias;
  const ChatbotPage({required this.medias});

  @override
  _ChatbotPageState createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> {
  final List<Map<String, dynamic>> _messages = [];
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  bool _thinking = false;

  @override
  void initState() {
    super.initState();
    _addBot('👋 Bonjour ! Je suis votre assistant IA SmartMedia.\n\nJe peux vous aider à :\n• Trouver des médias dans votre bibliothèque\n• Analyser et tagger vos fichiers avec MobileNet + CLIP\n• Recherche sémantique (ex: "chien qui court")\n• Répondre à vos questions\n\nQue puis-je faire pour vous ?');
  }

  void _addBot(String text) {
    setState(() => _messages.add({'role': 'bot', 'text': text, 'time': DateTime.now()}));
    _scrollDown();
  }

  void _addUser(String text) {
    setState(() => _messages.add({'role': 'user', 'text': text, 'time': DateTime.now()}));
    _scrollDown();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent + 100,
          duration: Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _thinking) return;
    _msgCtrl.clear();
    _addUser(text);
    setState(() => _thinking = true);

    await Future.delayed(Duration(milliseconds: 800));
    final reply = _generateReply(text);

    setState(() => _thinking = false);
    _addBot(reply);
  }

  String _generateReply(String query) {
    final q = query.toLowerCase();
    final total = widget.medias.length;
    final images = widget.medias.where((m) => m['type'] == 'image').length;
    final videos = widget.medias.where((m) => m['type'] == 'video').length;
    final audios = widget.medias.where((m) => m['type'] == 'audio').length;
    final docs   = widget.medias.where((m) => m['type'] == 'document').length;
    final analyzed = widget.medias.where((m) => m['analyzed'] == true).length;

    if (q.contains('bonjour') || q.contains('salut') || q.contains('hello'))
      return 'Bonjour ! 😊 Comment puis-je vous aider avec votre médiathèque ?';

    if (q.contains('combien') || q.contains('total') || q.contains('statistique') || q.contains('stats'))
      return '📊 Voici vos statistiques :\n\n'
          '• Total : $total médias\n'
          '• Images : $images\n'
          '• Vidéos : $videos\n'
          '• Audios : $audios\n'
          '• Documents : $docs\n'
          '• Analysés par IA : $analyzed';

    if (q.contains('image') || q.contains('photo'))
      return '🖼️ Vous avez $images image${images > 1 ? 's' : ''} dans votre bibliothèque.';

    if (q.contains('vidéo') || q.contains('video'))
      return '🎥 Vous avez $videos vidéo${videos > 1 ? 's' : ''} dans votre bibliothèque.';

    if (q.contains('audio') || q.contains('musique') || q.contains('son'))
      return '🎧 Vous avez $audios fichier${audios > 1 ? 's' : ''} audio dans votre bibliothèque.';

    if (q.contains('document') || q.contains('pdf') || q.contains('doc'))
      return '📄 Vous avez $docs document${docs > 1 ? 's' : ''} dans votre bibliothèque.';

    if (q.contains('analyser') || q.contains('analyse') || q.contains('ia') || q.contains('intelligence'))
      return '🤖 L\'IA a analysé $analyzed/$total médias.\n\nTechnologies utilisées :\n• MobileNetV3 — classification d\'images\n• OpenCV — extraction frames vidéo\n• CLIP (ViT-B/32) — embeddings image↔texte\n• FAISS — recherche vectorielle ultra-rapide\n• SentenceTransformers — embeddings texte\n\nTout fonctionne localement, sans API payante !';

    if (q.contains('cherche') || q.contains('trouve') || q.contains('search') || q.contains('recherch')) {
      final keyword = q.replaceAll(RegExp(r'(cherche|trouve|search|recherch[a-z]*)'), '').trim();
      if (keyword.isNotEmpty && widget.medias.isNotEmpty) {
        final found = widget.medias.where((m) =>
            (m['originalName'] ?? '').toLowerCase().contains(keyword) ||
            (m['tags'] ?? []).join(' ').toLowerCase().contains(keyword) ||
            (m['aiObjects'] ?? []).join(' ').toLowerCase().contains(keyword)).toList();
        if (found.isNotEmpty) {
          final names = found.take(5).map((m) {
            final objs = (m['aiObjects'] as List? ?? []);
            final objStr = objs.isNotEmpty ? ' (${objs.take(2).join(', ')})' : '';
            return '• ${m['originalName']}$objStr';
          }).join('\n');
          return '🔍 Trouvé ${found.length} résultat${found.length > 1 ? 's' : ''} :\n\n$names\n\n💡 Utilisez l\'onglet Recherche IA pour une recherche sémantique avancée.';
        } else {
          return '🔍 Aucun média trouvé pour "$keyword".\n\n💡 Essayez la recherche sémantique dans l\'onglet Recherche — elle comprend le sens, pas juste les mots exacts.';
        }
      }
      return '🔍 Utilisez l\'onglet Recherche IA pour trouver vos fichiers par description (ex: "chien noir", "coucher de soleil").';
    }

    if (q.contains('supprimer') || q.contains('effacer') || q.contains('delete'))
      return '🗑️ Pour supprimer un média, appuyez longuement sur la carte du fichier dans l\'onglet Accueil, puis sélectionnez "Supprimer".';

    if (q.contains('ajouter') || q.contains('upload') || q.contains('envoyer'))
      return '📤 Pour ajouter un fichier :\n1. Retournez à l\'onglet Accueil\n2. Appuyez sur le bouton "+ Ajouter"\n3. Choisissez le type de fichier\n4. Sélectionnez votre fichier\n\nL\'IA l\'analysera automatiquement !';

    if (q.contains('aide') || q.contains('help') || q.contains('que') || q.contains('quoi'))
      return '💡 Je peux vous aider à :\n\n'
          '• 📊 Voir vos statistiques\n'
          '• 🔍 Rechercher des fichiers\n'
          '• 🖼️ Compter vos images/vidéos\n'
          '• 📤 Guide pour uploader\n'
          '• 🤖 Expliquer l\'analyse IA\n\n'
          'Posez-moi n\'importe quelle question !';

    if (q.contains('merci') || q.contains('thanks'))
      return 'Avec plaisir ! 😊 N\'hésitez pas si vous avez d\'autres questions.';

    // Suggestions rapides
    final suggestions = [
      'Bonne question ! En ce moment, votre bibliothèque contient $total médias dont $analyzed ont été analysés par l\'IA.\n\nSouhaitez-vous des détails sur un type spécifique ?',
      'Je suis votre assistant personnel SmartMedia. Je gère actuellement $total fichiers pour vous. Que souhaitez-vous savoir ?',
      'Intéressant ! Pour l\'instant, votre médiathèque est composée de $images images, $videos vidéos, $audios audios et $docs documents.',
    ];
    return suggestions[Random().nextInt(suggestions.length)];
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(children: [
        // HEADER
        Container(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Row(children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.primary, AppColors.secondary]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.smart_toy_outlined, color: Colors.white, size: 22),
            ),
            SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Assistant IA', style: AppTextStyles.title.copyWith(fontSize: 18)),
              Row(children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.success, shape: BoxShape.circle)),
                SizedBox(width: 5),
                Text('En ligne', style: AppTextStyles.caption.copyWith(color: AppColors.success, fontSize: 12)),
              ]),
            ]),
          ]),
        ),
        Divider(color: Colors.white10, height: 1),

        // MESSAGES
        Expanded(
          child: ListView.builder(
            controller: _scrollCtrl,
            padding: EdgeInsets.all(16),
            itemCount: _messages.length + (_thinking ? 1 : 0),
            itemBuilder: (_, i) {
              if (_thinking && i == _messages.length) return _buildTypingIndicator();
              final msg = _messages[i];
              return _buildMessage(msg);
            },
          ),
        ),

        // QUICK REPLIES
        if (_messages.length <= 1)
          Container(
            height: 42,
            margin: EdgeInsets.only(bottom: 8),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16),
              children: [
                '📊 Mes stats', '🖼️ Mes images', '🎥 Mes vidéos', '📤 Comment uploader ?', '🤖 Analyse IA',
              ].map((q) => GestureDetector(
                onTap: () { _msgCtrl.text = q.replaceAll(RegExp(r'[📊🖼️🎥📤🤖] '), ''); _send(); },
                child: Container(
                  margin: EdgeInsets.only(right: 8),
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.darkCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primary.withOpacity(0.5)),
                  ),
                  child: Text(q, style: TextStyle(color: AppColors.secondary, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              )).toList(),
            ),
          ),

        // INPUT
        Container(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
          decoration: BoxDecoration(
            color: AppColors.darkCard,
            border: Border(top: BorderSide(color: Colors.white10)),
          ),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _msgCtrl,
                style: TextStyle(color: Colors.white, fontSize: 14),
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: 'Posez votre question…',
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: Colors.white12)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: AppColors.primary)),
                ),
              ),
            ),
            SizedBox(width: 10),
            GestureDetector(
              onTap: _send,
              child: Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.primary, AppColors.secondary]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildMessage(Map<String, dynamic> msg) {
    final isBot = msg['role'] == 'bot';
    return Align(
      alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: EdgeInsets.only(bottom: 12, right: isBot ? 60 : 0, left: isBot ? 0 : 60),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: isBot
              ? null
              : LinearGradient(colors: [AppColors.primary, AppColors.secondary]),
          color: isBot ? AppColors.darkCard : null,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: isBot ? Radius.circular(4) : Radius.circular(18),
            bottomRight: isBot ? Radius.circular(18) : Radius.circular(4),
          ),
          border: isBot ? Border.all(color: Colors.white10) : null,
        ),
        child: Text(
          msg['text'],
          style: TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _dot(0), _dot(150), _dot(300),
        ]),
      ),
    );
  }

  Widget _dot(int delayMs) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      builder: (_, v, __) => Container(
        margin: EdgeInsets.symmetric(horizontal: 3),
        width: 8, height: 8,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.4 + 0.6 * v),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════
//  ROUTE HELPERS
// ══════════════════════════════════════════
PageRoute _slideRoute(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (_, anim, __) => page,
    transitionsBuilder: (_, anim, __, child) {
      return SlideTransition(
        position: Tween<Offset>(begin: Offset(1, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      );
    },
    transitionDuration: Duration(milliseconds: 350),
  );
}

PageRoute _fadeRoute(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (_, anim, __) => page,
    transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
    transitionDuration: Duration(milliseconds: 300),
  );
}

// ══════════════════════════════════════════
//  ADMIN DASHBOARD
// ══════════════════════════════════════════
class AdminDashboard extends StatefulWidget {
  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> with TickerProviderStateMixin {
  Map<String, dynamic> _stats = {};
  List _users  = [];
  List _medias = [];
  bool _loading = true;
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _fetchAll();
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  Future<String> _token() async {
    final p = await SharedPreferences.getInstance();
    return p.getString('token') ?? '';
  }

  Future<void> _fetchAll() async {
    setState(() => _loading = true);
    await Future.wait([_fetchStats(), _fetchUsers(), _fetchMedias()]);
    setState(() => _loading = false);
  }

  Future<void> _fetchStats() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/admin/stats'),
          headers: {'Authorization': 'Bearer ${await _token()}'}).timeout(Duration(seconds: 10));
      if (res.statusCode == 200) setState(() => _stats = jsonDecode(res.body));
    } catch (_) {}
  }

  Future<void> _fetchUsers() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/admin/users'),
          headers: {'Authorization': 'Bearer ${await _token()}'}).timeout(Duration(seconds: 10));
      if (res.statusCode == 200) setState(() => _users = jsonDecode(res.body));
    } catch (_) {}
  }

  Future<void> _fetchMedias() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/admin/medias'),
          headers: {'Authorization': 'Bearer ${await _token()}'}).timeout(Duration(seconds: 10));
      if (res.statusCode == 200) setState(() => _medias = jsonDecode(res.body));
    } catch (_) {}
  }

  Future<void> _toggleUser(Map u) async {
    final newStatus = !(u['isActive'] == true);
    final res = await http.put(
      Uri.parse('$baseUrl/api/admin/users/${u['id']}'),
      headers: {'Authorization': 'Bearer ${await _token()}', 'Content-Type': 'application/json'},
      body: jsonEncode({'is_active': newStatus}),
    );
    if (res.statusCode == 200) _fetchUsers();
  }

  Future<void> _deleteUser(Map u) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/api/admin/users/${u['id']}'),
      headers: {'Authorization': 'Bearer ${await _token()}'},
    );
    if (res.statusCode == 200) _fetchUsers();
  }

  Future<void> _deleteMedia(Map m) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/api/admin/medias/${m['id']}'),
      headers: {'Authorization': 'Bearer ${await _token()}'},
    );
    if (res.statusCode == 200) _fetchMedias();
  }

  Future<void> _logout() async {
    final p = await SharedPreferences.getInstance();
    await p.clear();
    Navigator.pushReplacement(context, _fadeRoute(LoginPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dark,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Row(children: [
          Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.accent, AppColors.primary]),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.admin_panel_settings, color: Colors.white, size: 18),
          ),
          SizedBox(width: 10),
          Text('Administration', style: AppTextStyles.title),
        ]),
        actions: [
          IconButton(icon: Icon(Icons.refresh, color: Colors.white), onPressed: _fetchAll),
          IconButton(icon: Icon(Icons.logout, color: AppColors.accent), onPressed: _logout),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          tabs: [
            Tab(icon: Icon(Icons.bar_chart), text: 'Stats'),
            Tab(icon: Icon(Icons.people), text: 'Utilisateurs'),
            Tab(icon: Icon(Icons.perm_media), text: 'Médias'),
          ],
        ),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: AppColors.primary))
          : TabBarView(controller: _tabCtrl, children: [
              _buildStats(),
              _buildUsers(),
              _buildMedias(),
            ]),
    );
  }

  // ── Stats ──────────────────────────────
  Widget _buildStats() {
    final items = [
      {'icon': Icons.people, 'label': 'Utilisateurs', 'value': '${_stats['totalUsers'] ?? 0}', 'color': AppColors.primary},
      {'icon': Icons.verified_user, 'label': 'Actifs', 'value': '${_stats['activeUsers'] ?? 0}', 'color': AppColors.success},
      {'icon': Icons.admin_panel_settings, 'label': 'Admins', 'value': '${_stats['totalAdmins'] ?? 0}', 'color': AppColors.accent},
      {'icon': Icons.photo_library, 'label': 'Médias', 'value': '${_stats['totalMedias'] ?? 0}', 'color': AppColors.secondary},
      {'icon': Icons.auto_awesome, 'label': 'Analysés', 'value': '${_stats['analyzedMedias'] ?? 0}', 'color': AppColors.warning},
      {'icon': Icons.storage, 'label': 'Stockage', 'value': '${_stats['totalStorage'] ?? '0 GB'}', 'color': AppColors.gradEnd},
    ];
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(height: 8),
        Text('Vue globale', style: AppTextStyles.title),
        SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.4,
          ),
          itemCount: items.length,
          itemBuilder: (_, i) {
            final item = items[i];
            final color = item['color'] as Color;
            return Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.darkCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(item['icon'] as IconData, color: color, size: 24),
                Spacer(),
                Text(item['value'] as String, style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                Text(item['label'] as String, style: AppTextStyles.caption),
              ]),
            );
          },
        ),
      ]),
    );
  }

  // ── Utilisateurs ───────────────────────
  Widget _buildUsers() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _users.length,
      itemBuilder: (_, i) {
        final u = _users[i] as Map;
        final isAdmin = u['role'] == 'admin';
        final isActive = u['isActive'] == true;
        return Container(
          margin: EdgeInsets.only(bottom: 10),
          padding: EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.darkCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isAdmin ? AppColors.accent.withOpacity(0.4) : Colors.white10),
          ),
          child: Row(children: [
            CircleAvatar(
              backgroundColor: isAdmin ? AppColors.accent.withOpacity(0.2) : AppColors.primary.withOpacity(0.2),
              child: Icon(isAdmin ? Icons.admin_panel_settings : Icons.person,
                  color: isAdmin ? AppColors.accent : AppColors.primary, size: 20),
            ),
            SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(u['email'] ?? '', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              SizedBox(height: 3),
              Row(children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isAdmin ? AppColors.accent.withOpacity(0.2) : AppColors.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(isAdmin ? 'Admin' : 'User',
                      style: TextStyle(color: isAdmin ? AppColors.accent : AppColors.primary, fontSize: 10, fontWeight: FontWeight.w700)),
                ),
                SizedBox(width: 8),
                Icon(Icons.circle, size: 7, color: isActive ? AppColors.success : AppColors.accent),
                SizedBox(width: 4),
                Text(isActive ? 'Actif' : 'Désactivé', style: AppTextStyles.caption.copyWith(fontSize: 10)),
              ]),
            ])),
            if (!isAdmin) ...[
              IconButton(
                icon: Icon(isActive ? Icons.block : Icons.check_circle_outline,
                    color: isActive ? AppColors.warning : AppColors.success, size: 20),
                onPressed: () => _toggleUser(u),
                tooltip: isActive ? 'Désactiver' : 'Activer',
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, color: AppColors.accent, size: 20),
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: AppColors.darkCard,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: Text('Supprimer ?', style: TextStyle(color: Colors.white)),
                    content: Text('Supprimer ${u['email']} ?', style: TextStyle(color: AppColors.textLight)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
                        onPressed: () { Navigator.pop(context); _deleteUser(u); },
                        child: Text('Supprimer'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ]),
        );
      },
    );
  }

  // ── Médias ─────────────────────────────
  Widget _buildMedias() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _medias.length,
      itemBuilder: (_, i) {
        final m = _medias[i] as Map;
        final type = m['type'] ?? 'document';
        return Container(
          margin: EdgeInsets.only(bottom: 10),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.darkCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: _typeGradient(type)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_typeIcon(type), color: Colors.white, size: 18),
            ),
            SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m['originalName'] ?? '', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('User ID: ${m['userId']} • ${_formatSizeAdmin(m['size'])}',
                  style: AppTextStyles.caption.copyWith(fontSize: 10)),
            ])),
            IconButton(
              icon: Icon(Icons.delete_outline, color: AppColors.accent, size: 20),
              onPressed: () => _deleteMedia(m),
            ),
          ]),
        );
      },
    );
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'image': return Icons.image_outlined;
      case 'video': return Icons.videocam_outlined;
      case 'audio': return Icons.audiotrack_outlined;
      default:      return Icons.insert_drive_file_outlined;
    }
  }

  List<Color> _typeGradient(String type) {
    switch (type) {
      case 'image': return [Color(0xFF6C63FF), Color(0xFF9C63FF)];
      case 'video': return [Color(0xFFFF6584), Color(0xFFFF8C69)];
      case 'audio': return [Color(0xFF3ECFCF), Color(0xFF3E9FCF)];
      default:      return [Color(0xFF4CAF50), Color(0xFF81C784)];
    }
  }

  String _formatSizeAdmin(dynamic bytes) {
    if (bytes == null) return '-';
    final b = (bytes is int) ? bytes : (bytes as num).toInt();
    if (b < 1024) return '$b B';
    if (b < 1048576) return '${(b/1024).toStringAsFixed(1)} KB';
    return '${(b/1048576).toStringAsFixed(2)} MB';
  }
}
