// ... (Code from Part 1 ends here) ...
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart' as crypto;
import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
// import 'package:shared_preferences/shared_preferences.dart'; // No longer needed
import 'package:intl/intl.dart';
import 'package:app_links/app_links.dart'; // ✅ Add this line
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:flutter/services.dart';
// --- MODIFIED IMPORTS for Share/Download ---
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:gal/gal.dart';
import 'dart:io';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'; // Required for compute
import 'package:shimmer/shimmer.dart';
import 'dart:ui';
// --- VIDEO SUPPORT: Import video_player ---
import 'package:video_player/video_player.dart';
// --- CACHING: Import cached_network_image ---
import 'package:cached_network_image/cached_network_image.dart';
// --- CACHING: Import cache manager for clearing ---
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
// --- OFFLINE CHECK: Import connectivity_plus ---
import 'package:connectivity_plus/connectivity_plus.dart';
// --- FIREBASE IMPORTS ---
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_analytics/observer.dart';
// --- IAP IMPORT ---
import 'package:in_app_purchase/in_app_purchase.dart';
// --- NEW: Platform specific IAP ---
// Required for completing purchases on Android, especially outside the US
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http_parser/http_parser.dart'; // For Dropbox POST headers
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:shared_preferences/shared_preferences.dart'; // <-- ADD THIS
import 'package:flutter/gestures.dart'; // <-- ADD THIS
import 'ui/smart_migration_page.dart';
import 'package:workmanager/workmanager.dart';
import 'background_scan_worker.dart';
import 'memories_page.dart';
import 'ui/people_page.dart';
import 'services/foreground_scanner.dart';
import 'data/person_record.dart';
import 'data/face_record.dart';
// --- NEW: DEDUPLICATION IMPORTS ---
// For image decoding and pHash calculation
import 'package:image/image.dart' as img;
// For pHash comparison
import 'package:collection/collection.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
// --- MEGA IMPORTS (Client-side AES-128 Encryption) ---
import 'package:encrypt/encrypt.dart' as enc;
// Isar imports
import 'package:isar/isar.dart';
import 'ai_tag.dart';
import 'data/asset_repository.dart'; // Phase 1: Centralized Asset Tracking
import 'notification_service.dart';
// Global Isar instance (initialized in main())
late Isar isar;
// Global AssetRepository instance (initialized in main() after Isar opens)
late AssetRepository assetRepository;
// --- GLOBAL GOOGLE SIGN IN INSTANCE ---
// FIX: serverClientId prevents SignInHubActivity NPE on devices where
// google_sign_in_android 6.2.1 builds a null PendingIntent without it.
// Web Client ID (client_type: 3) sourced directly from android/app/google-services.json
final GoogleSignIn googleSignIn = GoogleSignIn(
  scopes: ['email'],
  serverClientId: '555390520562-d4gqv5cdvj754penvadcdith7mf5c807.apps.googleusercontent.com', // Web client ID (client_type:3) from google-services.json
);
// --- Configuration ---
const String oneDriveClientId = "06eb5566-31e3-486c-8036-a2c1746a32b6";
const String dropboxClientId = "bsdti9wpyb1iojt";
const String redirectUri = "com.pranav.onedrivephotos://auth";
const String oneDriveScope =
    "files.read.all files.readwrite.all user.read offline_access";
const String dropboxScope =
    "files.content.read files.metadata.read files.content.write account_info.read";
// --- Endpoints ---
const String oneDriveAuthorizationEndpoint =
    'https://login.microsoftonline.com/common/oauth2/v2.0/authorize';
const String oneDriveTokenEndpoint =
    'https://login.microsoftonline.com/common/oauth2/v2.0/token';
const String oneDriveGraphBase = 'https://graph.microsoft.com/v1.0';
const String dropboxAuthorizationEndpoint =
    'https://www.dropbox.com/oauth2/authorize';
const String dropboxTokenEndpoint = 'https://api.dropboxapi.com/oauth2/token';
const String dropboxApiBase = 'https://api.dropboxapi.com/2';
// ✅ ADD THESE NEW CONSTANTS
const String googleDriveScope = 'https://www.googleapis.com/auth/drive.readonly';
const String googleDriveApiBase = 'https://www.googleapis.com/drive/v3';
// ✅ ADD THESE NEW CONSTANTS
const String boxClientId = "hyoa0rnuanwkib8qlektw13hlqae2cip"; // ⚠️ PASTE YOUR CLIENT ID HERE
const String boxClientSecret = "F5ThaxdwmYVJURk9AgiyPLfswnQWisq5"; // ⚠️ PASTE YOUR CLIENT SECRET HERE
const String boxScope = "root_readwrite";
const String boxAuthorizationEndpoint = 'https://account.box.com/api/oauth2/authorize';
const String boxTokenEndpoint = 'https://api.box.com/oauth2/token';
const String boxApiBase = 'https://api.box.com/2.0';
// --- ADD FOR PCLOUD ---
// pCloud OAuth2 and API Configuration
const String pCloudClientId = "qFomk1OSOQb";
const String pCloudRedirectUri = "com.pranav.onedrivephotos:/oauth2redirect";
const String pCloudScope = "files.read files.write";
const String pCloudAuthBase = "https://my.pcloud.com/oauth2";
const String pCloudApiBase = "https://api.pcloud.com";

/// Safely parse pCloud dates which can be RFC 1123 strings, ISO strings, or integer timestamps
DateTime? _parsePCloudDate(dynamic raw) {
  if (raw == null) return null;
  if (raw is int) {
    return raw > 100000000000
        ? DateTime.fromMillisecondsSinceEpoch(raw)
        : DateTime.fromMillisecondsSinceEpoch(raw * 1000);
  }
  if (raw is String) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    try {
      return HttpDate.parse(s);
    } catch (_) {}
    try {
      return DateTime.tryParse(s);
    } catch (_) {}
    try {
      return DateFormat("EEE, dd MMM yyyy HH:mm:ss Z").parse(s);
    } catch (_) {}
  }
  return null;
}
// --- ADD FOR MEGA ---
// Mega uses its own JSON-RPC API (NOT OAuth2). No App Key needed for basic usage.
const String megaApiBase = "https://g.api.mega.co.nz";
// --- Internal Testers Whitelist ---
const Set<String> _kInternalTesters = {
  'kartikurkude701@gmail.com',
  'kartik211299@gmail.com',
  'kar21urk12@gmail.com',
  'k8712699@gmail.com',
  'kartikurkude21@gmail.com',
  'mamtaurkude11@gmail.com',
  'ukartik21@gmail.com',
  'ukartik12@gmail.com',
  '0103ee171048@gmail.com',
  'ajayurkudebgt@gmail.com',
  'shubhamdada.kishadi@gmail.com',
  'shubhamdada.kishadii@gmail.com',
  'pranayurkude63@gmail.com',
  'pranayu63@gmail.com',
};

bool isInternalTester(String? email) {
  if (email == null || email.trim().isEmpty) return false;
  return _kInternalTesters.contains(email.trim().toLowerCase());
}
// --- AppAuth Configurations ---
const AuthorizationServiceConfiguration oneDriveServiceConfiguration =
    AuthorizationServiceConfiguration(
  authorizationEndpoint: oneDriveAuthorizationEndpoint,
  tokenEndpoint: oneDriveTokenEndpoint,
);
const AuthorizationServiceConfiguration dropboxServiceConfiguration =
    AuthorizationServiceConfiguration(
  authorizationEndpoint: dropboxAuthorizationEndpoint,
  tokenEndpoint: dropboxTokenEndpoint,
);
// ✅ ADD THIS
const AuthorizationServiceConfiguration boxServiceConfiguration =
    AuthorizationServiceConfiguration(
  authorizationEndpoint: boxAuthorizationEndpoint,
  tokenEndpoint: boxTokenEndpoint,
);
// ✅ Global Theme Notifier
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);
// ✅ Theme persistence helpers
Future<void> _saveThemePreference(ThemeMode mode) async {
  final prefs = await SharedPreferences.getInstance();
  final modeStr = mode == ThemeMode.dark ? 'dark' : (mode == ThemeMode.light ? 'light' : 'system');
  await prefs.setString('app_theme_mode', modeStr);
}
Future<void> _loadThemePreference() async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString('app_theme_mode');
  if (saved == 'dark') {
    themeNotifier.value = ThemeMode.dark;
  } else if (saved == 'light') {
    themeNotifier.value = ThemeMode.light;
  } else {
    themeNotifier.value = ThemeMode.system;
  }
}
final FlutterAppAuth appAuth = FlutterAppAuth();
const FlutterSecureStorage secureStorage = FlutterSecureStorage();
// --- Enums and Models ---
enum PhotoSource { oneDrive, dropbox, googleDrive, box, pCloud, mega, local }
enum FilterSource { all, oneDrive, dropbox, googleDrive, box, pCloud, mega, local }
enum FilterType { all, photos, videos }
// --- NEW ENUM: SortOption ---
enum SortOption { newestFirst, oldestFirst, nameAZ, nameZA }
class DriveItem {
  final String id;
  final String name;
  final PhotoSource source;
  String? downloadUrl;
  String? thumbnailUrl;
  DateTime? created;
  BigInt? pHash;
  String? contentHash;
  String? cachedDownloadUrl;
  String? cachedBase64Thumbnail;
  final bool isVideo;
  final bool isFolder;
  List<String>? aiTags;
  final int? size;
  AssetEntity? localAsset; // ✅ Cached AssetEntity for local photos
  DriveItem({
    required this.id,
    required this.name,
    required this.source,
    this.downloadUrl,
    this.created,
    this.thumbnailUrl,
    this.pHash,
    this.contentHash,
    this.cachedDownloadUrl,
    this.cachedBase64Thumbnail,
    this.isVideo = false,
    this.isFolder = false,
    this.aiTags,
    this.size,
    this.localAsset, // ✅ Add to constructor
  });
  String getUniqueKey() => '${source.name}::$id';
  bool get isVideoFile {
    final lowerCaseName = name.toLowerCase();
    return lowerCaseName.endsWith('.mp4') ||
        lowerCaseName.endsWith('.mov') ||
        lowerCaseName.endsWith('.wmv');
  }
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'source': source.index,
        'downloadUrl': downloadUrl,
        'created': created?.toIso8601String(),
        'thumbnailUrl': thumbnailUrl,
        'cachedBase64Thumbnail': cachedBase64Thumbnail,
        'isVideo': isVideo,
        'isFolder': isFolder,
        'aiTags': aiTags,
        'size': size,
      };
  factory DriveItem.fromJson(Map<String, dynamic> json) {
    return DriveItem(
      id: json['id'],
      name: json['name'],
      source: PhotoSource.values[json['source']],
      downloadUrl: json['downloadUrl'],
      created: json['created'] != null ? DateTime.parse(json['created']) : null,
      thumbnailUrl: json['thumbnailUrl'],
      cachedBase64Thumbnail: json['cachedBase64Thumbnail'],
      isVideo: json['isVideo'] ?? false,
      isFolder: json['isFolder'] ?? false,
      aiTags: (json['aiTags'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      size: json['size'],
    );
  }
}
// --- FIREBASE: Initialize Firebase ---
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  //
  // ✅ INITIALIZE WORKMANAGER for background pHash scanning (Android only)
  //
  await Workmanager().initialize(
    callbackDispatcher, // Top-level entry point in background_scan_worker.dart
    isInDebugMode: false, // Set true during development to see WorkManager logs
  );
  // Register periodic background face-scan that fires every 6h ONLY when charging
  await ForegroundScanner.registerBackgroundScanTask();
  //
  // ✅ ADD THIS BLOCK TO INITIALIZE ISAR
  //
  try {
    print("📾 Initializing Isar database...");
    final dir = await getApplicationDocumentsDirectory();
    isar = await Isar.open(
      [AITagSchema, AssetRecordSchema, PersonRecordSchema, FaceRecordSchema],
      directory: dir.path,
    );
    assetRepository = AssetRepository(isar); // Initialize the repository singleton
    print("✅ Isar initialized successfully.");
  } catch (e, st) {
    print("❌ Isar init failed: $e");
    print(st);
  }
  // --- NEW: Configure IAP for Play Store purchases ---
  // The billing permission has been added to AndroidManifest.xml.
  // We'll rely on the plugin's internal initialization for now.
  // Send all uncaught Flutter errors to Crashlytics
  // ✅ Initialize Firebase before using any Firebase service
  try {
    print("🥚 Starting Firebase initialization...");
    await Firebase.initializeApp();
    print("✅ Firebase initialized successfully.");
    print("🔔 Initializing NotificationService...");
    await NotificationService.initialize();
    // ✅ Load saved theme preference before showing any UI
    await _loadThemePreference();
    // Use non-fatal reporting for Flutter framework errors (layout issues, etc.)
    // so they don't inflate app_exception counts in Analytics.
    FlutterError.onError = (FlutterErrorDetails details) {
      // Only send truly unexpected errors — skip assertion/layout noise in debug
      FirebaseCrashlytics.instance.recordFlutterError(details, fatal: false);
    };
    // Filter PlatformDispatcher errors — skip expected network/auth errors
    // to prevent routine token-refresh failures from becoming app_exception events.
    PlatformDispatcher.instance.onError = (error, stack) {
      final msg = error.toString().toLowerCase();
      final isExpectedError =
          msg.contains('socketexception') ||         // No internet
          msg.contains('handshakeexception') ||      // SSL / network
          msg.contains('connection refused') ||
          msg.contains('connection timed out') ||
          msg.contains('token') ||                   // OAuth token expiry
          msg.contains('unauthorized') ||
          msg.contains('forbidden') ||
          msg.contains('permission') ||              // OS permission denials
          msg.contains('pathnotfoundexception') ||   // Cache file evicted by OS
          msg.contains('filesystemexception');       // Cache eviction race condition
      if (!isExpectedError) {
        // Only report truly unexpected errors as fatal
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      } else {
        // Log expected errors as non-fatal so they appear in Crashlytics
        // but do NOT fire app_exception in Analytics
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: false);
      }
      return true;
    };
    print("🚀 Initializing Analytics...");
    FirebaseAnalytics analytics = FirebaseAnalytics.instance;
    // Set initial lifecycle state for foreground service
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_is_resumed', true);
    runApp(const MyApp());
    print("🚀 runApp() called.");
  } catch (e, st) {
    print("❌ Firebase init failed: $e");
    print(st);
  }
}
class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    print("🏠 Building main UI widget...");
    // ✅ Wrap MaterialApp in ValueListenableBuilder to listen to theme changes
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          title: 'Cloud Photos',
          // ✅ Light Theme
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF0078D4),
              primary: const Color(0xFF0078D4),
              brightness: Brightness.light,
            ),
            primaryColor: const Color(0xFF0078D4),
            visualDensity: VisualDensity.adaptivePlatformDensity,
            scaffoldBackgroundColor: const Color(0xFFF5F7FA),
            brightness: Brightness.light,
            floatingActionButtonTheme: const FloatingActionButtonThemeData(
              backgroundColor: Color(0xFF0078D4),
              foregroundColor: Colors.white,
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0078D4),
                foregroundColor: Colors.white,
              ),
            ),
            appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFF0078D4),
                elevation: 0,
                iconTheme: IconThemeData(color: Colors.white),
                titleTextStyle: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600)),
            cardTheme: const CardThemeData(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12))),
              elevation: 2,
            ),
          ),
          // ✅ Dark Theme
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF0078D4),
              primary: const Color(0xFF0078D4),
              brightness: Brightness.dark,
            ),
            primaryColor: const Color(0xFF0078D4),
            scaffoldBackgroundColor: const Color(0xFF121212),
            floatingActionButtonTheme: const FloatingActionButtonThemeData(
              backgroundColor: Color(0xFF0078D4),
              foregroundColor: Colors.white,
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0078D4),
                foregroundColor: Colors.white,
              ),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF1E1E1E),
              elevation: 0,
              iconTheme: IconThemeData(color: Colors.white),
              titleTextStyle: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          themeMode: currentMode, // ✅ Use the notifier value
          home: const AuthGate(),
          // FIX: app_links delivers the OAuth redirect URI BOTH via uriLinkStream
          // (handled by _loginToPCloud listener) AND via didPushRouteInformation.
          // Flutter tries to push "/oauth2redirect#access_token=..." as a named route
          // which hits onUnknownRoute. Flutter requires non-null here.
          //
          // CRITICAL: Do NOT return AuthGate here — it triggers initState on the
          // new widget instance, which calls _tryAutoLogin → _fetchAllPhotos again,
          // causing duplicate network requests. Instead return a blank route that
          // immediately pops itself so the user stays on the existing screen.
          onUnknownRoute: (settings) {
            debugPrint('[Router] Deep-link absorbed (self-popping): '
                '${settings.name?.substring(0, (settings.name?.length ?? 0).clamp(0, 60))}...');
            return MaterialPageRoute<void>(
              settings: const RouteSettings(name: '/__deep_link_noop'),
              builder: (context) {
                // Pop on the first frame — returns to existing screen with zero UI flash
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) {
                    final nav = Navigator.of(context);
                    if (nav.canPop()) nav.pop();
                  }
                });
                return const SizedBox.shrink(); // invisible placeholder
              },
            );
          },
          navigatorObservers: [
            FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
          ],
          builder: (context, child) {
            return NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollStartNotification) {
                  ForegroundScanner().isUserScrolling = true;
                } else if (notification is ScrollEndNotification) {
                  ForegroundScanner().isUserScrolling = false;
                }
                return false;
              },
              child: child!,
            );
          },
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
// --- FIREBASE: AuthGate (Routing) ---
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}
class _AuthGateState extends State<AuthGate> {
  bool _isInitialized = false;
  late final Stream<User?> _authStream;

  @override
  void initState() {
    super.initState();
    // FIX: Use userChanges() instead of authStateChanges().
    // authStateChanges() only fires on sign-in/sign-out. userChanges() also
    // fires when the profile (displayName, photoURL) is updated, so the UI
    // immediately reflects the user's real name after Google Sign-In.
    _authStream = FirebaseAuth.instance.userChanges();
    _checkInitStatus();
  }
  Future<void> _checkInitStatus() async {
    // PERF: If Firebase already has a cached user session, mark initialized immediately
    // so the spinner is skipped on re-opens.
    final cachedUser = FirebaseAuth.instance.currentUser;
    if (cachedUser != null && mounted) {
      setState(() => _isInitialized = true);
    }
    // Read SharedPrefs for open count tracking
    final prefs = await SharedPreferences.getInstance();
    int openCount = prefs.getInt('app_open_count') ?? 0;
    openCount++;
    prefs.setInt('app_open_count', openCount);
    // If no Firebase session exists, sign in anonymously so the user goes
    // straight to the gallery without any login prompt.
    // Users can sign in from the drawer or when connecting a cloud account.
    if (cachedUser == null) {
      try {
        await FirebaseAuth.instance.signInAnonymously();
        // Request notification + media permissions on first open
        if (openCount == 1) {
          await NotificationService.requestPermissions();
        }
      } catch (e) {
        debugPrint("AuthGate: Auto-Guest failed: $e");
      }
    }
    if (mounted) {
      setState(() => _isInitialized = true);
    }
  }
  @override
  Widget build(BuildContext context) {
    // 1. Loading State
    if (!_isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    // 2. AUTH GATE: Listening to the Auth Stream
    return StreamBuilder<User?>(
      stream: _authStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        // If we have a user, enter the gallery
        if (snapshot.hasData) {
          final user = snapshot.data!;
          FirebaseAnalytics.instance.setUserProperty(
            name: 'login_status',
            value: user.isAnonymous ? 'anonymous' : 'registered'
          );
          // Save userId to prefs for background worker access
          SharedPreferences.getInstance().then((prefs) => prefs.setString('active_user_id', user.uid));
          return CloudPhotosPage(
            key: ValueKey(user.uid),
            firebaseUser: user
          );
        }
        // No user session — sign in anonymously so the user goes straight to
        // the gallery (local photos, no cloud) without any login prompt.
        // This also handles the logout case: signOut() → stream null → we
        // immediately re-sign in anonymously → fresh app state, no cloud tokens.
        return FutureBuilder<UserCredential>(
          future: FirebaseAuth.instance.signInAnonymously(),
          builder: (context, anonSnapshot) {
            if (anonSnapshot.hasData) {
              final user = anonSnapshot.data!.user!;
              // Save userId to prefs for background worker access
              SharedPreferences.getInstance().then((prefs) => prefs.setString('active_user_id', user.uid));
              return CloudPhotosPage(
                key: ValueKey(user.uid),
                firebaseUser: user
              );
            }
            // If anonymous sign-in fails (e.g. no network), show a retry screen.
            if (anonSnapshot.hasError) {
              return Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cloud_off, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        const Text("Connection Failed", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(anonSnapshot.error.toString().split(']').last, textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => setState(() {}), // Retry
                          child: const Text("Retry"),
                        )
                      ],
                    ),
                  ),
                ),
              );
            }
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          },
        );
      },
    );
  }
}
// --- FIREBASE: New LoginPage Widget ---
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}
class _LoginPageState extends State<LoginPage> {
  bool _isSigningIn = false;
  bool _isInitializing = true;
  String? _errorMessage;
  // Using the shared global instance instead of a local one
  final GoogleSignIn _googleSignIn = googleSignIn;
  @override
  void initState() {
    super.initState();
    // ✅ Check for existing session on startup
    _silentSignIn();
  }
  Future<void> _silentSignIn() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signInSilently();
      if (googleUser != null) {
        if (mounted) setState(() => _isSigningIn = true);
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        final userCred = await FirebaseAuth.instance.signInWithCredential(credential);
        final user = userCred.user;
        if (user != null) {
          // FIX: Sync Google profile fields to Firebase Auth on silent sign-in.
          // signInWithCredential on a previously linked account may return a user
          // whose displayName/photoURL are already set, but we guard anyway.
          final googleName = googleUser.displayName;
          final googlePhoto = googleUser.photoUrl;
          if (googleName != null && user.displayName != googleName) {
            await user.updateDisplayName(googleName);
            debugPrint("✅ Silent sign-in: Updated displayName to: $googleName");
          }
          if (googlePhoto != null && user.photoURL != googlePhoto) {
            await user.updatePhotoURL(googlePhoto);
            debugPrint("✅ Silent sign-in: Updated photoURL");
          }
          await user.reload();
          final email = (FirebaseAuth.instance.currentUser?.email ?? googleUser.email).trim().toLowerCase();
          final prefs = await SharedPreferences.getInstance();
          final isTester = isInternalTester(email);
          // SECURITY: Only check user-scoped key (is_pro_{uid}), NOT the device-wide
          // 'has_purchased_pro' key which could grant free Pro to a different user
          // logging in on the same device after a legitimate Pro user logged out.
          final hasUserScopedPro = prefs.getBool('is_pro_${user.uid}') ?? false;
          if (isTester || hasUserScopedPro) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .set({'isPro': true}, SetOptions(merge: true))
                .catchError((e) => debugPrint("Error syncing pro on silent login: $e"));
            await prefs.setBool('has_purchased_pro', true); // keep for backward compat
            await prefs.setBool('is_pro_${user.uid}', true);
          }
        }
        // NO manual navigation needed!
        // 👇 THIS CLOSES THE LOGIN PAGE UPON SUCCESS 👇
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context); 
        }
      }
    } catch (e) {
      debugPrint("Google Silent Sign-In failed: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isSigningIn = false;
          _isInitializing = false;
        });
      }
    }
  }
  Future<void> _signInWithGoogle() async {
    setState(() {
      _isSigningIn = true;
      _errorMessage = null;
    });
    try {
      debugPrint("🚀 Starting Google Sign-In flow...");
      // 🕵️  RESET: Force a sign-out before signing in.
      // We wrap this in a try-catch to ensure it doesn't block the main flow.
      try {
        await _googleSignIn.signOut().timeout(const Duration(seconds: 3)); 
      } catch (e) {
        debugPrint("Silent signOut failed (ignoring): $e");
      }
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        debugPrint("User cancelled Google Sign-In.");
        if (mounted) setState(() => _isSigningIn = false);
        return;
      }
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && currentUser.isAnonymous) {
        try {
          await currentUser.linkWithCredential(credential);
          debugPrint("✅ Linked Google Account to Guest Session!");
          FirebaseAnalytics.instance.setUserProperty(name: 'login_status', value: 'registered');
        } on FirebaseAuthException catch (e) {
          if (e.code == 'credential-already-in-use') {
             debugPrint("Credential in use, switching to existing account...");
             await FirebaseAuth.instance.signInWithCredential(credential);
             FirebaseAnalytics.instance.setUserProperty(name: 'login_status', value: 'registered');
          } else {
             rethrow; 
          }
        }
      } else {
        await FirebaseAuth.instance.signInWithCredential(credential);
        FirebaseAnalytics.instance.setUserProperty(name: 'login_status', value: 'registered');
      }
      // FIX: linkWithCredential does NOT copy Google profile fields (displayName, photoURL)
      // to the Firebase Auth user automatically. We must do it manually so the UI
      // shows the real name instead of null / "User".
      final newFirebaseUser = FirebaseAuth.instance.currentUser;
      if (newFirebaseUser != null) {
        final googleName = googleUser.displayName;
        final googlePhoto = googleUser.photoUrl;
        if (googleName != null && newFirebaseUser.displayName != googleName) {
          await newFirebaseUser.updateDisplayName(googleName);
          debugPrint("✅ Updated displayName to: $googleName");
        }
        if (googlePhoto != null && newFirebaseUser.photoURL != googlePhoto) {
          await newFirebaseUser.updatePhotoURL(googlePhoto);
          debugPrint("✅ Updated photoURL");
        }
        // Reload so currentUser reflects the updated profile
        await newFirebaseUser.reload();
      }
      final refreshedUser = FirebaseAuth.instance.currentUser;
      if (refreshedUser != null) {
        final email = (refreshedUser.email ?? googleUser.email).trim().toLowerCase();
        final prefs = await SharedPreferences.getInstance();
        final isTester = isInternalTester(email);
        // SECURITY: Only check user-scoped key, NOT device-wide 'has_purchased_pro'
        final hasUserScopedPro = prefs.getBool('is_pro_${refreshedUser.uid}') ?? false;
        if (isTester || hasUserScopedPro) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(refreshedUser.uid)
              .set({'isPro': true}, SetOptions(merge: true))
              .catchError((e) => debugPrint("Error syncing pro on Google login: $e"));
          await prefs.setBool('has_purchased_pro', true); // keep for backward compat
          await prefs.setBool('is_pro_${refreshedUser.uid}', true);
        }
      }
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context); 
      }
    } on FirebaseAuthException catch (e) {
      debugPrint("🔥 FirebaseAuth Error: ${e.code} - ${e.message}");
      if (mounted) {
        setState(() => _errorMessage = e.message);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Authentication Error: ${e.message}"),
          backgroundColor: Colors.red,
        ));
      }
    } catch (e) {
      debugPrint("😩 Google Sign-In Error: $e");
      String safeMessage = "An error occurred. Please try again.";
      final errorStr = e.toString().toLowerCase();
      // FIX: SignInHubActivity NullPointerException — outdated Google Play Services
      // on older devices (e.g. Nexus 5X). Show actionable message instead of crashing.
      if (errorStr.contains('nullpointer') ||
          errorStr.contains('getclass') ||
          errorStr.contains('signinhubactivity')) {
        safeMessage = "Sign-In failed. Please update Google Play Services and try again.";
      } else if (errorStr.contains("network_error")) {
        safeMessage = "Network error. Please check your internet connection.";
      } else if (errorStr.contains("12501") || errorStr.contains("sign_in_canceled")) {
        safeMessage = "Login cancelled.";
      } else if (errorStr.contains("12500")) {
        safeMessage = "Google Play Services error. Please update your phone.";
      } else if (errorStr.contains("access_denied")) {
        safeMessage = "Access denied by user.";
      } else {
        safeMessage = e.toString().contains(']') ? e.toString().split(']').last : e.toString();
      }
      if (mounted) {
        setState(() => _errorMessage = safeMessage);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(safeMessage),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSigningIn = false);
    }
  }
  Future<void> _openPrivacyPolicy() async {
    final Uri url = Uri.parse('https://kar701-dot.github.io/UnifiedGallery/privacy.html');
    if (!await launchUrl(url)) {
      debugPrint('Could not launch privacy policy');
    }
  }
  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      backgroundColor: Colors.white,
      // 🛑 FIX 1: This stops the screen from jumping/shifting when dialogs open
      resizeToAvoidBottomInset: false, 
      body: SafeArea(
        child: SizedBox(
          // 🛑 FIX 2: Forces the column to take full width, preventing left/right shifts
          width: double.infinity, 
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center, // Ensure center alignment
              children: [
                const Spacer(flex: 2),
                // 🎨 FIX 3: YOUR REAL APP ICON
                Container(
                  width: 120, // Slightly larger for better branding
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.transparent, 
                    borderRadius: BorderRadius.circular(24), // Rounded corners like the icon
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  // ClipRRect rounds the corners of your image
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset(
                      'assets/images/app_icon.png', // ✅ Uses your new logo
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // WELCOME TEXT
                const Text(
                  "Unified Gallery",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Text(
                    "All your photos, from every cloud,\nin one simple place.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                const Spacer(flex: 2),
                // ACTION BUTTON
                if (_isSigningIn)
                  const CircularProgressIndicator()
                else
                 // 3. ACTION BUTTON (Fixed Height to prevent jumping)
                SizedBox(
                  width: double.infinity,
                  height: 56, // ✅ Locks the height
                  child: _isSigningIn
                      ? const Center(
                          child: SizedBox(
                            height: 24, 
                            width: 24, 
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                        )
                      : ElevatedButton(
                          onPressed: _signInWithGoogle,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.login_rounded, size: 20),
                              SizedBox(width: 12),
                              Text(
                                "Continue with Google",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
                // Error Message
                if (_errorMessage != null) ...[
                  const SizedBox(height: 20),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 24),
                // FOOTER
                GestureDetector(
                  onTap: _openPrivacyPolicy,
                  child: Text(
                    "Privacy Policy • Secure Login",
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
// --- Helper for Bug 1: Set equality check to avoid unnecessary rebuilds ---
class _SetEquality {
  static bool equals(Set<String> a, Set<String> b) {
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }
}
// --- Main App Page ---
class CloudPhotosPage extends StatefulWidget {
  final User firebaseUser;
  const CloudPhotosPage({super.key, required this.firebaseUser});
  @override
  _CloudPhotosPageState createState() => _CloudPhotosPageState();
}
class _CloudPhotosPageState extends State<CloudPhotosPage> with WidgetsBindingObserver {
  static FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  // Cloud provider auth tokens
  String? _oneDriveAccessToken,
      _oneDriveRefreshToken,
      _dropboxAccessToken,
      _dropboxRefreshToken,
      _boxAccessToken, // ✅ ADDED
      _boxRefreshToken, // ✅ ADDED
      _pCloudAccessToken, // ✅ ADDED
      _megaSessionId; // ✅ MEGA: Session ID token
  // App state
  List<DriveItem> _driveItems = [];
  bool _isLoading = true;
  String _statusMessage = 'Please connect an account from the side menu.';
  String? _dropboxCursor;
  bool _hasMoreDropbox = true;
  bool _hasGoogleDriveAccess = false;
  // Local storage pagination
  int _localPage = 0;          // Now an OFFSET (0, 100, 200…) not a page index
  int _localTotalCount = 0;    // Total asset count cached for _hasMoreLocal check
  bool _hasMoreLocal = true;
  bool _isLoadingMore = false;  // Guard: prevents concurrent load-more fetches
  static const int _localPageSize = 200;
  AssetPathEntity? _localRecentPath;
  // Debounce timer for _onAssetsChanged (prevents scroll resets from thumbnail events)
  Timer? _assetsChangedDebounce;
  Timer? _filterDebounce; // PERF: debounce guard for _updateFilteredItems
   // --- NEW STATE: Locking for token refresh ---
  bool _isOneDriveRefreshing = false;
  bool _isDropboxRefreshing = false;
  bool _isBoxRefreshing = false; // FIX Bug 4: separate lock, was incorrectly sharing _isDropboxRefreshing
  bool _isGoogleDriveAuthInProgress = false;
  // Error handling state
  bool _oneDriveError = false;
  bool _dropboxError = false;
  bool _boxError = false; // ✅ ADDED
  bool _pCloudError = false; // ✅ ADDED
  StreamSubscription<Uri>? _pCloudAuthSub; // tracks the active pCloud OAuth listener
  bool _megaError = false; // ✅ MEGA ADDED
  // Firestore state
  Set<String> _favorites = {};
  Set<String> _bin = {};
  Map<String, List<String>> _albums = {};
  Map<String, String> _albumCovers = {};
  bool _isPro = false;
  bool _isFirestoreLoading = true;
 bool? _hasGivenConsent; // null = loading, false = no, true = yes
  late DocumentReference _userDocRef;
  StreamSubscription? _userDocSubscription;
  // Search/Filter state
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  FilterSource _currentSourceFilter = FilterSource.all;
  FilterType _currentTypeFilter = FilterType.all;
  List<DriveItem> _filteredDriveItems = [];
  bool _isSearching = false;
  // --- NEW STATE: Sorting ---
 SortOption _currentSortOption = SortOption.newestFirst;
// ✅ ADD THIS LINE
// Instance moved to global scope
  // Caching preference
  bool _useCaching = true;
  // --- Bin Behavior ---
  /// When true, "Delete Permanently" also removes the file from the cloud provider.
  /// When false, it only removes the item from this app's view (stays on cloud).
  bool _binDeleteFromCloud = false;
  // --- Files Tab ---
  int _selectedTab = 0; // 0 = Photos, 1 = Files
  // Bug Fix 6: GlobalKey to call search on the Files page state
  final GlobalKey<_UnifiedDocsPageState> _filesPageKey = GlobalKey<_UnifiedDocsPageState>();
  final TextEditingController _filesSearchController = TextEditingController();
  bool _isFilesSearching = false;
  // --- Desktop App Banner ---
  bool _isDesktopBannerDismissed = false;
  // --- MULTI-SELECT: State variables ---
  bool _isSelecting = false;
  Set<String> _selectedItemKeys = {};
  // --- Batch action loading states ---
  bool _isBatchSharing = false;
  bool _isBatchDownloading = false;
  // --- IAP State Variables ---
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _iapSubscription;
  List<ProductDetails> _products = []; // Holds the details of our Pro subscription
  bool _isIapAvailable = false;
  bool _isIapLoading = true; // Track loading state for products
  String? _iapError;
  bool _isPurchasePending = false; // Track if a purchase is in progress
  // FIX: Guard flag so IAP restore safety-net fires only once per session
  // (prevents repeated restorePurchases() calls on every Firestore update)
  bool _iapRestoredOnce = false;
  // ✅ ADD THIS LINE for AI Search
  bool _isAiSearching = false;
  // --- Background scan lifecycle tracking ---
  bool _bgScanScheduled = false;
  // Debounce guard: timestamp of last AI scan start (prevents OOM from rapid re-init)
  DateTime? _lastAiScanStartTime;
  // --- IAP Product ID ---
  // IMPORTANT: This MUST match the Product ID you created in Google Play Console!
  static const String _kProSubscriptionId = 'pro_lifetime';
  static const String _kProMonthlyId = 'premium_monthly_v1';
  static const Set<String> _kProductIds = {_kProSubscriptionId, _kProMonthlyId};
  PackageInfo _packageInfo = PackageInfo(
    appName: 'Cloud Photos',
    packageName: 'Unknown',
    version: '...',
    buildNumber: '...',
  );
  Future<void> _startBackgroundAiScan() async {
    analytics.logEvent(name: 'scan_ai_start');
    if (ForegroundScanner().isScanning.value) return; // Don't run multiple scans
    // Debounce: prevent rapid back-to-back ML Kit re-inits that cause OOM.
    // Each ML Kit init allocates ~30-50MB native. Multiple provider logins in
    // quick succession would stack these allocations until the OS kills the process.
    final now = DateTime.now();
    if (_lastAiScanStartTime != null &&
        now.difference(_lastAiScanStartTime!).inSeconds < 30) {
      debugPrint('🤖 [AI Scan] Debounced — last scan started ${now.difference(_lastAiScanStartTime!).inSeconds}s ago, skipping.');
      return;
    }
    _lastAiScanStartTime = now;
    debugPrint("🤖 Starting AI rescan...");
    final userId = widget.firebaseUser.uid;
    ForegroundScanner().startScan(userId, assetRepository);
  }
Future<List<String>> _fetchAndSaveTags(DriveItem item) async {
  final userId = widget.firebaseUser.uid;
  final uniqueKey = '$userId::${item.getUniqueKey()}';
  // Fix: If tags are already in memory (e.g. loaded from cache), sync the DB
  // status to 'done' so this item is not re-queued on the next app start.
  if (item.aiTags != null) {
    await assetRepository.setAiScanStatus(uniqueKey, AiScanStatus.done, tags: item.aiTags);
    return item.aiTags!;
  }
  // Mark status as scanning in database
  await assetRepository.setAiScanStatus(uniqueKey, AiScanStatus.scanning);
  File? tempFile;
  try {
    // 1. Get thumbnail URL
    final imageUrl = await _getThumbnailUrl(item);
    if (imageUrl == null) throw Exception('Could not get thumbnail URL');
    // 2. Download/resolve image bytes
    if (item.source == PhotoSource.local) {
      final entity = item.localAsset ?? await AssetEntity.fromId(item.id);
      final file = await entity?.file;
      if (file == null) throw Exception('Could not resolve local file for tagging');
      tempFile = file;
    } else if (imageUrl.startsWith('data:image')) {
      tempFile = File('${(await getTemporaryDirectory()).path}/${item.getUniqueKey()}.jpg');
      await tempFile.writeAsBytes(base64Decode(imageUrl.split(',').last));
    } else {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) throw Exception('Download failed');
      tempFile = File('${(await getTemporaryDirectory()).path}/${item.getUniqueKey()}.jpg');
      await tempFile.writeAsBytes(response.bodyBytes);
    }
    // 3a. Run ML Kit Image Labeler
    // Threshold 0.5: captures specific labels like 'Laptop', 'Dog', 'Cat'
    // that were being cut at the old 0.6 threshold.
    final ImageLabeler labeler = ImageLabeler(
      options: ImageLabelerOptions(confidenceThreshold: 0.5),
    );
    final InputImage inputImage = InputImage.fromFile(tempFile);
    final List<ImageLabel> labels = await labeler.processImage(inputImage);
    await labeler.close();
    final tags = labels.map((e) => e.label).toList();
    // 3b. Run ML Kit Object Detector (Phase 1 — on-device, free)
    // Detects specific physical objects with bounding boxes and more precise
    // labels than the Image Labeler (e.g. 'Laptop computer' vs 'Computer').
    List<String>? detectedObjects;
    try {
      final objectDetector = ObjectDetector(
        options: ObjectDetectorOptions(
          mode: DetectionMode.single,
          classifyObjects: true,
          multipleObjects: true,
        ),
      );
      final List<DetectedObject> objects =
          await objectDetector.processImage(inputImage);
      await objectDetector.close();
      final objLabels = objects
          .expand((o) => o.labels)
          .map((l) => l.text)
          .where((t) => t.isNotEmpty)
          .toSet()
          .toList();
      if (objLabels.isNotEmpty) detectedObjects = objLabels;
      debugPrint('🔑 Object detection: $objLabels for ${item.name}');
    } catch (e) {
      debugPrint('⚠️ Object detection failed for ${item.name}: $e');
    }
    // 3c. Run ML Kit Text Recognition / OCR (Phase 1 — on-device, free)
    // Extracts visible text from screenshots, receipts, documents, signs.
    // Stored so users can search photos by text inside them.
    String? recognizedText;
    try {
      final textRecognizer =
          TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText result =
          await textRecognizer.processImage(inputImage);
      await textRecognizer.close();
      if (result.text.trim().isNotEmpty) {
        recognizedText = result.text.trim();
        debugPrint(
            'ðŸ“ OCR found ${result.blocks.length} text blocks in ${item.name}');
      }
    } catch (e) {
      debugPrint('⚠️ OCR failed for ${item.name}: $e');
    }
    // 4. Save to AssetRecord in database
    var record = await assetRepository.findByKey(uniqueKey);
    if (record == null) {
      record = AssetRepository.fromFields(
        userId: userId,
        uniqueKey: uniqueKey,
        cloudFileId: item.id,
        source: item.source.index,
        name: item.name,
        size: item.size,
        isVideo: item.isVideo,
        isFolder: item.isFolder,
        createdAt: item.created,
      );
      await assetRepository.upsert(record);
    }
    await assetRepository.setAiScanStatus(
      uniqueKey,
      AiScanStatus.done,
      tags: tags,
      recognizedText: recognizedText,
      detectedObjects: detectedObjects,
    );
    // 5. Update in memory
    item.aiTags = tags;
    return tags;
  } catch (e) {
    debugPrint("❌ AI Tagging Worker failed for ${item.name}: $e");
    await assetRepository.setAiScanStatus(uniqueKey, AiScanStatus.failed);
    return [];
  } finally {
    if (tempFile != null && item.source != PhotoSource.local) {
      try {
        tempFile.delete();
      } catch (e) {
        // ignore
      }
    }
  }
}
Future<void> _attachTagsToDriveItems() async {
  debugPrint("Attaching existing AI tags from database...");
  try {
    final userId = widget.firebaseUser.uid;
    final allRecords = await assetRepository.findAll(userId);
    // Create a fast lookup map mapping standard item key format to tags
    final tagMap = {
      for (var record in allRecords)
        if (record.aiTags != null)
          record.uniqueKey.replaceFirst('$userId::', ''): record.aiTags!
    };
    if (tagMap.isEmpty) {
      debugPrint("No tags found in database.");
      return;
    }
    for (final item in _driveItems) {
      item.aiTags = tagMap[item.getUniqueKey()];
    }
    debugPrint("Successfully attached tags to in-memory items.");
  } catch (e) {
    debugPrint("Error attaching tags: $e");
  }
}
// ===== INSTANT LOAD CACHE (DriveItem list) =====
  Future<void> _saveItemsToLocalCache() async {
    if (!_useCaching) return;
    try {
      final userId = widget.firebaseUser.uid;
      // FIX 3: Read existing records from DB first so we can preserve
      // AI scan results (status, tags, pHash) that were already computed
      // but may not be loaded into memory yet.
      final existingRecords = await assetRepository.findAll(userId);
      final existingMap = {for (var r in existingRecords) r.uniqueKey: r};
      final List<AssetRecord> records = _driveItems.map((item) {
        final uniqueKey = '$userId::${item.getUniqueKey()}';
        final existing = existingMap[uniqueKey];
        final record = AssetRepository.fromFields(
          userId: userId,
          uniqueKey: uniqueKey,
          cloudFileId: item.id,
          source: item.source.index,
          name: item.name,
          size: item.size,
          isVideo: item.isVideo,
          isFolder: item.isFolder,
          createdAt: item.created,
        );
        // Always update URL/thumbnail cache from in-memory item
        record.downloadUrlCached = item.downloadUrl;
        record.thumbnailLocalPath = item.thumbnailUrl;
        // --- AI scan fields: prefer in-memory data, fall back to DB ---
        if (item.aiTags != null) {
          // In-memory has fresh tags (just scanned this session)
          record.aiTags = item.aiTags;
          record.aiScanStatus = AiScanStatus.done;
        } else if (existing != null && existing.aiScanStatus == AiScanStatus.done) {
          // DB has completed scan — preserve it so we don't re-queue this item
          record.aiTags = existing.aiTags;
          record.aiScanStatus = AiScanStatus.done;
        } else if (existing != null && existing.aiScanStatus == AiScanStatus.failed) {
          // Preserve failed status (don't reset to pending, avoids infinite re-retry)
          record.aiScanStatus = AiScanStatus.failed;
        } else if (existing != null && existing.aiScanStatus == AiScanStatus.scanning) {
          // App was force-killed mid-scan — reset to pending so it retries cleanly
          // (Don't leave it stuck at 'scanning' forever)
          record.aiScanStatus = AiScanStatus.pending;
        } else if (existing != null && existing.aiScanStatus == AiScanStatus.skipped) {
          // Intentionally skipped (video, folder, unsupported type) — don't re-queue
          record.aiScanStatus = AiScanStatus.skipped;
        }
        // Otherwise: no existing record or status=pending → stays pending (default from fromFields)
        // --- pHash: prefer in-memory, fall back to DB ---
        if (item.pHash != null) {
          record.pHashHex = item.pHash!.toRadixString(16);
          record.pHashComputedAt = DateTime.now();
        } else if (existing?.pHashHex != null) {
          record.pHashHex = existing!.pHashHex;
          record.pHashComputedAt = existing.pHashComputedAt;
        }
        // --- Content hash: prefer in-memory, fall back to DB ---
        if (item.contentHash != null) {
          record.contentHash = item.contentHash;
        } else if (existing?.contentHash != null) {
          record.contentHash = existing!.contentHash;
        }
        return record;
      }).toList();
      await assetRepository.upsertAll(records);
      debugPrint("ðŸ“¦ Saved ${_driveItems.length} items to Isar local cache.");
    } catch (e) {
      debugPrint("❌ Error saving local cache to Isar: $e");
    }
  }
  Future<void> _loadItemsFromLocalCache() async {
    if (!_useCaching) return;
    try {
      final userId = widget.firebaseUser.uid;
      final records = await assetRepository.findAll(userId);
      if (records.isEmpty) {
        // Fallback/Migrate SharedPreferences cache if present
        final prefs = await SharedPreferences.getInstance();
        final jsonString = prefs.getString(_userKey('cached_drive_items_list'));
        if (jsonString != null) {
          final List decoded = jsonDecode(jsonString);
          final items = decoded.map((e) => DriveItem.fromJson(e)).toList();
          if (items.isNotEmpty) {
            debugPrint("ðŸ“¦ Migrating SharedPreferences cache to Isar...");
            _driveItems = items;
            await _saveItemsToLocalCache();
            if (!mounted) return;
            setState(() {
              _isLoading = false;
              _statusMessage = "";
            });
            _updateFilteredItems();
            return;
          }
        }
        return;
      }
      final List<DriveItem> items = records.map((record) {
        final item = DriveItem(
          id: record.cloudFileId,
          name: record.name,
          source: PhotoSource.values[record.source],
          downloadUrl: record.downloadUrlCached,
          created: record.createdAt,
          thumbnailUrl: record.thumbnailLocalPath,
          isVideo: record.isVideo,
          isFolder: record.isFolder,
          aiTags: record.aiTags,
          size: record.size,
          contentHash: record.contentHash,
        );
        if (record.pHashHex != null) {
          item.pHash = BigInt.parse(record.pHashHex!, radix: 16);
        }
        return item;
      }).toList();
      if (!mounted) return;
      setState(() {
        _driveItems = items;
        _isLoading = false;
        _statusMessage = "";
      });
      _updateFilteredItems();
      debugPrint("🚀 Loaded ${items.length} items from Isar local cache.");
    } catch (e) {
      debugPrint("❌ Error loading local cache from Isar: $e");
    }
  }
  Future<void> _migrateAiTagsToAssetRecords() async {
    try {
      final aiTags = await isar.aITags.where().findAll();
      if (aiTags.isEmpty) {
        debugPrint("ðŸ“¦ No legacy AITags to migrate.");
        return;
      }
      final userId = widget.firebaseUser.uid;
      debugPrint("ðŸ“¦ Found ${aiTags.length} legacy AITags. Migrating to AssetRecords...");
      final List<AssetRecord> recordsToUpsert = [];
      for (final tagEntry in aiTags) {
        final key = tagEntry.itemKey;
        if (key == null) continue;
        final uniqueKey = '$userId::$key';
        var record = await assetRepository.findByKey(uniqueKey);
        if (record == null) {
          final parts = key.split('::');
          if (parts.length < 2) continue;
          final sourceStr = parts[0];
          final id = parts.sublist(1).join('::');
          int sourceIdx = 6; // default local
          if (sourceStr == 'oneDrive') sourceIdx = 0;
          else if (sourceStr == 'dropbox') sourceIdx = 1;
          else if (sourceStr == 'googleDrive') sourceIdx = 2;
          else if (sourceStr == 'box') sourceIdx = 3;
          else if (sourceStr == 'pCloud') sourceIdx = 4;
          else if (sourceStr == 'mega') sourceIdx = 5;
          record = AssetRepository.fromFields(
            userId: userId,
            uniqueKey: uniqueKey,
            cloudFileId: id,
            source: sourceIdx,
            name: 'Migrated Asset',
          );
        }
        record.aiTags = tagEntry.tags;
        record.aiScanStatus = AiScanStatus.done;
        recordsToUpsert.add(record);
      }
      if (recordsToUpsert.isNotEmpty) {
        await assetRepository.upsertAll(recordsToUpsert);
        debugPrint("✅ Successfully migrated ${recordsToUpsert.length} AITags to AssetRecords.");
        await isar.writeTxn(() async {
          await isar.aITags.clear();
        });
        debugPrint("🗑️ Cleared legacy AITags table.");
      }
    } catch (e) {
      debugPrint("❌ Error migrating AITags: $e");
    }
  }
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // For background scan lifecycle
    // Store userId in SharedPreferences so the background WorkManager task
    // can identify which user's photos to process (no access to Firebase in BG)
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(kPrefUserId, widget.firebaseUser.uid);
      // Register periodic background scan immediately at login.
      // Runs every 15 mins (minimum WorkManager window) whenever battery is not low.
      Workmanager().registerPeriodicTask(
        kBackgroundScanTaskId,
        kBackgroundScanTaskName,
        frequency: const Duration(minutes: 15),
        existingWorkPolicy: ExistingWorkPolicy.update, // FIX: workmanager 0.6.0 uses ExistingWorkPolicy (not ExistingPeriodicWorkPolicy)
        constraints: Constraints(
          networkType: NetworkType.notRequired,
          requiresBatteryNotLow: true,
        ),
      );
      // Also register the daily "On This Day" memories notification
      Workmanager().registerPeriodicTask(
        kMemoriesTaskId,
        kMemoriesTaskName,
        frequency: const Duration(hours: 24),
        initialDelay: _initialDelayUntil9AM(),
        existingWorkPolicy: ExistingWorkPolicy.keep, // FIX: workmanager 0.6.0 uses ExistingWorkPolicy (not ExistingPeriodicWorkPolicy)
        constraints: Constraints(
          networkType: NetworkType.notRequired,
        ),
      );
      _bgScanScheduled = true;
      debugPrint('[initState] WorkManager background scan registered for uid: ${widget.firebaseUser.uid}');
    });
    // Wire up notification tap to navigate to Duplicates page
    NotificationService.onNotificationTap = _handleNotificationTap;
    _userDocRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.firebaseUser.uid);
    // Pre-check tester status and local cache for instant Pro unlock
    if (isInternalTester(widget.firebaseUser.email)) {
      _isPro = true;
      _userDocRef.set({'isPro': true}, SetOptions(merge: true)).catchError((e) {});
      SharedPreferences.getInstance().then((prefs) {
        prefs.setBool('has_purchased_pro', true);
        prefs.setBool('is_pro_${widget.firebaseUser.uid}', true);
      });
    }
    // NOTE: Pro status for non-testers is now loaded in _initializeApp() below,
    // where SharedPreferences is already awaited. This avoids the race condition
    // where _isPro was still false when the user tapped Dropbox immediately after launch.
    // Initialize IAP
    final Stream<List<PurchaseDetails>> purchaseUpdated =
        _inAppPurchase.purchaseStream;
    _iapSubscription = purchaseUpdated.listen((purchaseDetailsList) {
      _handlePurchaseUpdates(purchaseDetailsList);
    }, onDone: () {
      _iapSubscription.cancel();
    }, onError: (error) {
      debugPrint("IAP Stream Error: $error");
    });
    _initIAP();
    _setupFirestoreListener();
    _initPackageInfo();
    _searchController.addListener(() {
      if (_searchQuery != _searchController.text) {
        setState(() => _searchQuery = _searchController.text);
        _updateFilteredItems();
      }
    });
    // ✅ NEW: Call the strict startup sequence
    _initializeApp();
  }
  // NEW: Dedicated startup function to enforce order
    Future<void> _initializeApp() async {
    // 1. Load Preference and Isar cache first in parallel for instant UI loading
    await _loadCachingPreference();
    final results = await Future.wait([
      _loadItemsFromLocalCache(),
      SharedPreferences.getInstance(),
    ]);
    final prefs = results[1] as SharedPreferences;
    final dismissed = prefs.getBool('desktop_banner_dismissed') ?? false;

    // FIX Bug 1: Await Pro status check here, before any cloud login or UI render.
    // Previously this was done with .then() in initState — a race condition that
    // caused _isPro to still be false when the user tapped Dropbox immediately.
    if (!_isPro && !isInternalTester(widget.firebaseUser.email)) {
      // SECURITY: Only read user-scoped key. 'has_purchased_pro' is device-wide
      // and could falsely grant Pro to a different user on the same device.
      final hasPro = prefs.getBool('is_pro_${widget.firebaseUser.uid}') ?? false;
      if (hasPro && mounted) {
        setState(() => _isPro = true);
        _userDocRef.set({'isPro': true}, SetOptions(merge: true)).catchError((e) {});
        debugPrint('[initializeApp] ✅ Pro status restored from user-scoped local cache.');
      }
    }

    if (mounted) {
      setState(() {
        _isDesktopBannerDismissed = dismissed;
      });
    }
    // 2. Perform permission requests, auto login, and syncing in the background asynchronously
    _requestLocalPhotoPermission().then((_) {
      _tryAutoLogin();
      _checkGoogleDriveAccess(fetch: true);
    });
    _migrateAiTagsToAssetRecords();
    _setupNotifications();
  }
  /// Requests local photo/video permission once at startup.
  /// Doing this upfront prevents the OS dialog from appearing mid-load
  /// and avoids the _onAssetsChanged → pagination-reset race condition.
  Future<void> _requestLocalPhotoPermission() async {
    try {
      final PermissionState ps = await PhotoManager.requestPermissionExtend();
      if (!ps.isAuth && !ps.hasAccess) {
        debugPrint('⚠️ Local photo permission denied or limited: $ps');
      } else {
        debugPrint('✅ Local photo permission granted: $ps');
      }
    } catch (e) {
      debugPrint('❌ Error requesting local photo permission: $e');
    }
  }
  Future<void> _setupNotifications() async {
    // Request permission from the user
    await NotificationService.requestPermissions();
    // Retrieve device token and update Firestore document
    final String? token = await NotificationService.getFCMToken();
    if (token != null) {
      try {
        await _userDocRef.set({
          'fcmToken': token,
        }, SetOptions(merge: true));
        debugPrint("🔑 FCM Token saved to Firestore successfully.");
      } catch (e) {
        debugPrint("❌ Error saving FCM token to Firestore: $e");
      }
    }
  }
  // ✅ NEW METHOD: Checks prefs and shows dialog
 // ✅ REPLACEMENT METHOD: Checks user-specific preference
   // --- PASTE THIS NEW HELPER METHOD HERE ---
  Future<void> _initPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _packageInfo = info;
      });
    }
  }
  // --- NEW METHOD: Initialize IAP and Load Products ---
  Future<void> _initIAP() async {
    setState(() {
      _isIapLoading = true;
      _iapError = null;
    });

    // Check tester status immediately
    if (isInternalTester(widget.firebaseUser.email)) {
      if (!_isPro && mounted) setState(() => _isPro = true);
      _userDocRef.set({'isPro': true}, SetOptions(merge: true)).catchError((e) {});
      SharedPreferences.getInstance().then((prefs) {
        prefs.setBool('has_purchased_pro', true);
        prefs.setBool('is_pro_${widget.firebaseUser.uid}', true);
      });
    }

    final bool available = await _inAppPurchase.isAvailable();
    if (!mounted) return;
    if (!available) {
      setState(() {
        _isIapAvailable = false;
        _isIapLoading = false;
        _iapError = 'Billing service is unavailable on this device.';
      });
      return;
    }

    // Always attempt past purchases & restore so existing Pro users are restored
    // even if product detail queries are delayed or unavailable.
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final InAppPurchaseAndroidPlatformAddition androidAddition =
            _inAppPurchase.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
        final QueryPurchaseDetailsResponse? pastPurchases = await androidAddition.queryPastPurchases();
        if (pastPurchases != null && pastPurchases.pastPurchases.isNotEmpty) {
          await _handlePurchaseUpdates(pastPurchases.pastPurchases);
        }
      }
      await _inAppPurchase.restorePurchases();
      debugPrint("IAP: restorePurchases() called on init to detect existing Pro users.");
    } catch (e) {
      debugPrint("IAP restore on init error (non-fatal): $e");
    }

    try {
      final ProductDetailsResponse productDetailResponse =
          await _inAppPurchase.queryProductDetails(_kProductIds);
      if (!mounted) return;
      if (productDetailResponse.error != null) {
        setState(() {
          _iapError = 'Error loading products: ${productDetailResponse.error!.message}';
          _products = [];
          _isIapLoading = false;
          _isIapAvailable = true;
        });
        debugPrint("IAP product query error: ${productDetailResponse.error!.message}");
        return;
      }
      if (productDetailResponse.productDetails.isEmpty) {
        setState(() {
          _iapError = 'Pro subscription product "$_kProSubscriptionId" not found. Please check Play Store setup.';
          _products = [];
          _isIapLoading = false;
          _isIapAvailable = true;
        });
        debugPrint("IAP Error: Product '$_kProSubscriptionId' not found in Play Store response.");
        return;
      }
      setState(() {
        _products = productDetailResponse.productDetails;
        _isIapAvailable = true;
        _isIapLoading = false;
        _iapError = null;
      });
      debugPrint("IAP Initialized. Products loaded: ${_products.map((p) => p.id).toList()}");
    } catch (e) {
      if (mounted) {
        setState(() {
          _iapError = 'An unexpected error occurred initializing IAP: $e';
          _products = [];
          _isIapLoading = false;
        });
        debugPrint("Unexpected IAP Init Error: $e");
      }
    }
  }
  // --- FIXED: ADDED MISSING FIRESTORE LISTENER ---
  void _setupFirestoreListener() {
    setState(() {
      _isFirestoreLoading = true;
      _hasGivenConsent = null; // Set to loading
    });
    _userDocSubscription = _userDocRef.snapshots().listen((snapshot) async {
      if (!mounted) return;

      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      final bool isTester = isInternalTester(widget.firebaseUser.email);
      // SECURITY: hasLocalPro uses ONLY the user-scoped key (is_pro_{uid}).
      // 'has_purchased_pro' is device-wide — trusting it here would grant free Pro
      // to any user logging in on a device where a different user previously bought Pro.
      final bool hasLocalPro = prefs.getBool('is_pro_${widget.firebaseUser.uid}') ?? false;

      if (!snapshot.exists) {
        final bool initialPro = isTester || hasLocalPro || _isPro;
        setState(() {
          _favorites = {};
          _bin = {};
          _albums = {};
          _albumCovers = {};
          // FIX: Never downgrade _isPro — take the MAX of computed and current value
          _isPro = initialPro || _isPro;
          _hasGivenConsent = false;
          _isFirestoreLoading = false;
        });

        final Map<String, dynamic> defaultDoc = {
          'createdAt': FieldValue.serverTimestamp(),
          'lastSeenAt': FieldValue.serverTimestamp(),
          'hasGivenConsent': false,
          'favorites': [],
          'bin': [],
          'albums': {},
          'albumCovers': {},
        };
        if (initialPro) {
          defaultDoc['isPro'] = true;
        }

        _userDocRef.set(defaultDoc, SetOptions(merge: true)).catchError((e) {
          debugPrint("Error setting default user doc: $e");
        });
        return;
      }

      final data = snapshot.data() as Map<String, dynamic>? ?? {};
      final remoteIsPro = data['isPro'] as bool? ?? false;
      final effectiveIsPro = remoteIsPro || isTester || hasLocalPro || _isPro;

      // Self-heal Firestore if user is verified Pro but remote doc is missing/false
      if (effectiveIsPro && !remoteIsPro) {
        _userDocRef.set({'isPro': true}, SetOptions(merge: true)).catchError((e) {
          debugPrint("Error self-healing Pro in Firestore: $e");
        });
      }

      // FIX: If both Firestore AND local storage say isPro=false (can happen after
      // an app update wipes SharedPreferences, or Firestore doc was accidentally reset),
      // trigger an IAP restore as a last-resort safety net. Google Play will return
      // the purchase receipt and _handlePurchaseUpdates will re-grant Pro.
      if (!effectiveIsPro && !isTester && !_iapRestoredOnce) {
        _iapRestoredOnce = true;
        debugPrint('[Pro Recovery] isPro=false from all sources, triggering IAP restore...');
        _inAppPurchase.restorePurchases().catchError((e) {
          debugPrint('[Pro Recovery] IAP restore error: $e');
        });
      }

      // Backfill missing fields for existing users.
      final Map<String, dynamic> migrationData = {};
      if (!data.containsKey('createdAt')) {
        migrationData['createdAt'] = FieldValue.serverTimestamp();
      }
      // SECURITY: Only write isPro if verified Pro — never write isPro: false into Firestore
      if (!data.containsKey('isPro') && effectiveIsPro) migrationData['isPro'] = true;
      if (!data.containsKey('hasGivenConsent')) migrationData['hasGivenConsent'] = false;
      if (!data.containsKey('favorites')) migrationData['favorites'] = [];
      if (!data.containsKey('bin')) migrationData['bin'] = [];
      if (!data.containsKey('albums')) migrationData['albums'] = {};
      if (!data.containsKey('albumCovers')) migrationData['albumCovers'] = {};
      if (migrationData.isNotEmpty) {
        _userDocRef.set(migrationData, SetOptions(merge: true)).catchError((e) {
          debugPrint("Error migrating user doc: $e");
        });
      }

      final favList = data['favorites'] as List<dynamic>? ?? [];
      final newFavorites = favList.map((e) => e.toString()).toSet();
      final binList = data['bin'] as List<dynamic>? ?? [];
      final newBin = binList.map((e) => e.toString()).toSet();
      final albumsMap = data['albums'] as Map<String, dynamic>? ?? {};
      final newAlbums = <String, List<String>>{};
      albumsMap.forEach((key, value) {
        if (value is List<dynamic>) {
          newAlbums[key] = value.map((e) => e.toString()).toList();
        }
      });
      final coversMap = data['albumCovers'] as Map<String, dynamic>? ?? {};
      final newAlbumCovers = <String, String>{};
      coversMap.forEach((key, value) {
        if (value is String) {
          newAlbumCovers[key] = value;
        }
      });
      final newHasGivenConsent = data['hasGivenConsent'] as bool? ?? false;

      final bool newIsPro = effectiveIsPro || _isPro; // the actual value _isPro will be set to
      final bool hasChanged = !_SetEquality.equals(_favorites, newFavorites) ||
          !_SetEquality.equals(_bin, newBin) ||
          _isPro != newIsPro ||
          _hasGivenConsent != newHasGivenConsent ||
          _isFirestoreLoading;
      if (hasChanged) {
        final wasPro = _isPro;
        setState(() {
          _favorites = newFavorites;
          _bin = newBin;
          _albums = newAlbums;
          _albumCovers = newAlbumCovers;
          // FIX: _isPro must NEVER go from true → false via the Firestore listener.
          // effectiveIsPro can be false if Firestore loads before IAP restore completes.
          // We take the MAX — once Pro in this session, stay Pro until explicit sign-out.
          _isPro = newIsPro;
          _hasGivenConsent = newHasGivenConsent;
          _isFirestoreLoading = false;
        });
        if (effectiveIsPro && !wasPro && !_isLoading) {
          _startBackgroundAiScan();
        }
      } else {
        if (_isFirestoreLoading) setState(() => _isFirestoreLoading = false);
      }
    }, onError: (error) {
      debugPrint("Firestore listener error: $error");
      if (mounted) {
        setState(() {
          _isFirestoreLoading = false;
          _hasGivenConsent = false;
          _statusMessage = "Error loading your data.";
        });
      }
    });
  }
 // --- PASTE THIS NEW METHOD ---
  Future<void> _handleConsentGiven() async {
    try {
      // Set the flag in Firestore
      await _userDocRef.update({'hasGivenConsent': true});
      // The listener will automatically see this change and rebuild the UI
    } catch (e) {
      debugPrint("Error saving consent to Firestore: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error saving preference: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }
  // --- NEW METHOD: Handle Purchase Updates ---
  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) async {
    for (var purchaseDetails in purchaseDetailsList) {
      // Handle purchases/restores
      if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        // Basic check for product ID
        if (purchaseDetails.productID == _kProSubscriptionId || purchaseDetails.productID == _kProMonthlyId) {
            // Grant Pro access
           await _verifyAndGrantProAccess(purchaseDetails);
        } else {
           debugPrint("Purchase updated for unexpected product: ${purchaseDetails.productID}");
        }
        // IMPORTANT: Complete the purchase (required on Android, safe on iOS)
        if (purchaseDetails.pendingCompletePurchase) {
          try {
             await _inAppPurchase.completePurchase(purchaseDetails);
             debugPrint("Purchase completed for: ${purchaseDetails.purchaseID}");
          } catch (e) {
             debugPrint("Error completing purchase ${purchaseDetails.purchaseID}: $e");
             // Handle completion error if necessary
          }
        }
         if (mounted) setState(() => _isPurchasePending = false); // Purchase resolved
      }
      // Handle errors
      else if (purchaseDetails.status == PurchaseStatus.error) {
        debugPrint("Purchase Error: ${purchaseDetails.error?.message} (Code: ${purchaseDetails.error?.code})");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Purchase failed: ${purchaseDetails.error?.message ?? 'Unknown error'}'),
            backgroundColor: Colors.red,
          ));
           setState(() => _isPurchasePending = false); // Purchase failed
        }
         // Also complete the purchase to remove it from the queue, even on error
        if (purchaseDetails.pendingCompletePurchase) {
           try {
              await _inAppPurchase.completePurchase(purchaseDetails);
              debugPrint("Purchase (error state) completed for: ${purchaseDetails.purchaseID}");
           } catch (e) {
              debugPrint("Error completing purchase (error state) ${purchaseDetails.purchaseID}: $e");
           }
        }
      }
      // Handle pending state (e.g., requires parental approval, delayed payment method)
      else if (purchaseDetails.status == PurchaseStatus.pending) {
         if (mounted) {
            // Show user info that purchase is pending
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Purchase pending. Awaiting confirmation...'),
                duration: Duration(seconds: 3),
             ));
            setState(() => _isPurchasePending = true); // Indicate purchase is in progress
         }
      }
      // Handle Canceled state
      else if (purchaseDetails.status == PurchaseStatus.canceled) {
         debugPrint("Purchase Canceled for: ${purchaseDetails.productID}");
          if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Purchase canceled.'),
                duration: Duration(seconds: 2),
             ));
            setState(() => _isPurchasePending = false); // Purchase canceled
          }
           // IMPORTANT: Complete the purchase if it was pending and got canceled
           // This might happen if the user backs out of the Play Store UI
           if (purchaseDetails.pendingCompletePurchase) {
              try {
                 await _inAppPurchase.completePurchase(purchaseDetails);
                 debugPrint("Purchase (canceled state) completed for: ${purchaseDetails.purchaseID}");
              } catch (e) {
                 debugPrint("Error completing purchase (canceled state) ${purchaseDetails.purchaseID}: $e");
              }
           }
      }
    }
  }
 // --- PASTE THIS REPLACEMENT METHOD ---
 // ✅ PASTE THIS REPLACEMENT METHOD
 // ✅ REPLACEMENT METHOD: Smart Refresh (Protects tokens from accidental deletion)
  Future<bool> _refreshAccessToken(PhotoSource source) async {
    // Prevent multiple refreshes at the same time
    if (source == PhotoSource.oneDrive && _isOneDriveRefreshing) return false;
    if (source == PhotoSource.dropbox && _isDropboxRefreshing) return false;
    if (source == PhotoSource.box && _isBoxRefreshing) return false; // FIX Bug 4: own lock
    if (mounted) {
      setState(() {
        if (source == PhotoSource.oneDrive) _isOneDriveRefreshing = true;
        if (source == PhotoSource.dropbox) _isDropboxRefreshing = true;
        if (source == PhotoSource.box) _isBoxRefreshing = true; // FIX Bug 4: own lock
      });
    }
    String? key;
    if (source == PhotoSource.oneDrive) key = 'od_refresh_token';
    else if (source == PhotoSource.dropbox) key = 'dbx_refresh_token';
    else if (source == PhotoSource.box) key = 'box_refresh_token';
    if (key == null) return false;
    final String? refreshToken = await secureStorage.read(key: _userKey(key));
    if (refreshToken == null) {
      debugPrint("Refresh failed: No refresh token found for $source");
      _resetRefreshLocks();
      return false;
    }
    try {
      // -------------------------------------------------------
      // 📁¦ BOX REFRESH
      // -------------------------------------------------------
      if (source == PhotoSource.box) {
        final response = await http.post(
          Uri.parse(boxTokenEndpoint),
          body: {
            'grant_type': 'refresh_token',
            'refresh_token': refreshToken,
            'client_id': boxClientId,
            'client_secret': boxClientSecret,
          },
        );
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          // Box rotates refresh tokens! We MUST save the new one.
          final newRefreshToken = data['refresh_token'];
          final result = TokenResponse(
            data['access_token'],
            newRefreshToken, 
            DateTime.now().add(Duration(seconds: data['expires_in'] as int? ?? 3600)),
            null,
            data['token_type'],
            null,
            null
          );
          _onLoginSuccessBox(result); // Saves new token to storage
          if (mounted) setState(() => _isBoxRefreshing = false); // FIX Bug 4
          return true;
        } else {
          // ⚠️ ONLY delete if the token is definitely invalid/revoked
          if (response.statusCode == 400 || response.statusCode == 401) {
             debugPrint("⚠️ Box Token Invalid/Revoked. Deleting.");
             await secureStorage.delete(key: _userKey(key));
          }
          throw Exception('Box refresh failed: ${response.body}');
        }
      }
      // -------------------------------------------------------
      // 🔵 DROPBOX REFRESH
      // -------------------------------------------------------
      else if (source == PhotoSource.dropbox) {
        final response = await http.post(
          Uri.parse(dropboxTokenEndpoint), // FIX Bug 3: was 'api.dropbox.com' (wrong subdomain)
          body: {
            'grant_type': 'refresh_token',
            'refresh_token': refreshToken,
            'client_id': dropboxClientId,
            // Dropbox usually doesn't need client_secret for public apps,
            // and strictly NO redirect_uri here.
          },
        );
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          // Dropbox might rotate the token, or might not.
          final newRefreshToken = data['refresh_token'] ?? refreshToken; 
          final result = TokenResponse(
            data['access_token'],
            newRefreshToken,
            DateTime.now().add(Duration(seconds: data['expires_in'] ?? 14400)),
            null,
            'bearer',
            null,
            null
          );
          _onLoginSuccessDropbox(result);
          if (mounted) setState(() => _isDropboxRefreshing = false);
          debugPrint("✅ Dropbox Refresh Successful");
          return true;
        } else {
           // ⚠️ ONLY delete if the token is definitely invalid/revoked
          if (response.statusCode == 400 || response.statusCode == 401) {
             debugPrint("⚠️ Dropbox Token Invalid/Revoked. Deleting.");
             await secureStorage.delete(key: _userKey(key));
          }
          throw Exception('Dropbox refresh failed: ${response.body}');
        }
      }
      // -------------------------------------------------------
      // ☁️ ONEDRIVE REFRESH
      // -------------------------------------------------------
      else {
        final TokenResponse? result = await appAuth.token(TokenRequest(
          oneDriveClientId,
          redirectUri,
          refreshToken: refreshToken,
          serviceConfiguration: oneDriveServiceConfiguration,
          scopes: oneDriveScope.split(' '),
        ));
        if (result != null) {
          _onLoginSuccessOneDrive(result);
          if (mounted) setState(() => _isOneDriveRefreshing = false);
          return true;
        } else {
          throw Exception('OneDrive token response was null');
        }
      }
    } catch (e) {
      debugPrint('❌Å’ Token refresh for $source FAILED: $e');
      // 🛑 STOP! Do NOT delete the token here. 
      // This catches network errors (offline), timeouts, etc.
      // We want to keep the token so we can try again when internet returns.
      if (mounted) {
        setState(() {
          if (source == PhotoSource.oneDrive) _oneDriveError = true;
          if (source == PhotoSource.dropbox) _dropboxError = true;
          if (source == PhotoSource.box) _boxError = true;
        });
        _resetRefreshLocks();
        _updateFilteredItems();
      }
      return false;
    }
  }
  void _resetRefreshLocks() {
    if (mounted) {
      setState(() {
        _isOneDriveRefreshing = false;
        _isDropboxRefreshing = false;
        _isBoxRefreshing = false; // FIX Bug 4: also reset box lock
      });
    }
  }
  // ======================================================
 // 🚪 Logout and Cleanup for OneDrive
 // ======================================================
 // --- PASTE THIS REPLACEMENT METHOD ---
 Future<void> _logoutOneDrive() async {
  try {
    debugPrint("🚪 Logging out from OneDrive...");
    // --- FIX: Use _userKey and delete the correct token ---
    await secureStorage.delete(key: _userKey('od_refresh_token'));
    // Remove OneDrive photos from gallery
    setState(() {
      _driveItems.removeWhere((item) => item.source == PhotoSource.oneDrive);
      _oneDriveAccessToken = null;
      _oneDriveRefreshToken = null;
      _oneDriveError = false;
    });
    _updateFilteredItems();
    // Show confirmation
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Logged out of OneDrive successfully')),
      );
    }
    debugPrint("✅ OneDrive logout complete.");
  } catch (e) {
    debugPrint("❌Å’ Error during OneDrive logout: $e");
  }
}
// --- PASTE THIS REPLACEMENT METHOD ---
Future<void> _logoutDropbox() async {
  try {
    debugPrint("🚪 Logging out from Dropbox...");
    // --- FIX: Use _userKey and delete the correct token ---
    await secureStorage.delete(key: _userKey('dbx_refresh_token'));
    // Remove Dropbox photos
    setState(() {
      _driveItems.removeWhere((item) => item.source == PhotoSource.dropbox);
      _dropboxAccessToken = null;
      _dropboxRefreshToken = null;
      _dropboxError = false;
    });
    _updateFilteredItems();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Logged out of Dropbox successfully')),
      );
    }
    debugPrint("✅ Dropbox logout complete.");
  } catch (e) {
    debugPrint("❌ Error during Dropbox logout: $e");
  }
}
// --- INTEGRATED PCLOUD LOGIN ---
// 🔑½ INTEGRATED PCLOUD LOGIN (From your working test)
// 🔑½ UPDATED PCLOUD LOGIN (Fixes "Invalid Token" for EU users)
Future<void> _loginToPCloud() async {
  if (widget.firebaseUser.isAnonymous) {
    _showGoogleSignInRequired();
    return;
  }
  final Uri authUri = Uri.https('my.pcloud.com', '/oauth2/authorize', {
    'client_id': pCloudClientId,
    'response_type': 'token',
    'redirect_uri': pCloudRedirectUri,
    'force_relogin': '1',
    // FIX EU routing: tell pCloud to include locationid in the redirect fragment.
    // EU accounts (locationid=2) need to hit eapi.pcloud.com, not api.pcloud.com.
    // my.pcloud.com handles both regions and always returns the correct locationid.
  });
  try {
    debugPrint("🔑 Launching pCloud: $authUri");
    final _appLinks = AppLinks();
    StreamSubscription<Uri>? sub;
    // Cancel any previously-open pCloud subscription to avoid double-listeners
    _pCloudAuthSub?.cancel();
    sub = _appLinks.uriLinkStream.listen((uri) async {
      debugPrint("🔑— Received URI: $uri");
      final bool isCorrectRedirect = uri.scheme == 'com.pranav.onedrivephotos' &&
                               (uri.host == 'oauth2redirect' || uri.path.contains('oauth2redirect'));
      if (isCorrectRedirect) {
        // ✅ Cancel immediately — don't keep listening after we got the redirect
        sub?.cancel();
        _pCloudAuthSub = null;
        final fragment = uri.fragment;
        final params = Uri.splitQueryString(fragment.isNotEmpty ? fragment : uri.query);
        final token = params['access_token'] ?? params['token'];
        String? locationId = params['locationid'];
        final hostname = (params['hostname'] ?? '').toString();
        if (locationId == null && hostname.isNotEmpty) {
          locationId = hostname.contains('eapi') ? '2' : '1';
        }
        if (token != null) {
          analytics.logLogin(loginMethod: 'pcloud');
          debugPrint("✅ pCloud Token Received. Location ID: $locationId");
          await secureStorage.write(key: _userKey('pcloud_access_token'), value: token);
          // FIX: If locationid missing from redirect, probe BOTH servers to find region.
          // EU tokens are rejected by api.pcloud.com so we must try eapi.pcloud.com too.
          String effectiveLocationId = locationId ?? '1';
          if (locationId == null) {
            debugPrint('[pCloud] ⚠️ locationid missing from redirect — probing region...');
            try {
              // Try US first
              final respUS = await http.get(Uri.https('api.pcloud.com', '/userinfo',
                {'access_token': token})).timeout(const Duration(seconds: 8));
              final infoUS = json.decode(respUS.body);
              if (infoUS['result'] == 0) {
                final apiServer = (infoUS['apiserver'] ?? '').toString();
                effectiveLocationId = apiServer.contains('eapi') ? '2' : '1';
                debugPrint('[pCloud] US probe success → locationid=$effectiveLocationId');
              } else {
                // US rejected it — must be EU account
                debugPrint('[pCloud] US probe rejected (result=${infoUS['result']}) — trying EU...');
                final respEU = await http.get(Uri.https('eapi.pcloud.com', '/userinfo',
                  {'access_token': token})).timeout(const Duration(seconds: 8));
                final infoEU = json.decode(respEU.body);
                if (infoEU['result'] == 0) {
                  effectiveLocationId = '2';
                  debugPrint('[pCloud] EU probe success → locationid=2');
                }
              }
            } catch (e) {
              debugPrint('[pCloud] Region probe failed, keeping default: $e');
            }
          }
          await secureStorage.write(key: _userKey('pcloud_location_id'), value: effectiveLocationId);
          if (mounted) {
            setState(() {
              _pCloudAccessToken = token;
              _pCloudError = false;
              _statusMessage = "Connected! Syncing photos...";
            });
            await _fetchAllPhotos(firstPage: true);
          }
        }
      }
    });
    _pCloudAuthSub = sub;
    await launchUrl(authUri, mode: LaunchMode.externalApplication);
    // FIX: Extend timeout from 30s to 5 minutes.
    // Users on slow connections or with 2FA may take over 30s in the browser.
    // The subscription self-cancels immediately on success anyway.
    Future.delayed(const Duration(minutes: 5), () {
      sub?.cancel();
      _pCloudAuthSub = null;
    });
  } catch (e) {
    debugPrint("❌Å’ pCloud Login Error: $e");
    if (mounted) {
      setState(() {
        _pCloudError = true;
        _statusMessage = "pCloud Login Failed: $e";
      });
    }
  }
}

/// FIX: Validates a stored pCloud access token by calling /userinfo.
/// Returns true if the token is valid, false if expired or revoked.
/// Also updates the stored locationid if it has changed (handles EU/US region switches).
Future<bool> _validatePCloudToken(String token) async {
  try {
    final storedLoc = await secureStorage.read(key: _userKey('pcloud_location_id'));
    final primaryHost = (storedLoc == '2') ? 'eapi.pcloud.com' : 'api.pcloud.com';
    final fallbackHost = (storedLoc == '2') ? 'api.pcloud.com' : 'eapi.pcloud.com';

    Future<bool?> probe(String host) async {
      try {
        final resp = await http.get(
          Uri.https(host, '/userinfo', {'access_token': token}),
        ).timeout(const Duration(seconds: 10));
        final data = json.decode(resp.body);
        if (data['result'] == 0) {
          final apiServer = (data['apiserver'] ?? '').toString();
          final newLocationId = apiServer.contains('eapi') ? '2' : (data['locationid']?.toString() ?? (host.contains('eapi') ? '2' : '1'));
          await secureStorage.write(
              key: _userKey('pcloud_location_id'), value: newLocationId);
          debugPrint('[pCloud] Validated on $host (locationid=$newLocationId)');
          return true;
        } else if (data['result'] == 1000 || data['result'] == 2094) {
          // Explicit token rejection / revoked
          return false;
        } else if (data['result'] == 2000) {
          // Wrong server region — not an invalid token
          return null;
        }
      } catch (e) {
        debugPrint('[pCloud] Probe $host network error: $e');
      }
      return null; // Network/transient error
    }

    final r1 = await probe(primaryHost);
    if (r1 == true) return true;
    final r2 = await probe(fallbackHost);
    if (r2 == true) return true;

    // Only fail if BOTH hosts explicitly reject authentication (token revoked/invalid)
    if (r1 == false && r2 == false) {
      return false;
    }
    return true; // Assume valid on network errors/timeouts to avoid premature disconnect
  } catch (e) {
    debugPrint('[pCloud] _validatePCloudToken error: $e');
    return true;
  }
}

// ... existing variables ...
  // _pCloudItems removed — pCloud items are merged into _driveItems via _fetchAllPhotos
// ✅ REPLACEMENT METHOD (Fixes "PhotoItem" vs "DriveItem" crash)
 // ✅ REPLACEMENT METHOD: Returns list for _fetchAllPhotos to handle
// ✅ REPLACEMENT METHOD: Fetches BOTH images and videos
Future<List<DriveItem>> _fetchPCloudPhotos() async {
  if (_pCloudAccessToken == null) return [];
  debugPrint("Fetching pCloud photos...");
  try {
    String? locationId = await secureStorage.read(key: _userKey('pcloud_location_id'));
    String primaryHost = (locationId == '2') ? 'eapi.pcloud.com' : 'api.pcloud.com';
    String fallbackHost = (locationId == '2') ? 'api.pcloud.com' : 'eapi.pcloud.com';

    // FIX: Do NOT use recursive=1 — it fetches the entire folder tree as one
    // massive JSON which can take 45-90s for large accounts and gets cancelled
    // when the app goes to background. Instead, list only the root non-recursively
    // (fast ~1-2s), then iterate each top-level folder with individual calls.
    Future<http.Response?> fetchFolder(String host, {int folderId = 0}) async {
      try {
        final listUrl = Uri.https(host, '/listfolder', {
          'folderid': folderId.toString(),
          'recursive': '0', // Non-recursive: only one level at a time → fast!
          'access_token': _pCloudAccessToken,
        });
        return await http.get(listUrl).timeout(const Duration(seconds: 20));
      } catch (e) {
        debugPrint('[pCloud] Failed to fetch folder $folderId on $host: $e');
        return null;
      }
    }

    String activeHost = primaryHost;
    http.Response? response = await fetchFolder(primaryHost, folderId: 0);
    Map<String, dynamic>? data;

    if (response != null && response.statusCode == 200) {
      data = json.decode(response.body);
    }

    // Auto-heal: If result == 2000 (wrong server) or failed, try fallback host.
    if (data == null || data['result'] == 2000) {
      debugPrint('[pCloud] Primary host rejected (result=${data?['result']}), trying fallback: $fallbackHost');
      final fallbackResponse = await fetchFolder(fallbackHost, folderId: 0);
      if (fallbackResponse != null && fallbackResponse.statusCode == 200) {
        final fallbackData = json.decode(fallbackResponse.body);
        if (fallbackData['result'] == 0) {
          activeHost = fallbackHost;
          data = fallbackData;
          final correctLoc = activeHost.contains('eapi') ? '2' : '1';
          await secureStorage.write(key: _userKey('pcloud_location_id'), value: correctLoc);
          debugPrint('[pCloud] ✅ Auto-healed region! Saved location: $correctLoc');
        } else {
          data ??= fallbackData;
        }
      }
    }

    if (data == null) return [];

    if (data['result'] == 0) {
      // Iteratively collect files from root + all top-level subfolders.
      // We skip deep recursion (recursive=1) which causes large JSON payloads
      // and 45-90s response times. Instead we do:
      //   1. List root (folderid=0) → get immediate files + top-level folder IDs
      //   2. List each top-level folder in parallel → cover Automatic Upload, Photos, etc.
      // This completes in ~3-5s total even with many folders.
      final List<dynamic> allRawFiles = [];
      final List<int> topLevelFolderIds = [];

      // Collect root-level files and find subfolders to enumerate
      final rootMetadata = data['metadata'];
      if (rootMetadata != null && rootMetadata['contents'] is List) {
        for (var child in (rootMetadata['contents'] as List)) {
          if (child is! Map) continue;
          final isFolder = child['isfolder'] == true || child['isfolder'] == 1;
          if (isFolder) {
            final fid = child['folderid'];
            if (fid != null) topLevelFolderIds.add(fid is int ? fid : int.tryParse(fid.toString()) ?? 0);
          } else {
            allRawFiles.add(child);
          }
        }
      }

      // Fetch each top-level folder in parallel (covers Automatic Upload, Photos, Videos, etc.)
      if (topLevelFolderIds.isNotEmpty) {
        debugPrint('[pCloud] Listing ${topLevelFolderIds.length} top-level folders in parallel...');
        final folderFutures = topLevelFolderIds.map((fid) async {
          final resp = await fetchFolder(activeHost, folderId: fid);
          if (resp == null || resp.statusCode != 200) return;
          try {
            final fd = json.decode(resp.body);
            if (fd['result'] == 0 && fd['metadata'] != null && fd['metadata']['contents'] is List) {
              for (var child in (fd['metadata']['contents'] as List)) {
                if (child is! Map) continue;
                final isFolder = child['isfolder'] == true || child['isfolder'] == 1;
                if (!isFolder) allRawFiles.add(child);
                // Note: We intentionally skip 2nd-level subfolders to keep it fast.
                // 99% of pCloud photos live in root or one level deep (Automatic Upload).
              }
            }
          } catch (e) {
            debugPrint('[pCloud] Error parsing folder $fid: $e');
          }
        });
        await Future.wait(folderFutures);
      }

      debugPrint('[pCloud] Scanned root + ${topLevelFolderIds.length} top-level folders.');

      // Filter media files only (check contentType AND common file extensions)
      final mediaFiles = allRawFiles.where((file) {
        if (file is! Map) return false;
        final contentType = (file['contenttype'] ?? '').toString().toLowerCase();
        final name = (file['name'] ?? '').toString().toLowerCase();
        final isMediaExt = name.endsWith('.jpg') || name.endsWith('.jpeg') ||
                           name.endsWith('.png') || name.endsWith('.gif') ||
                           name.endsWith('.webp') || name.endsWith('.heic') ||
                           name.endsWith('.heif') || name.endsWith('.dng') ||
                           name.endsWith('.bmp') || name.endsWith('.tiff') ||
                           name.endsWith('.tif') || name.endsWith('.mp4') ||
                           name.endsWith('.mov') || name.endsWith('.m4v') ||
                           name.endsWith('.3gp') || name.endsWith('.mkv') ||
                           name.endsWith('.avi') || name.endsWith('.webm') ||
                           name.endsWith('.wmv') || name.endsWith('.flv') ||
                           name.endsWith('.ts');
        return contentType.startsWith('image/') || contentType.startsWith('video/') || isMediaExt;
      }).toList();

      debugPrint('[pCloud] Found ${mediaFiles.length} media files across all folders.');

      if (mediaFiles.isNotEmpty) {
        Map<String, String> thumbMap = {};
        // Fetch thumbnails in parallel batches of 50 to avoid URL length limits and speed up loading
        final chunkFutures = <Future<void>>[];
        for (var i = 0; i < mediaFiles.length; i += 50) {
          final end = (i + 50 > mediaFiles.length) ? mediaFiles.length : i + 50;
          final chunk = mediaFiles.sublist(i, end);
          // FIX: Exclude videos — pCloud /getthumbslinks only works for image files.
          // Including videos wastes batch slots and returns result≠0 for those file IDs.
          final validChunk = chunk.where((f) {
            if (f['fileid'] == null) return false;
            final ct = (f['contenttype'] ?? '').toString().toLowerCase();
            final nm = (f['name'] ?? '').toString().toLowerCase();
            final isVid = ct.startsWith('video/') || nm.endsWith('.mp4') ||
                nm.endsWith('.mov') || nm.endsWith('.m4v') || nm.endsWith('.3gp') ||
                nm.endsWith('.mkv') || nm.endsWith('.avi') || nm.endsWith('.webm') ||
                nm.endsWith('.wmv') || nm.endsWith('.flv') || nm.endsWith('.ts');
            return !isVid;
          }).toList();
          if (validChunk.isEmpty) continue;
          final fileIds = validChunk.map((f) => f['fileid'].toString()).join(',');
          final thumbsUrl = Uri.https(activeHost, '/getthumbslinks', {
            'fileids': fileIds,
            'size': '500x500',
            'access_token': _pCloudAccessToken
          });
          chunkFutures.add(() async {
            try {
              final thumbsResponse = await http.get(thumbsUrl).timeout(const Duration(seconds: 15));
              final thumbsData = json.decode(thumbsResponse.body);
              if (thumbsData['result'] == 0 && thumbsData['thumbs'] is List) {
                for (var t in thumbsData['thumbs']) {
                  if (t['result'] == 0 && t['hosts'] != null && t['path'] != null) {
                    final hosts = t['hosts'] as List;
                    if (hosts.isNotEmpty) {
                      thumbMap[t['fileid'].toString()] = 'https://${hosts[0]}${t['path']}';
                    }
                  }
                }
              }
            } catch (e) {
              debugPrint('[pCloud] Thumbnail chunk failed (non-fatal): $e');
            }
          }());
        }
        if (chunkFutures.isNotEmpty) {
          await Future.wait(chunkFutures);
        }

        List<DriveItem> newPhotos = [];
        for (var file in mediaFiles) {
          if (file is! Map) continue;
          final name = (file['name'] ?? '').toString();
          final lowerName = name.toLowerCase();
          final contentType = (file['contenttype'] ?? '').toString().toLowerCase();
          final isVideo = contentType.startsWith('video/') ||
                          lowerName.endsWith('.mp4') || lowerName.endsWith('.mov') ||
                          lowerName.endsWith('.m4v') || lowerName.endsWith('.3gp') ||
                          lowerName.endsWith('.mkv') || lowerName.endsWith('.avi') ||
                          lowerName.endsWith('.webm') || lowerName.endsWith('.wmv') ||
                          lowerName.endsWith('.flv') || lowerName.endsWith('.ts');
          final fileId = file['fileid'].toString();
          final createdDate = _parsePCloudDate(file['created']) ?? _parsePCloudDate(file['modified']);
          final rawSize = file['size'];
          final int? size = rawSize is int ? rawSize : int.tryParse(rawSize?.toString() ?? '');
          newPhotos.add(DriveItem(
            id: fileId,
            name: name.isNotEmpty ? name : 'pCloud File',
            thumbnailUrl: thumbMap[fileId],
            downloadUrl: null, // Generated on-demand via _getDownloadUrl -> getfilelink
            source: PhotoSource.pCloud,
            created: createdDate,
            isVideo: isVideo,
            size: size,
          ));
        }
        return newPhotos;
      }
    } else if (data['result'] == 1000 || data['result'] == 2094) {
      debugPrint('❌ pCloud Auth Error (result=${data['result']}): ${data['error']}');
      if (mounted) setState(() => _pCloudError = true);
    } else if (data['result'] == 5000) {
      debugPrint('[pCloud] Server error (result=5000) — will retry on next refresh');
    }
  } catch (e) {
    debugPrint('⚠️ pCloud Fetch Error (keeping connection): $e');
  }
  return [];
}
Future<void> _logoutFromPCloud() async {
  // Cancel any pending OAuth flow before clearing the token
  _pCloudAuthSub?.cancel();
  _pCloudAuthSub = null;
  // ✅ FIX: Use _userKey
  await secureStorage.delete(key: _userKey('pcloud_access_token'));
  await secureStorage.delete(key: _userKey('pcloud_location_id'));
  setState(() {
    _pCloudAccessToken = null;
    _pCloudError = false;
    _driveItems.removeWhere((item) => item.source == PhotoSource.pCloud); // Clear items from UI
  });
  _updateFilteredItems(); // Update UI
  debugPrint("🚪 Logged out from pCloud");
}
// =============================================================================
// --- MEGA CLOUD INTEGRATION ---
// Mega uses a custom JSON-RPC API with client-side AES-128 encryption.
// Authentication flow:
//   1. Derive AES key from password (65536 iterations of AES-128 — prepare_key)
//   2. Compute password hash (stringhash — 16384 AES-ECB rounds)
//   3. POST login command → decrypt master key from 'k' field
//   4. Get session: use 'tsid' directly, or RSA-decrypt 'csid' using 'privk'
//   5. Use session as 'sid' for all subsequent API calls
// =============================================================================
// --- Mega helper: string -> array of big-endian 32-bit ints ---
List<int> _strToA32(String s) {
  final bytes = utf8.encode(s);
  final result = List<int>.filled((bytes.length + 3) ~/ 4, 0);
  for (int i = 0; i < bytes.length; i++) {
    result[i >> 2] |= bytes[i] << (24 - (i & 3) * 8);
  }
  return result;
}
// --- Mega helper: array of 32-bit ints -> bytes (big-endian) ---
Uint8List _a32ToBytes(List<int> a) {
  final out = Uint8List(a.length * 4);
  for (int i = 0; i < a.length; i++) {
    out[i * 4]     = (a[i] >> 24) & 0xFF;
    out[i * 4 + 1] = (a[i] >> 16) & 0xFF;
    out[i * 4 + 2] = (a[i] >> 8)  & 0xFF;
    out[i * 4 + 3] =  a[i]        & 0xFF;
  }
  return out;
}
// --- Mega helper: bytes -> array of 32-bit ints ---
List<int> _bytesToA32(List<int> b) {
  final result = List<int>.filled(b.length ~/ 4, 0);
  for (int i = 0; i < result.length; i++) {
    result[i] = ((b[i * 4]     & 0xFF) << 24) |
                ((b[i * 4 + 1] & 0xFF) << 16) |
                ((b[i * 4 + 2] & 0xFF) << 8)  |
                 (b[i * 4 + 3] & 0xFF);
  }
  return result;
}
/// Decode Mega's base64url format (no padding, URL-safe chars).
List<int> _megaBase64Decode(String s) {
  String padded = s.replaceAll('-', '+').replaceAll('_', '/');
  while (padded.length % 4 != 0) padded += '=';
  return base64.decode(padded);
}
// =============================================================================
// MEGA HASHCASH SOLVER (Runs in a separate Isolate to prevent UI freeze)
// =============================================================================
static Map<String, dynamic> _megaSolveHashcashCompute(Map<String, dynamic> args) {
  final String token = args['token'];
  final int easiness = args['easiness'];
  final threshold = ((((easiness & 63) << 1) + 1) << ((easiness >> 6) * 7 + 3)) & 0xFFFFFFFF;
  String padded = token.replaceAll('-', '+').replaceAll('_', '/');
  while (padded.length % 4 != 0) padded += '=';
  List<int> tokenDecoded = base64.decode(padded);
  final rem = tokenDecoded.length % 16;
  if (rem != 0) {
    tokenDecoded = [...tokenDecoded, ...List<int>.filled(16 - rem, 0)];
  }
  final numReplications = 262144;
  final tokenSlotSize = 48;
  final buffer = Uint8List(4 + numReplications * tokenSlotSize);
  for (var i = 0; i < numReplications; i++) {
    buffer.setRange(4 + i * tokenSlotSize, 4 + i * tokenSlotSize + tokenDecoded.length, tokenDecoded);
  }
  for (int i = 0; i <= 0xFFFFFFFF; i++) {
    buffer[0] = i & 0xFF;
    buffer[1] = (i >> 8) & 0xFF;
    buffer[2] = (i >> 16) & 0xFF;
    buffer[3] = (i >> 24) & 0xFF;
    final hash = crypto.sha256.convert(buffer).bytes;
    final hashValue = ((hash[0] << 24) | (hash[1] << 16) | (hash[2] << 8) | hash[3]) & 0xFFFFFFFF;
    if (hashValue <= threshold) {
      String res = base64Url.encode(buffer.sublist(0, 4)).replaceAll('=', '');
      return {'result': res};
    }
  }
  return {'result': ''};
}
// =============================================================================
// FIX #1 — Unified Mega API caller with redirect & Hashcash (402) handling
// =============================================================================
Future<dynamic> _megaApiCall(List<dynamic> commands, {String? sid, String? hashcashHeader}) async {
  final uri = Uri.parse(sid != null
      ? '$megaApiBase/cs?id=${DateTime.now().millisecondsSinceEpoch}&sid=$sid'
      : '$megaApiBase/cs?id=${DateTime.now().millisecondsSinceEpoch}');
  final reqBody = jsonEncode(commands);
  final headers = {
    'Content-Type': 'application/json',
    'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
    'Origin': 'https://mega.nz',
    'Referer': 'https://mega.nz/',
  };
  if (hashcashHeader != null) {
    headers['X-Hashcash'] = hashcashHeader;
  }
  String respBody = '';
  int statusCode = 0;
  Map<String, String> respHeaders = {};
  final client = http.Client();
  try {
    final req = http.Request('POST', uri)
      ..headers.addAll(headers)
      ..body = reqBody
      ..followRedirects = false;
    final streamed = await client.send(req).timeout(const Duration(seconds: 30));
    statusCode = streamed.statusCode;
    respHeaders = streamed.headers;
    respBody = await streamed.stream.bytesToString();
    debugPrint('🔴 Mega API HTTP $statusCode | body length: ${respBody.length}');
    if (streamed.isRedirect || (statusCode >= 301 && statusCode <= 307)) {
      final location = respHeaders['location'];
      debugPrint('🔴 Mega redirect → $location');
      if (location != null) {
        final rResp = await client.post(
          Uri.parse(location),
          headers: headers,
          body: reqBody,
        ).timeout(const Duration(seconds: 30));
        statusCode = rResp.statusCode;
        respHeaders = rResp.headers;
        respBody = rResp.body;
      }
    }
  } finally {
    client.close();
  }
  // Handle Hashcash (HTTP 402) — only on the first attempt (hashcashHeader == null)
  // to avoid infinite retry loops.
  if (statusCode == 402 && hashcashHeader == null) {
    // Mega's 402 body is intentionally empty — look for the challenge in headers.
    final hc = respHeaders['x-hashcash'] ?? respHeaders['X-Hashcash'];
    if (hc != null) {
      debugPrint('🔴 Mega 402 Hashcash challenge received: $hc');
      final parts = hc.split(':');
      // Expected format: "1:easiness:version:token" (>= 4 parts, version 1)
      if (parts.length >= 4 && parts[0] == '1') {
        final easiness = int.tryParse(parts[1]) ?? 0;
        final token = parts[3];
        debugPrint('🔴 Solving Hashcash (easiness: $easiness)... this may take a few seconds.');
        final res = await compute(_megaSolveHashcashCompute, {
          'token': token,
          'easiness': easiness,
        });
        final cashValue = res['result'] as String?;
        if (cashValue != null && cashValue.isNotEmpty) {
          debugPrint('✅ Hashcash solved: $cashValue');
          // Solution header format expected by Mega: "1:token:solution"
          final newHeader = '1:$token:$cashValue';
          // Retry the request with the solved hashcash header
          return _megaApiCall(commands, sid: sid, hashcashHeader: newHeader);
        } else {
          throw Exception(
              'Mega hashcash challenge could not be solved. '
              'Please try again or restart the app.');
        }
      } else {
        throw Exception(
            'Mega returned an unrecognized hashcash challenge format. '
            'Please update the app.');
      }
    } else {
      // 402 with no hashcash header — Mega may be rate-limiting this IP/account.
      throw Exception(
          'Mega blocked the request (HTTP 402). '
          'Please wait a few minutes and try again.');
    }
  }
  // If we sent a hashcash solution and still got a 402, the solution was rejected.
  if (statusCode == 402 && hashcashHeader != null) {
    throw Exception(
        'Mega rejected the hashcash solution (HTTP 402). '
        'Please try connecting again.');
  }
  if (respBody.trim().isEmpty) {
    throw Exception(
        'Mega returned an empty response (HTTP $statusCode). '
        'Please check your internet connection and try again.');
  }
  return jsonDecode(respBody);
}
// =============================================================================
// FIX #3 — Correctly decrypt Mega master key from login response 'k' field.
// The 'k' field is base64url-encoded AES-128-ECB encrypted with the derivedKey.
// =============================================================================
Uint8List _megaDecryptMasterKey(String kB64, Uint8List derivedKey) {
  final encKey = Uint8List.fromList(_megaBase64Decode(kB64));
  final cipher = enc.Encrypter(
      enc.AES(enc.Key(derivedKey.sublist(0, 16)), mode: enc.AESMode.ecb, padding: null));
  final decrypted = Uint8List(encKey.length);
  for (int i = 0; i < encKey.length; i += 16) {
    final block = cipher.decryptBytes(
        enc.Encrypted(Uint8List.fromList(encKey.sublist(i, i + 16))));
    decrypted.setRange(i, i + 16, block);
  }
  return decrypted; // 16-byte AES-128 master key
}
// =============================================================================
// FIX #2 — Parse one MPI (Multi-Precision Integer) from a byte buffer.
// Used for RSA private key parsing from Mega's 'privk' field.
// =============================================================================
(BigInt, int) _megaReadMPI(Uint8List data, int offset) {
  if (offset + 2 > data.length) return (BigInt.zero, data.length);
  final bitLen = (data[offset] << 8) | data[offset + 1];
  final byteLen = (bitLen + 7) >> 3;
  BigInt n = BigInt.zero;
  for (int i = 0; i < byteLen && (offset + 2 + i) < data.length; i++) {
    n = (n << 8) | BigInt.from(data[offset + 2 + i]);
  }
  return (n, offset + 2 + byteLen);
}
// =============================================================================
// FIX #2 — RSA-decrypt Mega's 'csid' field using the RSA private key in 'privk'.
// privk is AES-128-CBC (zero IV) encrypted with the master key.
// The MPI sequence in privk is: [p, q, d, u] (Mega-specific order).
// The decrypted csid's last 43 bytes is the actual session token.
// =============================================================================
String? _megaDecryptCsid(String? csidB64, String? privkB64, Uint8List masterKey) {
  if (csidB64 == null || privkB64 == null) return null;
  try {
    // 1. AES-CBC decrypt privk with masterKey, zero IV
    final encPrivk = Uint8List.fromList(_megaBase64Decode(privkB64));
    final cipher = enc.Encrypter(
        enc.AES(enc.Key(masterKey.sublist(0, 16)), mode: enc.AESMode.cbc, padding: null));
    final iv = enc.IV(Uint8List(16)); // zero IV
    final privkBytes = Uint8List(encPrivk.length);
    for (int i = 0; i + 16 <= encPrivk.length; i += 16) {
      final dec = cipher.decryptBytes(
          enc.Encrypted(Uint8List.fromList(encPrivk.sublist(i, i + 16))), iv: iv);
      privkBytes.setRange(i, i + 16, dec);
    }
    // 2. Parse RSA private key: MPI sequence is [p, q, d, u]
    int offset = 0;
    BigInt p, q, d;
    (p, offset) = _megaReadMPI(privkBytes, offset);
    (q, offset) = _megaReadMPI(privkBytes, offset);
    (d, offset) = _megaReadMPI(privkBytes, offset);
    (_, offset) = _megaReadMPI(privkBytes, offset); // u (CRT param) — advance offset only
    final n = p * q;
    // 3. Decode csid ciphertext as big integer
    final cBytes = Uint8List.fromList(_megaBase64Decode(csidB64));
    BigInt c = BigInt.zero;
    for (final byte in cBytes) {
      c = (c << 8) | BigInt.from(byte);
    }
    // 4. RSA decrypt: m = c^d mod n
    final m = c.modPow(d, n);
    // 5. Convert result to bytes — take the last 43 bytes as the session ID
    String mHex = m.toRadixString(16);
    if (mHex.length % 2 != 0) mHex = '0$mHex';
    final mBytes = <int>[];
    for (int i = 0; i < mHex.length; i += 2) {
      mBytes.add(int.parse(mHex.substring(i, i + 2), radix: 16));
    }
    final sidBytes = mBytes.length >= 43 ? mBytes.sublist(mBytes.length - 43) : mBytes;
    return base64Url.encode(sidBytes).replaceAll('=', '');
  } catch (e) {
    debugPrint('❌Å’ Mega csid RSA decryption failed: $e');
    return null;
  }
}
/// Derives Mega's AES-128 master key from the password.
/// Matches mega.js prepare_key() — iteratively encrypts a magic constant.
Uint8List _megaDeriveKey(String password) {
  var pkey = [0x93C467E3, 0x7DB0C7A4, 0xD1BE3F81, 0x0152CB56];
  final pwA32 = _strToA32(password);
  final pwKeys = <List<int>>[];
  for (int i = 0; i < pwA32.length; i += 4) {
    pwKeys.add([
      pwA32[i],
      i + 1 < pwA32.length ? pwA32[i + 1] : 0,
      i + 2 < pwA32.length ? pwA32[i + 2] : 0,
      i + 3 < pwA32.length ? pwA32[i + 3] : 0,
    ]);
  }
  if (pwKeys.isEmpty) pwKeys.add([0, 0, 0, 0]);
  for (int i = 0; i < 65536; i++) {
    for (final keyWords in pwKeys) {
      final keyBytes = _a32ToBytes(keyWords);
      final cipher = enc.Encrypter(
          enc.AES(enc.Key(keyBytes), mode: enc.AESMode.ecb, padding: null));
      final pkeyBytes = _a32ToBytes(pkey);
      final encrypted = cipher.encryptBytes(pkeyBytes.toList());
      pkey = _bytesToA32(encrypted.bytes.toList());
    }
  }
  return _a32ToBytes(pkey);
}
/// Computes Mega's user hash (uh) for login.
/// Matches mega.js stringhash() — XORs email words, then AES-encrypts 16384x.
String _megaComputePasswordHash(String email, Uint8List derivedKey) {
  final emailA32 = _strToA32(email.toLowerCase());
  final hash = [0, 0, 0, 0];
  for (int i = 0; i < emailA32.length; i++) {
    hash[i & 3] ^= emailA32[i];
  }
  final cipher = enc.Encrypter(
      enc.AES(enc.Key(derivedKey), mode: enc.AESMode.ecb, padding: null));
  var block = _a32ToBytes(hash).toList();
  for (int r = 0; r < 16384; r++) {
    block = cipher.encryptBytes(block).bytes.toList();
  }
  final hashA32 = _bytesToA32(block);
  return base64Url.encode(_a32ToBytes([hashA32[0], hashA32[1]])).replaceAll('=', '');
}
// =============================================================================
// Login to Mega — fully corrected with fixes for Issues #1, #2, #3
// =============================================================================
Future<void> _loginToMega() async {
  if (widget.firebaseUser.isAnonymous) {
    _showGoogleSignInRequired();
    return;
  }
  String email = '';
  String password = '';
  bool obscure = true;
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFD9173A).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.cloud, color: Color(0xFFD9173A), size: 24),
              ),
              const SizedBox(width: 12),
              const Text('Connect Mega',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter your Mega.nz credentials to connect your account.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                keyboardType: TextInputType.emailAddress,
                onChanged: (v) => email = v.trim(),
              ),
              const SizedBox(height: 12),
              TextField(
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  suffixIcon: IconButton(
                    icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setDialogState(() => obscure = !obscure),
                  ),
                ),
                onChanged: (v) => password = v,
              ),
              const SizedBox(height: 8),
              const Text(
                '’ Your password is processed locally using AES-128 encryption and never sent to our servers.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD9173A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Connect'),
            ),
          ],
        ),
      );
    },
  );
  if (result != true || email.isEmpty || password.isEmpty) return;
  setState(() {
    _isLoading = true;
    _statusMessage = 'Connecting to Mega...';
    _megaError = false;
  });
  try {
    // Step 1: Derive AES key and password hash (client-side — never sent in plaintext)
    setState(() => _statusMessage = 'Deriving key... (this may take a few seconds)');
    final derivedKey = _megaDeriveKey(password);
    final uh = _megaComputePasswordHash(email, derivedKey);
    debugPrint('🔴 Mega uh derived');
    // Step 2: Send login request (FIX #1: uses redirect-safe _megaApiCall)
    setState(() => _statusMessage = 'Authenticating with Mega...');
    final loginResponse = await _megaApiCall([{'a': 'us', 'user': email, 'uh': uh}]);
    final loginData = (loginResponse is List) ? loginResponse[0] : loginResponse;
    if (loginData is int) {
      final errorMessages = {
        -1:  'Internal Mega error',
        -2:  'Invalid arguments sent to Mega',
        -3:  'Request out of range',
        -4:  'Too many requests — please wait and retry',
        -9:  'Resource not found',
        -15: 'Invalid email or password',
        -16: 'Too many failed login attempts — try later',
      };
      throw Exception(errorMessages[loginData] ?? 'Mega login failed (code: $loginData)');
    }
    // Step 3 (FIX #3): Decrypt master key from 'k' field using derivedKey
    final String? kField = loginData['k'];
    if (kField == null) throw Exception('Mega response missing master key field');
    final masterKey = _megaDecryptMasterKey(kField, derivedKey);
    debugPrint('🔴 Mega master key decrypted');
    // Step 4 (FIX #2): Get session — prefer tsid (simple), fall back to RSA-decrypted csid
    setState(() => _statusMessage = 'Establishing Mega session...');
    String? sessionId = loginData['tsid'] as String?;
    if (sessionId == null || sessionId.isEmpty) {
      debugPrint('🔴 Mega: no tsid, attempting csid RSA decrypt...');
      sessionId = _megaDecryptCsid(
        loginData['csid'] as String?,
        loginData['privk'] as String?,
        masterKey,
      );
    }
    if (sessionId == null || sessionId.isEmpty) {
      throw Exception(
          'Could not establish a Mega session. '
          'Your account may require 2FA or an unsupported login method.');
    }
    debugPrint('✅ Mega session obtained');
    // Step 5: Store session and master key (NOT derived key — master key is needed for decryption)
    await secureStorage.write(key: _userKey('mega_session_id'), value: sessionId);
    await secureStorage.write(key: _userKey('mega_master_key'), value: base64Url.encode(masterKey));
    // Remove old derived key storage if present (migration)
    await secureStorage.delete(key: _userKey('mega_derived_key'));
    analytics.logLogin(loginMethod: 'mega');
    debugPrint('✅ Mega Connected! Session established.');
    if (mounted) {
      setState(() {
        _megaSessionId = sessionId;
        _megaError = false;
        _statusMessage = 'Connected! Fetching Mega photos...';
      });
      await _fetchMegaPhotos();
      _updateFilteredItems();
    }
  } catch (e) {
    debugPrint('❌Å’ Mega Login Error: $e');
    if (mounted) {
      setState(() {
        _megaError = true;
        _isLoading = false;
        _statusMessage = 'Mega Login Failed: ${e.toString().split('Exception: ').last}';
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Mega Error: ${e.toString().split('Exception: ').last}'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ));
    }
  }
}
// =============================================================================
// Fetch Mega photos — fixes #4 (session expiry), #5 (redirect), #6 (empty body),
// #7/#8 (node key 32-byte XOR), #9 (null bytes), #10 (storage read outside loop)
// =============================================================================
Future<List<DriveItem>> _fetchMegaPhotos() async {
  if (_megaSessionId == null) return [];
  debugPrint('📁¥ Fetching Mega photos...');
  try {
    // FIX #5: Use _megaApiCall instead of http.post (redirect-safe)
    final responseData = await _megaApiCall(
      [{'a': 'f', 'c': 1, 'r': 1}],
      sid: _megaSessionId,
    );
    final data = (responseData is List) ? responseData[0] : responseData;
    if (data is int) {
      debugPrint('❌Å’ Mega fetch error code: $data');
      // FIX #4: Handle session expiry explicitly
      if (data == -15) {
        debugPrint('❌Å’ Mega session expired — logging out');
        await _logoutFromMega();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Mega session expired. Please reconnect.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
          ));
        }
      } else if (mounted) {
        setState(() => _megaError = true);
      }
      return [];
    }
    final List<dynamic> nodes = data['f'] ?? [];
    // FIX #10: Read master key ONCE outside the loop (not per-node)
    final String? masterKeyB64 = await secureStorage.read(key: _userKey('mega_master_key'));
    Uint8List? masterKey;
    enc.Encrypter? masterCipher;
    if (masterKeyB64 != null) {
      masterKey = Uint8List.fromList(base64Url.decode(masterKeyB64));
      masterCipher = enc.Encrypter(
          enc.AES(enc.Key(masterKey.sublist(0, 16)), mode: enc.AESMode.ecb, padding: null));
    }
    const mediaExtensions = {
      '.jpg', '.jpeg', '.png', '.gif', '.webp', '.heic', '.heif', '.bmp', '.tiff',
      '.mp4', '.mov', '.avi', '.mkv', '.wmv', '.3gp', '.m4v',
    };
    final List<DriveItem> items = [];
    for (final node in nodes) {
      if (node['t'] != 0) continue; // Skip folders (type 1) and other types
      final String handle = node['h'] ?? '';
      if (handle.isEmpty) continue;
      String fileName = 'mega_file_$handle';
      bool isVideo = false;
      // Attempt to decrypt the node attribute to get the real filename
      if (masterCipher != null && masterKey != null) {
        try {
          final String? nodeKeyField = node['k']?.toString();
          if (nodeKeyField != null && nodeKeyField.contains(':')) {
            // Node key can be "ownerHandle:encKey" or "h1:k1/h2:k2" (shared)
            // Take the first (or only) key pair
            final firstPair = nodeKeyField.split('/').first;
            final encNodeKeyB64 = firstPair.contains(':')
                ? firstPair.split(':').last
                : firstPair;
            final encNodeKey = Uint8List.fromList(_megaBase64Decode(encNodeKeyB64));
            // FIX #7: Decrypt each 16-byte block of the node key with master key (ECB)
            final decNodeKey = Uint8List(encNodeKey.length);
            for (int i = 0; i + 16 <= encNodeKey.length; i += 16) {
              final block = masterCipher.decryptBytes(
                  enc.Encrypted(Uint8List.fromList(encNodeKey.sublist(i, i + 16))));
              decNodeKey.setRange(i, i + 16, block);
            }
            // FIX #7/#8: For 32-byte (file) node keys, attribute key = XOR of two halves
            // For 16-byte (folder) keys, use directly. Media files always have 32-byte keys.
            Uint8List attrKey;
            if (decNodeKey.length >= 32) {
              attrKey = Uint8List(16);
              for (int i = 0; i < 16; i++) {
                attrKey[i] = decNodeKey[i] ^ decNodeKey[i + 16];
              }
            } else if (decNodeKey.length >= 16) {
              attrKey = Uint8List.fromList(decNodeKey.sublist(0, 16));
            } else {
              continue; // Key too short — skip node
            }
            // Decrypt the 'a' attribute (AES-128-CBC, zero IV) to get {n: filename}
            final String? attrB64 = node['a']?.toString();
            if (attrB64 != null) {
              final attrBytes = Uint8List.fromList(_megaBase64Decode(attrB64));
              final attrCipher = enc.Encrypter(
                  enc.AES(enc.Key(attrKey), mode: enc.AESMode.cbc, padding: null));
              final attrIv = enc.IV(Uint8List(16)); // zero IV
              if (attrBytes.length >= 16) {
                final decrypted = attrCipher.decryptBytes(
                    enc.Encrypted(attrBytes), iv: attrIv);
                // FIX #9: Strip null bytes correctly using indexOf, not broken regex
                final nullIdx = decrypted.indexOf(0);
                final trimmed = nullIdx >= 0 ? decrypted.sublist(0, nullIdx) : decrypted;
                final decoded = utf8.decode(trimmed, allowMalformed: true);
                // Attribute starts with "MEGA{...}" — find the JSON object
                final jsonStart = decoded.indexOf('{');
                if (jsonStart >= 0) {
                  try {
                    final attrs = jsonDecode(decoded.substring(jsonStart));
                    if (attrs['n'] != null) {
                      fileName = attrs['n'].toString();
                    }
                  } catch (_) {
                    // JSON parse failed — keep handle-based name
                  }
                }
              }
            }
          }
        } catch (e) {
          debugPrint('⚠️ Could not decrypt Mega node name for $handle: $e');
        }
      }
      // Determine media type from decrypted filename extension
      final lc = fileName.toLowerCase();
      final videoExts = {'.mp4', '.mov', '.avi', '.mkv', '.wmv', '.3gp', '.m4v'};
      isVideo = videoExts.any((ext) => lc.endsWith(ext));
      final bool isMedia = mediaExtensions.any((ext) => lc.endsWith(ext));
      if (!isMedia) continue;
      final int? tsSeconds = node['ts'] as int?;
      final DateTime? created = tsSeconds != null
          ? DateTime.fromMillisecondsSinceEpoch(tsSeconds * 1000)
          : null;
      items.add(DriveItem(
        id: handle,
        name: fileName,
        source: PhotoSource.mega,
        downloadUrl: null, // FIX #11: Never store Mega URLs — they expire; fetch fresh each time
        thumbnailUrl: null,
        created: created,
        isVideo: isVideo,
      ));
    }
    debugPrint('✅ Mega: Found ${items.length} media files out of ${nodes.length} nodes.');
    if (mounted) {
      setState(() {
        _megaError = false;
        _driveItems.removeWhere((item) => item.source == PhotoSource.mega);
        _driveItems.addAll(items);
        _isLoading = false;
        _statusMessage = '';
      });
    }
    return items;
  } catch (e) {
    debugPrint('❌Å’ Mega Fetch Error: $e');
    if (mounted) {
      setState(() {
        _megaError = true;
        _isLoading = false;
        _statusMessage = 'Mega fetch failed: ${e.toString().split('Exception: ').last}';
      });
    }
    return [];
  }
}
  Future<List<DriveItem>> _fetchLocalPhotos({bool firstPage = false}) async {
    final List<DriveItem> localItems = [];
    try {
      if (firstPage) {
        _localPage = 0;
        _localTotalCount = 0;
        _hasMoreLocal = true;
        _localRecentPath = null;
        _isLoadingMore = false;
      }
      if (!_hasMoreLocal) {
        return [];
      }
      final PermissionState ps = await PhotoManager.requestPermissionExtend();
      if (ps.isAuth || ps.hasAccess) {
        final FilterOptionGroup filter = FilterOptionGroup();
        filter.addOrderOption(
          OrderOption(
            type: OrderOptionType.createDate,
            asc: _currentSortOption == SortOption.oldestFirst,
          ),
        );
        final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
          type: RequestType.common,
          onlyAll: true,
          filterOption: filter,
        );
        if (paths.isNotEmpty) {
          final recentPath = paths.first;
          final totalCount = await recentPath.assetCountAsync;
          _localTotalCount = totalCount;
          _hasMoreLocal = false; // All local photos are loaded in full

          // Fetch all local asset metadata references (extremely fast cursor read)
          final List<AssetEntity> assets = await recentPath.getAssetListRange(
            start: 0,
            end: totalCount > 0 ? totalCount : 50000,
          );
          _localPage = assets.length;

          final now = DateTime.now();
          final oneYearInFuture = now.add(const Duration(days: 365));

          for (final asset in assets) {
            DateTime? createdDate = asset.createDateTime;
            // Check for invalid timestamps (1970 or future dates) and fallback to modified date
            if (createdDate.year < 2000 || createdDate.isAfter(oneYearInFuture)) {
              createdDate = asset.modifiedDateTime;
            }
            if (createdDate.year < 2000 || createdDate.isAfter(oneYearInFuture)) {
              createdDate = null; // Cleanly groups under 'Unknown Date'
            }
            localItems.add(DriveItem(
              id: asset.id,
              name: asset.title ?? 'local_${asset.id}',
              source: PhotoSource.local,
              downloadUrl: asset.id,
              created: createdDate,
              thumbnailUrl: asset.id,
              isVideo: asset.type == AssetType.video,
              size: 0,
              localAsset: asset,
            ));
          }
          debugPrint('📁± Local photos: successfully loaded all ${localItems.length} items.');
        } else {
          _hasMoreLocal = false;
        }
      } else {
        _hasMoreLocal = false;
        debugPrint('⚠️ Local photo access not granted (state: $ps)');
      }
    } catch (e) {
      debugPrint("Error fetching local photos: $e");
    }
    return localItems;
  }
/// Generates a fresh temporary download URL for a Mega file node.
/// FIX #11: Always fetches a new URL — Mega URLs expire in ~1 hour, never cache them.
Future<String?> _getMegaDownloadUrl(String nodeHandle) async {
  if (_megaSessionId == null) return null;
  try {
    // FIX #5: Use _megaApiCall (redirect-safe)
    final responseData = await _megaApiCall(
      [{'a': 'g', 'g': 1, 'p': nodeHandle}],
      sid: _megaSessionId,
    ).timeout(const Duration(seconds: 15));
    final data = (responseData is List) ? responseData[0] : responseData;
    if (data is int) {
      debugPrint('❌Å’ Mega download URL error code: $data');
      // FIX #4: Handle session expiry
      if (data == -15) {
        await _logoutFromMega();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Mega session expired. Please reconnect.'),
            backgroundColor: Colors.orange,
          ));
        }
      }
      return null;
    }
    final dynamic g = data['g'];
    if (g is String && g.isNotEmpty) return g;
    if (g is List && g.isNotEmpty) return g[0].toString();
    return null;
  } catch (e) {
    debugPrint('❌Å’ Mega Download URL Error: $e');
    return null;
  }
}
/// Logout from Mega.
/// FIX #12: Invalidates the server session before clearing local storage.
Future<void> _logoutFromMega() async {
  // FIX #12: Tell Mega server to invalidate the session
  if (_megaSessionId != null) {
    try {
      await _megaApiCall([{'a': 'sml'}], sid: _megaSessionId)
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // Ignore server logout errors — local logout proceeds regardless
    }
  }
  await secureStorage.delete(key: _userKey('mega_session_id'));
  await secureStorage.delete(key: _userKey('mega_master_key'));
  await secureStorage.delete(key: _userKey('mega_derived_key')); // clean up legacy key
  if (mounted) {
    setState(() {
      _megaSessionId = null;
      _megaError = false;
      _driveItems.removeWhere((item) => item.source == PhotoSource.mega);
    });
    _updateFilteredItems();
  }
  debugPrint('🚪 Logged out from Mega');
}
// =============================================================================
// END MEGA INTEGRATION
// =============================================================================
// =============================================================================
// ✅ PASTE THIS NEW METHOD
/// Gets a fresh, valid access token from GoogleSignIn
// ... (inside _CloudPhotosPageState) ...
// ✅ PASTE THIS REPLACEMENT METHOD
/// Gets a fresh, valid access token from GoogleSignIn
// ✅ PASTE THIS REPLACEMENT METHOD
/// Gets a fresh, valid access token from GoogleSignIn
// ... (inside class _PhotoViewerPageState) ...
// ✅ PASTE THIS REPLACEMENT METHOD
Future<String?> _getGoogleAuthToken() async {
    try {
      GoogleSignInAccount? googleUser = googleSignIn.currentUser;
      if (googleUser == null) {
        googleUser = await googleSignIn.signInSilently();
      }
      if (googleUser == null) {
        debugPrint("PhotoViewer: Cannot get Google auth token, user is null.");
        return null;
      }
      final auth = await googleUser.authentication;
      return auth.accessToken;
    } catch (e) {
      debugPrint("Error getting Google auth token: $e");
      return null;
    }
  }
  Future<void> _checkGoogleDriveAccess({bool fetch = false}) async {
    // Just check if the user is signed in, don't ask for Drive permissions
    final bool hasAccess = await googleSignIn.isSignedIn();
    if (!mounted) return;
    setState(() {
      _hasGoogleDriveAccess = hasAccess;
    });
    if (hasAccess && fetch) {
      _fetchAllPhotos(firstPage: true);
    }
  }
  /// This is called from the Drawer or Home Page to
  /// pop up the "Allow Access" dialog for Google Drive.
  Future<void> _loginGoogleDrive({bool fromHomePage = false}) async {
    if (widget.firebaseUser.isAnonymous) {
      _showGoogleSignInRequired();
      return;
    }
    if (_isGoogleDriveAuthInProgress || _isOneDriveRefreshing || _isDropboxRefreshing) return;
    if (!fromHomePage) {
      Navigator.pop(context); // Close drawer
    }
    setState(() {
      _isGoogleDriveAuthInProgress = true;
      _statusMessage = 'Requesting Google Drive access...';
    });
    try {
      // This will re-use the signed-in user and just ask for the new scope
      final bool hasAccess = await googleSignIn.requestScopes([googleDriveScope]); 
      if (!mounted) return;
      setState(() {
        _hasGoogleDriveAccess = hasAccess;
        if (!hasAccess) {
          _statusMessage = 'Google Drive access denied.';
          _updateFilteredItems();
        }
      });
      if (hasAccess) {
        // Success! Fetch photos.
        _fetchAllPhotos(firstPage: true);
      }
    } catch (e) {
      // ✅ FIX: SignInHubActivity NullPointerException on outdated Google Play Services (Crashlytics fix)
      // Old devices (e.g. Nexus 5X) with stale play-services-auth crash inside SignInHubActivity.
      // Catching broadly here prevents a fatal crash and shows the user a helpful message.
      debugPrint("Error requesting Google Drive scopes: $e");
      final bool isPlayServicesIssue = e.toString().contains('NullPointer') ||
          e.toString().contains('getClass') ||
          e.toString().contains('SignInHubActivity');
      if (mounted) {
        setState(() {
          _hasGoogleDriveAccess = false;
          _statusMessage = isPlayServicesIssue
              ? 'Google Sign-In failed. Please update Google Play Services.'
              : 'Error connecting Google Drive.';
        });
        _updateFilteredItems();
        if (isPlayServicesIssue) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Sign-In failed. Please update Google Play Services on your device.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
          ));
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isGoogleDriveAuthInProgress = false);
      }
    }
  }
  /// This mimics the Dropbox/OneDrive disconnect by just removing
  /// items from the UI. User must go to their Google account to
  /// fully revoke permission.
  Future<void> _logoutGoogleDrive() async {
    try {
      debugPrint("🚪 Disconnecting Google Drive (locally)...");
      setState(() {
        _hasGoogleDriveAccess = false;
        _driveItems.removeWhere((item) => item.source == PhotoSource.googleDrive);
      });
      _updateFilteredItems();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Disconnected from Google Drive')),
        );
      }
    } catch (e) {
      debugPrint("❌Å’ Error during Google Drive local disconnect: $e");
    }
  }
// ✅ PASTE THESE 3 NEW METHODS
/// Attempts to log in to Box
Future<void> _loginBox({bool fromHomePage = false}) async {
  if (widget.firebaseUser.isAnonymous) {
    _showGoogleSignInRequired();
    return;
  }
  if (_isOneDriveRefreshing || _isDropboxRefreshing) {
    if (mounted && !fromHomePage) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('An authentication process is already in progress. Please wait a moment.'),
        backgroundColor: Colors.orange,
      ));
    }
    return;
  }
  if (!fromHomePage) {
    Navigator.pop(context);
  }
  setState(() {
    _isLoading = false;
    _statusMessage = 'Redirecting to Box...';
    _boxError = false;
    // We can re-use the Dropbox lock, or add a new _isBoxRefreshing one
    _isDropboxRefreshing = true; // Using Dropbox lock for simplicity
  });
  bool loginSuccess = false;
  try {
    final AuthorizationTokenResponse? result =
        await appAuth.authorizeAndExchangeCode(
      AuthorizationTokenRequest(
        boxClientId,
        redirectUri,
        clientSecret: boxClientSecret, // Box requires client secret for auth code
        serviceConfiguration: boxServiceConfiguration,
        scopes: boxScope.split(' '),
      ),
    );
    if (result != null) {
      _onLoginSuccessBox(result);
      loginSuccess = true;
    } else {
      _onLoginFail('Box login canceled or failed. Please try again.');
      _updateFilteredItems();
    }
  } catch (e) {
    _onLoginFail('Box login error: ${e.toString()}');
    _updateFilteredItems();
  } finally {
    if (mounted) {
      setState(() => _isDropboxRefreshing = false); // Release lock
    }
  }
  if (loginSuccess) {
    _fetchAllPhotos(firstPage: true);
  }
}
/// Saves Box tokens on successful login
void _onLoginSuccessBox(TokenResponse result) {
  _CloudPhotosPageState.analytics.logLogin(loginMethod: 'box');
  final newRefreshToken = result.refreshToken ?? _boxRefreshToken;
  setState(() {
    _boxAccessToken = result.accessToken;
    if (newRefreshToken != null) _boxRefreshToken = newRefreshToken;
    _boxError = false; // Clear error on success
  });
  // Securely store the refresh token — never overwrite with null
  if (newRefreshToken != null) {
    secureStorage.write(key: _userKey('box_refresh_token'), value: newRefreshToken);
  }
  debugPrint("Box Login Success");
}
/// Disconnects Box locally
Future<void> _logoutBox() async {
  try {
    debugPrint("🚪 Disconnecting Box (locally)...");
    await secureStorage.delete(key: _userKey('box_refresh_token'));
    setState(() {
      _boxAccessToken = null;
      _boxRefreshToken = null;
      _boxError = false;
      _driveItems.removeWhere((item) => item.source == PhotoSource.box);
    });
    _updateFilteredItems();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Disconnected from Box')),
      );
    }
  } catch (e) {
    debugPrint("❌Å’ Error during Box local disconnect: $e");
  }
}
  // --- NEW: Authenticated HTTP GET wrapper ---
  /// Performs an HTTP GET request, automatically refreshing the token on 401.
  // ✅ PASTE THIS REPLACEMENT METHOD
  /// Performs an HTTP GET request, automatically refreshing the token on 401.
  Future<http.Response> _authenticatedGet(
      Uri url, PhotoSource source) async {
    String? token;
    if (source == PhotoSource.oneDrive) {
      token = _oneDriveAccessToken;
    } else if (source == PhotoSource.dropbox) {
      token = _dropboxAccessToken;
    } else if (source == PhotoSource.box) {
      token = _boxAccessToken;
    }
    if (token == null) throw Exception('Not authenticated for $source');
    final headers = {'Authorization': 'Bearer $token'};
    final response = await http.get(url, headers: headers);
    if (response.statusCode == 401) {
      debugPrint("Got 401. Refreshing token for $source...");
      final bool refreshed = await _refreshAccessToken(source);
      if (refreshed) {
        // Retry the request with the new token
        String? newToken;
        if (source == PhotoSource.oneDrive) {
          newToken = _oneDriveAccessToken;
        } else if (source == PhotoSource.dropbox) {
          newToken = _dropboxAccessToken;
        } else if (source == PhotoSource.box) {
          newToken = _boxAccessToken;
        }
        final newHeaders = {'Authorization': 'Bearer $newToken'};
        debugPrint("Retrying GET request to $url");
        return await http.get(url, headers: newHeaders);
      } else {
        // Refresh failed, throw error to stop
        throw Exception('Token refresh failed');
      }
    } else {
      // Not a 401, just return the response
      return response;
    }
  }
  // --- NEW: Authenticated HTTP POST wrapper ---
// ✅ PASTE THIS REPLACEMENT METHOD
  // --- NEW: Authenticated HTTP POST wrapper ---
  Future<http.Response> _authenticatedPost(Uri url, PhotoSource source,
      {Map<String, String>? headers, Object? body}) async {
    String? token;
    if (source == PhotoSource.oneDrive) {
      token = _oneDriveAccessToken;
    } else if (source == PhotoSource.dropbox) {
      token = _dropboxAccessToken;
    } else if (source == PhotoSource.box) {
      token = _boxAccessToken;
    }
    if (token == null) throw Exception('Not authenticated for $source');
    // Add auth to existing headers
    final finalHeaders = headers ?? {};
    finalHeaders['Authorization'] = 'Bearer $token';
    final response =
        await http.post(url, headers: finalHeaders, body: body);
    if (response.statusCode == 401) {
      debugPrint("Got 401. Refreshing token for $source...");
      final bool refreshed = await _refreshAccessToken(source);
      if (refreshed) {
        String? newToken;
        if (source == PhotoSource.oneDrive) {
          newToken = _oneDriveAccessToken;
        } else if (source == PhotoSource.dropbox) {
          newToken = _dropboxAccessToken;
        } else if (source == PhotoSource.box) {
          newToken = _boxAccessToken;
        }
        finalHeaders['Authorization'] = 'Bearer $newToken';
        debugPrint("Retrying POST request to $url");
        return await http.post(url, headers: finalHeaders, body: body);
      } else {
        throw Exception('Token refresh failed');
      }
    } else {
      return response;
    }
  }
  // --- NEW: Authenticated HTTP DELETE wrapper ---
 // ✅ PASTE THIS REPLACEMENT METHOD
  // --- NEW: Authenticated HTTP DELETE wrapper ---
  Future<http.Response> _authenticatedDelete(
      Uri url, PhotoSource source) async {
    String? token;
    if (source == PhotoSource.oneDrive) {
      token = _oneDriveAccessToken;
    } else if (source == PhotoSource.dropbox) {
      token = _dropboxAccessToken;
    } else if (source == PhotoSource.box) {
      token = _boxAccessToken;
    }
    if (token == null) throw Exception('Not authenticated for $source');
    final headers = {'Authorization': 'Bearer $token'};
    final response = await http.delete(url, headers: headers);
    if (response.statusCode == 401) {
      debugPrint("Got 401. Refreshing token for $source...");
      final bool refreshed = await _refreshAccessToken(source);
      if (refreshed) {
        // Retry the request with the new token
        String? newToken;
        if (source == PhotoSource.oneDrive) {
          newToken = _oneDriveAccessToken;
        } else if (source == PhotoSource.dropbox) {
          newToken = _dropboxAccessToken;
        } else if (source == PhotoSource.box) {
          newToken = _boxAccessToken;
        }
        final newHeaders = {'Authorization': 'Bearer $newToken'};
        debugPrint("Retrying DELETE request to $url");
        return await http.delete(url, headers: newHeaders);
      } else {
        // Refresh failed, throw error to stop
        throw Exception('Token refresh failed');
      }
    } else {
      // Not a 401, just return the response
      return response;
    }
  }
  // --- NEW METHOD: Verify Purchase and Update Firestore ---
  Future<void> _verifyAndGrantProAccess(PurchaseDetails purchaseDetails) async {
    analytics.logEvent(name: 'purchase', parameters: {'currency': 'INR', 'value': 1499.00});
    if (purchaseDetails.productID == _kProSubscriptionId || purchaseDetails.productID == _kProMonthlyId) {
      debugPrint("Granting Pro access for user: ${widget.firebaseUser.uid}");
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_purchased_pro', true);
      await prefs.setBool('is_pro_${widget.firebaseUser.uid}', true);

      // FIX: Persist purchaseToken to Firestore so Pro survives reinstalls/updates.
      // Firebase is the permanent server-side record. On reinstall, when Google Play
      // restorePurchases() fires, this writes isPro:true back to Firestore automatically.
      final purchaseData = <String, dynamic>{
        'isPro': true,
        'purchaseToken': purchaseDetails.verificationData.serverVerificationData,
        'productId': purchaseDetails.productID,
        'purchasedAt': FieldValue.serverTimestamp(),
      };

      try {
        await _userDocRef.set(purchaseData, SetOptions(merge: true));
        if (mounted) {
          setState(() => _isPro = true);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(purchaseDetails.status == PurchaseStatus.restored
                ? 'Pro access restored!'
                : 'Upgrade successful! Welcome to Pro!'),
            backgroundColor: Colors.green,
          ));
        }
      } catch (e) {
        debugPrint("Firestore update error granting Pro: $e");
        if (mounted) {
          setState(() => _isPro = true);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(purchaseDetails.status == PurchaseStatus.restored
                ? 'Pro access restored locally!'
                : 'Upgrade successful! Welcome to Pro!'),
            backgroundColor: Colors.green,
          ));
        }
      }
    } else {
       debugPrint("Verification failed: Unexpected product ID ${purchaseDetails.productID}");
    }
  }
  // --- NEW METHOD: Initiate Purchase ---
  Future<void> _buyProSubscription(String productId) async {
    analytics.logEvent(name: 'begin_checkout');
    // 🛡️ CRITICAL: Don't allow purchases on GUEST accounts.
    if (widget.firebaseUser.isAnonymous) {
      _showGoogleSignInRequired();
      return;
    }
    // 🛡️ Feedback for pending purchases
    if (_isPurchasePending) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
         content: Text('A purchase is already in progress. Please wait...'),
         backgroundColor: Colors.blue,
       ));
       return;
    }
    // 🛡️ Handle empty product list
    if (_products.isEmpty) {
       if (mounted) setState(() => _isIapLoading = true);
       await _initIAP(); // Try refreshing products
       if (!mounted) return;
       if (_products.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_iapError ?? 'Could not load Pro features. Please check your internet.'),
            backgroundColor: Colors.red,
          ));
          setState(() => _isIapLoading = false);
          return;
       }
    }
    final ProductDetails? productDetails = _products.firstWhereOrNull((prod) => prod.id == productId);
    if (productDetails == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Selected product is currently unavailable. Please try again later.'),
          backgroundColor: Colors.orange,
        ));
      }
      return;
    }
    final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: productDetails,
    );
    try {
      debugPrint("🚀 Starting purchase flow for: ${productDetails.id}");
      final bool bought = await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
      debugPrint("Initiated purchase flow, result: $bought");
      if (bought && mounted) {
         setState(() => _isPurchasePending = true); // Set pending state
      } else if (!bought && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not start purchase flow. Please try again.'),
            backgroundColor: Colors.orange,
         ));
      }
    } catch (e) {
       debugPrint("❌Å’ Error initiating purchase: $e");
        if (mounted) {
          setState(() => _isPurchasePending = false);
          // ✅ FIX: Billing NullPointerException on outdated Google Play Services (Crashlytics fix)
          // ProxyBillingActivity crashes on old devices with stale Play Store — show friendly message
          final errMsg = e.toString();
          final bool isPlayServicesIssue = errMsg.contains('NullPointer') ||
              errMsg.contains('PendingIntent') ||
              errMsg.contains('IntentSender');
          final String userMessage = isPlayServicesIssue
              ? 'Purchase failed. Please update Google Play Store and try again.'
              : 'Error starting purchase: ${errMsg.split(']').last}';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(userMessage),
            backgroundColor: Colors.red,
          ));
        }
    }
  }
  // --- NEW METHOD: Restore Purchases ---
  Future<void> _restorePurchases() async {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Checking for existing purchases...'),
          duration: Duration(seconds: 2),
        ));
      }

      // 1. Check if user is an internal tester
      if (isInternalTester(widget.firebaseUser.email)) {
        await _userDocRef.set({'isPro': true}, SetOptions(merge: true)).catchError((e) {});
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('has_purchased_pro', true);
        await prefs.setBool('is_pro_${widget.firebaseUser.uid}', true);
        if (mounted) {
          setState(() => _isPro = true);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Tester account verified: Pro features unlocked!'),
            backgroundColor: Colors.green,
          ));
        }
        return;
      }

      // 2. Check local verified purchase cache
      final prefs = await SharedPreferences.getInstance();
      // SECURITY: Only read user-scoped key for Pro restoration
      final hasLocal = prefs.getBool('is_pro_${widget.firebaseUser.uid}') ?? false;
      if (hasLocal) {
        await _userDocRef.set({'isPro': true}, SetOptions(merge: true)).catchError((e) {});
        if (mounted) {
          setState(() => _isPro = true);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Pro status restored from verified purchase!'),
            backgroundColor: Colors.green,
          ));
        }
      }

      // 3. Query Google Play Store / App Store
      if (defaultTargetPlatform == TargetPlatform.android) {
        final InAppPurchaseAndroidPlatformAddition androidAddition =
            _inAppPurchase.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
        final QueryPurchaseDetailsResponse? pastPurchases = await androidAddition.queryPastPurchases();
        if (pastPurchases != null && pastPurchases.pastPurchases.isNotEmpty) {
          await _handlePurchaseUpdates(pastPurchases.pastPurchases);
        }
      }
      await _inAppPurchase.restorePurchases();
    } catch (e) {
      debugPrint("Error restoring purchases: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error restoring purchases: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }
Future<void> _shareApp() async {
    // TODO: Replace with your app's real Play Store link
    const String appUrl = 'https://play.google.com/store/apps/details?id=com.pranav.onedrivephotos';
    const String message = 'Check out Cloud Photos! It lets you see all your cloud photos in one simple app.\n\n$appUrl';
    await Share.share(message);
  }
  Future<void> _openPrivacyPolicy() async {
    // TODO: Replace with your app's real Privacy Policy link
    final Uri url = Uri.parse('https://kar701-dot.github.io/UnifiedGallery/privacy.html');
    if (!await launchUrl(url)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not open privacy policy.'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }
  Future<void> _showAboutDialog() async {
    // Close the drawer first
    Navigator.pop(context); 
    showAboutDialog(
      context: context,
      applicationIcon: const Icon(Icons.cloud_queue_rounded, size: 60, color: Color(0xFF0078D4)),
      applicationName: _packageInfo.appName,
      applicationVersion: 'Version: ${_packageInfo.version} (${_packageInfo.buildNumber})',
      applicationLegalese: '© 2025 Kartik Urkude.\nAll rights reserved.',
      children: [
        const SizedBox(height: 20),
        const Text('This app lets you browse all your cloud photos from OneDrive and Dropbox in one simple, beautiful gallery.'),
      ],
    );
  }
  // --- END OF NEW HELPER METHODS ---
Future<void> _showDeleteAccountDialog() async {
    // Close the drawer
    Navigator.pop(context);
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // User must make a choice
      builder: (context) => AlertDialog(
        title: const Text('Delete Account?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure?\n\nThis will permanently delete your account and all associated data, including favorites, albums, and pro status.\n\nThis action cannot be undone.',
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () async {
                final Uri url = Uri.parse('https://kar701-dot.github.io/UnifiedGallery/account-deletion.html');
                if (!await launchUrl(url)) {
                  debugPrint('Could not launch account deletion policy');
                }
              },
              child: const Text(
                'Read Account Deletion Policy',
                style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // User confirmed
              Navigator.pop(context, true);
            },
            child: Text('Delete Account',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      _deleteUserAndLogout();
    }
  }
  Future<void> _deleteUserAndLogout() async {
    // ✅ FIX: Check mounted before showing any dialogs
    if (!mounted) return;
    // Show a loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Dialog(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Deleting account...'),
            ],
          ),
        ),
      ),
    );
    try {
      // 1. Delete Firestore Data
      // This is the most important part for user privacy
      await _userDocRef.delete();
      // 2. Clear local asset cache and database records
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_userKey('cached_drive_items_list'));
        await assetRepository.deleteAllForUser(widget.firebaseUser.uid);
      } catch (e) {
        debugPrint("Error clearing local cache on account delete: $e");
      }
      // 3. Clear secure storage tokens for all connected clouds
      try {
        await secureStorage.delete(key: 'od_refresh_token');
        await secureStorage.delete(key: 'dbx_refresh_token');
        await secureStorage.delete(key: 'box_refresh_token');
        await secureStorage.delete(key: '${widget.firebaseUser.uid}_pcloud_access_token');
        await secureStorage.delete(key: '${widget.firebaseUser.uid}_pcloud_location_id'); // FIX: also clear region
        await secureStorage.delete(key: '${widget.firebaseUser.uid}_mega_session_id');
      } catch (e) {
        debugPrint('Error clearing secure storage on account delete: $e');
      }
      // 4. Sign out from Firebase/Google
      await FirebaseAuth.instance.signOut();
      try {
        await googleSignIn.signOut(); // <-- USE GLOBAL INSTANCE
      } catch (e) {
        debugPrint("Error during Google Sign Out (normal): $e");
      }
      // Pop the loading dialog
      if (mounted) Navigator.pop(context); // Close loading dialog
      // The AuthGate will automatically handle navigation to the LoginPage.
      // We don't need to pop the drawer or anything else.
    } catch (e) {
      // Pop the loading dialog
      if (mounted) Navigator.pop(context); // Close loading dialog
      // Show an error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error deleting account: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Lifecycle cleanup
    NotificationService.onNotificationTap = null;
    _assetsChangedDebounce?.cancel();
    _filterDebounce?.cancel();
    _pCloudAuthSub?.cancel(); // FIX: Cancel pending pCloud OAuth listener on dispose
    _iapSubscription.cancel();
    _searchController.dispose();
    _filesSearchController.dispose(); // Bug Fix 6
    _userDocSubscription?.cancel();
    super.dispose();
  }
  // --- App Lifecycle: Auto-start background scan when app is minimized/closed/resumed ---
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // User opened or resumed app — scan new/unscanned photos (throttled: max once per 30 min)
      // Face scanning works on local photos for all users, no Pro gate needed.
      if (_driveItems.isNotEmpty) {
        ForegroundScanner.shouldStartScan().then((canScan) {
          if (canScan) _startBackgroundAiScan();
        });
      }
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached || state == AppLifecycleState.hidden) {
      try {
        _userDocRef.set({
          'lastSeenAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint("Error updating lastSeenAt: $e");
      }
      if (state == AppLifecycleState.paused) {
        // App is minimized — trigger WorkManager scan immediately
        _scheduleBackgroundScan();
      }
    }
  }

  /// Schedules a one-time WorkManager task to run face scanning & pHash in
  /// the background whenever the app is minimized or phone is idle.
  void _scheduleBackgroundScan() {
    debugPrint('📱 [App] Scheduling background face & pHash scan via WorkManager...');
    // FIX: Use a fixed task ID (not timestamp-based) so WorkManager can deduplicate.
    // Using a timestamp-based ID created a brand-new task on every provider login,
    // causing the WorkManager queue to accumulate 15+ tasks per session, draining battery.
    // ExistingWorkPolicy.replace cancels any pending task and re-queues a fresh one.
    Workmanager().registerOneOffTask(
      kBackgroundScanTaskId, // fixed ID — deduplicates automatically
      kBackgroundScanTaskName,
      existingWorkPolicy: ExistingWorkPolicy.replace,
      constraints: Constraints(
        networkType: NetworkType.notRequired,
        requiresBatteryNotLow: true,
      ),
    );
    // Schedule daily "On This Day" memories check.
    // Runs once per day at ~9 AM. WorkManager fires it within a 15-min window.
    // existingWorkPolicy.keep means we won't re-schedule if already queued today.
    Workmanager().registerPeriodicTask(
      kMemoriesTaskId,
      kMemoriesTaskName,
      frequency: const Duration(hours: 24),
      initialDelay: _initialDelayUntil9AM(),
      existingWorkPolicy: ExistingWorkPolicy.keep, // FIX: workmanager 0.6.0 uses ExistingWorkPolicy (not ExistingPeriodicWorkPolicy)
      constraints: Constraints(
        networkType: NetworkType.notRequired,
      ),
    );
    _bgScanScheduled = true;
  }
  /// Calculates how long until 9:00 AM tomorrow (or today if it's before 9 AM).
  Duration _initialDelayUntil9AM() {
    final now = DateTime.now();
    var target = DateTime(now.year, now.month, now.day, 9, 0);
    if (now.isAfter(target)) {
      target = target.add(const Duration(days: 1));
    }
    return target.difference(now);
  }
  /// Called when user taps a local notification.
  /// Routes payloads to the correct page.
  void _handleNotificationTap(String payload) {
    if (!mounted) return;
    if (payload == 'open_duplicates') {
      debugPrint('[App] Notification tap: opening Duplicates page');
      // Use the same pattern as the existing DuplicatesPage call site at ~line 7255
      final imageItemsOnly = _driveItems.where((i) => !i.isVideo && !i.isFolder).toList();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DuplicatesPage(
            allItems: imageItemsOnly,
            getThumbnailUrl: _getThumbnailUrl,
            getDownloadUrl: _getDownloadUrl,
            onMoveToBin: _moveToBin,
            onFavoriteChanged: (key, isFav) {
              _userDocRef.update({
                'favorites': isFav
                    ? FieldValue.arrayUnion([key])
                    : FieldValue.arrayRemove([key])
              });
            },
            onShowAddToAlbumDialog: _showAddToAlbumDialog,
            oneDriveAccessToken: _oneDriveAccessToken,
            dropboxAccessToken: _dropboxAccessToken,
            boxAccessToken: _boxAccessToken,
            useCaching: _useCaching,
            favorites: _favorites,
            bin: _bin,
          ),
        ),
      );
    } else if (payload.startsWith('open_memories:')) {
      final isoDate = payload.substring('open_memories:'.length);
      debugPrint('[App] Notification tap: opening memories for ');
      try {
        final date = DateTime.parse(isoDate);
        final memoriesItems = _driveItems.where((item) {
          if (item.isFolder || item.created == null) return false;
          final d = item.created!;
          return d.year == date.year && d.month == date.month && d.day == date.day;
        }).toList();
        if (memoriesItems.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Photos from that day are still loading — try again in a moment.'),
          ));
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MemoriesPage(
              items: memoriesItems,
              date: date,
              getThumbnailUrl: _getThumbnailUrl,
              onPhotoTap: (items, index) => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PhotoViewerPage(
                    items: items,
                    initialIndex: index,
                    getThumbnailUrl: _getThumbnailUrl,
                    getDownloadUrl: _getDownloadUrl,
                    favorites: _favorites,
                    bin: _bin,
                    onFavoriteChanged: (key, isFav) {
                      _userDocRef.update({
                        'favorites': isFav
                            ? FieldValue.arrayUnion([key])
                            : FieldValue.arrayRemove([key])
                      });
                    },
                    onMoveToBin: _moveToBin,
                    onAddToAlbum: (item) => _showAddToAlbumDialog([item.getUniqueKey()]),
                    oneDriveAccessToken: _oneDriveAccessToken,
                    dropboxAccessToken: _dropboxAccessToken,
                    boxAccessToken: _boxAccessToken,
                    useCaching: _useCaching,
                  ),
                ),
              ),
            ),
          ),
        );
      } catch (e) {
        debugPrint('[App] Could not parse memories date:  — ');
      }
    }
  }
  // --- Persistence (Local Preferences) ---
  Future<void> _loadCachingPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _useCaching = prefs.getBool('pref_use_caching') ?? true;
      _binDeleteFromCloud = prefs.getBool('pref_bin_delete_from_cloud') ?? false;
    });
  }
  Future<void> _saveCachingPreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pref_use_caching', value);
    setState(() => _useCaching = value);
  }
  Future<void> _saveBinDeletePreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pref_bin_delete_from_cloud', value);
    setState(() => _binDeleteFromCloud = value);
  }
  Future<void> _clearImageCache() async {
    // Show confirmation dialog first
     final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Clear Image Cache?'),
          content: const Text('This will remove locally cached thumbnails and images. They will be re-downloaded when needed.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Clear Cache', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          ],
        ),
      );
      if (confirm != true) return;
      // Close drawer if open
      Navigator.pop(context); // Assumes this was called from the drawer
    try {
      // emptyCache() may throw PathNotFoundException on Samsung/Android 10
      // when the OS has already evicted cache files in the background.
      // We catch file-system errors specifically so they don't crash the app.
      try {
        await DefaultCacheManager().emptyCache();
      } on PathNotFoundException catch (e) {
        // Non-critical: file was already removed by the OS cache eviction
        debugPrint("⚠️ Cache file already removed by OS (non-critical): $e");
      } on FileSystemException catch (e) {
        // Non-critical: any other FS error (permissions, race condition, etc.)
        debugPrint("⚠️ File system error during cache clear (non-critical): $e");
      }
      // Also clear any cached DriveItem URLs
      for (var item in _driveItems) {
         item.thumbnailUrl = null;
         item.downloadUrl = null;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Image cache cleared successfully.')));
        // Trigger UI refresh if needed (e.g., if thumbnails disappear)
        setState(() {});
      }
    } catch (e) {
      debugPrint("Error clearing cache: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error clearing cache: $e')));
      }
    }
  }
/// Prepends the user's UID to a key for secure, isolated storage.
  String _userKey(String key) {
    return '${widget.firebaseUser.uid}_$key';
  }
  // --- Authentication ---
  // --- PASTE THIS REPLACEMENT METHOD ---
  // --- PASTE THIS REPLACEMENT METHOD ---
 // --- PASTE THIS REPLACEMENT METHOD ---
  // --- PASTE THIS REPLACEMENT METHOD ---
// --- PASTE THIS REPLACEMENT METHOD ---
// --- PASTE THIS REPLACEMENT METHOD ---
// ✅ PASTE THIS REPLACEMENT METHOD
 // ✅ REPLACEMENT METHOD: Handles ALL services correctly
// ✅ REPLACEMENT METHOD: Loads tokens into memory before testing connection
  Future<void> _tryAutoLogin() async {
    // 1. ALWAYS Read all tokens first (Do this BEFORE checking connectivity)
    // Read tokens in parallel to reduce KeyStore/KeyChain query latency on startup
    final List<String?> tokens = await Future.wait([
      secureStorage.read(key: _userKey('od_refresh_token')),
      secureStorage.read(key: _userKey('dbx_refresh_token')),
      secureStorage.read(key: _userKey('box_refresh_token')),
      secureStorage.read(key: _userKey('pcloud_access_token')),
      secureStorage.read(key: _userKey('mega_session_id')),
    ]);
    final String? odRefreshToken = tokens[0];
    final String? dbxRefreshToken = tokens[1];
    final String? boxRefreshToken = tokens[2];
    final String? pCloudToken = tokens[3];
    final String? megaSession = tokens[4];
    // 2. Update state so the UI knows we have accounts connected
    // This makes the "Connected" checkmarks appear in the Drawer immediately
    // FIX: Guard with mounted — user may have logged out while SecureStorage was reading.
    if (!mounted) return;
    setState(() {
      _oneDriveRefreshToken = odRefreshToken;
      _dropboxRefreshToken = dbxRefreshToken;
      _boxRefreshToken = boxRefreshToken;
      _pCloudAccessToken = pCloudToken;
      _megaSessionId = megaSession;
    });
    // 3. Check connectivity
    final connectivityResult = await Connectivity().checkConnectivity();
    final isOffline = connectivityResult.contains(ConnectivityResult.none);
    if (isOffline) {
      debugPrint("⚠️ Device is offline. Using cached tokens and syncing local photos.");
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _statusMessage = "Offline. Showing cached & local photos.";
      });
      await _fetchAllPhotos(firstPage: true);
      if (mounted) _updateFilteredItems();
      return;
    }
    // 4. Check if we have ANY accounts to sync
    if (odRefreshToken == null && dbxRefreshToken == null && boxRefreshToken == null && pCloudToken == null && megaSession == null) {
      await _fetchAllPhotos(firstPage: true);
      if (mounted) _updateFilteredItems();
      return;
    }
    if (!mounted) return;
    setState(() {
      if (_driveItems.isEmpty) {
        _isLoading = true;
      }
      _statusMessage = 'Syncing changes...';
      _oneDriveError = false;
      _dropboxError = false;
      _boxError = false;
      _pCloudError = false;
      _megaError = false;
    });
    bool anySuccess = false;
    // --- OneDrive ---
    if (odRefreshToken != null) {
      try {
        final TokenResponse? result = await appAuth.token(TokenRequest(
          oneDriveClientId,
          redirectUri,
          refreshToken: odRefreshToken,
          serviceConfiguration: oneDriveServiceConfiguration,
          scopes: oneDriveScope.split(' '),
        ));
        if (result != null) {
          _onLoginSuccessOneDrive(result);
          anySuccess = true;
        }
      } catch (e) {
        debugPrint('OneDrive auto-login error: $e');
        if (!isOffline && mounted) setState(() => _oneDriveError = true);
      }
    }
    // --- Dropbox ---
    if (dbxRefreshToken != null) {
      try {
        final refreshed = await _refreshAccessToken(PhotoSource.dropbox);
        if (refreshed) anySuccess = true;
      } catch (e) {
        debugPrint('Dropbox auto-login error: $e');
        if (!isOffline && mounted) setState(() => _dropboxError = true);
      }
    }
    // --- Box ---
    if (boxRefreshToken != null) {
      try {
        final refreshed = await _refreshAccessToken(PhotoSource.box);
        if (refreshed) anySuccess = true;
      } catch (e) {
        debugPrint('Box auto-login error: $e');
        if (!isOffline && mounted) setState(() => _boxError = true);
      }
    }
    // --- pCloud ---
    if (pCloudToken != null) {
      if (!mounted) return;
      setState(() {
        _pCloudAccessToken = pCloudToken;
        _pCloudError = false;
      });
      anySuccess = true;
      debugPrint('[pCloud] ✅ Token restored from secure storage.');

      // Validate & update region in background without deleting user credentials.
      // FIX: Only set _pCloudError on explicit server-side auth rejection (result 1000/2094).
      // Network timeouts / transient errors must NOT set _pCloudError, or the fetch is skipped.
      // _validatePCloudToken already returns true on network errors, so this is correct.
      _validatePCloudToken(pCloudToken).then((isValid) {
        // isValid == false only when BOTH US and EU servers explicitly reject the token.
        // Don't set _pCloudError here — the fetch already started and may succeed.
        // If it fails with auth error (result 1000/2094), _fetchPCloudPhotos sets the flag.
        if (!isValid) {
          debugPrint('[pCloud] ⚠️ Token reported invalid by both servers — will show error after next fetch attempt.');
        }
      }).catchError((e) {
        debugPrint('[pCloud] Background validation warning (non-fatal): $e');
      });
    }
    // --- Mega ---
    if (megaSession != null) {
      if (!mounted) return;
      setState(() {
        _megaSessionId = megaSession;
      });
      anySuccess = true;
    }
    // 5. Fetch Photos (Local is always fetched regardless of cloud login success)
    final bool itemsWereFound = await _fetchAllPhotos(firstPage: true);
    // FIX: Guard mounted after the longest async call in this method.
    // _fetchAllPhotos can take several seconds; widget may be disposed by then.
    if (!mounted) return;
    if (itemsWereFound) {
      setState(() => _statusMessage = "");
    } else if (!anySuccess && !isOffline) {
      _onLoginFail('Session restore failed. Please log in again.');
    }
    _updateFilteredItems();
  }
  Future<void> _logout() async {
    analytics.logEvent(name: 'logout');
    if (!mounted) return;

    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out from Cloud Photos and all connected services?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Logout', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Show loading dialog — widget is still mounted here so this is safe.
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => const PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Logging out...'),
            ],
          ),
        ),
      ),
    );

    try {
      // 1. Clear ALL cloud tokens in parallel FIRST.
      //    Tokens must be gone BEFORE signOut() so that _tryAutoLogin()
      //    on the fresh anonymous session cannot reconnect cloud accounts.
      await Future.wait([
        secureStorage.delete(key: _userKey('od_refresh_token')),
        secureStorage.delete(key: _userKey('dbx_refresh_token')),
        secureStorage.delete(key: _userKey('box_refresh_token')),
        secureStorage.delete(key: _userKey('pcloud_access_token')),
        secureStorage.delete(key: _userKey('pcloud_location_id')),
        secureStorage.delete(key: _userKey('mega_session_id')),
        secureStorage.delete(key: _userKey('mega_master_key')),
        secureStorage.delete(key: _userKey('mega_derived_key')),
      ]);

      // 2. Clear SharedPrefs item cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userKey('cached_drive_items_list'));

      // 3. Clear Isar records. Non-critical (new anon user has a different UID
      //    so their data is isolated), so we cap at 5 s to avoid blocking UI.
      try {
        await assetRepository
            .deleteAllForUser(widget.firebaseUser.uid)
            .timeout(const Duration(seconds: 5));
      } catch (e) {
        debugPrint('[Logout] Isar cleanup error (non-critical): $e');
      }

      // 4. Sign Google out (non-fatal if it fails)
      try {
        await googleSignIn.signOut();
      } catch (e) {
        debugPrint('[Logout] Google signOut error (non-fatal): $e');
      }

    } catch (e) {
      debugPrint('[Logout] Error: $e');
      // Dismiss dialog — widget is still mounted in the error path
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logout failed: $e')),
        );
      }
      return;
    }

    // 5. Dismiss dialog WHILE widget is still mounted (we have not called
    //    signOut() yet, so the widget tree is intact and context is valid).
    if (mounted) Navigator.of(context, rootNavigator: true).pop();

    // 6. Reset in-memory state before the widget is disposed
    if (mounted) {
      setState(() {
        _oneDriveAccessToken = null;
        _oneDriveRefreshToken = null;
        _dropboxAccessToken = null;
        _dropboxRefreshToken = null;
        _boxAccessToken = null;
        _boxRefreshToken = null;
        _oneDriveError = false;
        _dropboxError = false;
        _boxError = false;
        _pCloudAccessToken = null;
        _pCloudError = false;
        _megaSessionId = null;
        _megaError = false;
        _hasGoogleDriveAccess = false;
        _driveItems = [];
        _favorites = {};
        _bin = {};
        _albums = {};
        _albumCovers = {};
        _statusMessage = '';
        _isSelecting = false;
        _selectedItemKeys = {};
        _searchQuery = '';
        _searchController.clear();
        _currentSourceFilter = FilterSource.all;
        _currentTypeFilter = FilterType.all;
        _currentSortOption = SortOption.newestFirst;
      });
      _updateFilteredItems();
    }

    // 7. Sign out of Firebase LAST.
    //    All tokens are already gone, so _tryAutoLogin() on the new anonymous
    //    session will find nothing and won't reconnect any cloud service.
    //    This triggers AuthGate's userChanges() stream → signInAnonymously() →
    //    fresh CloudPhotosPage. The dialog is already dismissed so nothing hangs.
    await FirebaseAuth.instance.signOut();

    debugPrint('[Logout] Complete');
  }
  // --- PASTE THIS REPLACEMENT METHOD ---
 // ✅ PASTE THIS REPLACEMENT METHOD
 // --- PASTE THIS REPLACEMENT METHOD in _CloudPhotosPageState ---
Future<void> _updateFilteredItems() async {
  // PERF: debounce - coalesce rapid calls into one execution per 200ms
  // (e.g. multiple setState in quick succession after cache load, Firestore update)
  _filterDebounce?.cancel();
  final completer = Completer<void>();
  _filterDebounce = Timer(const Duration(milliseconds: 200), () async {
    if (mounted) await _doUpdateFilteredItems();
    if (!completer.isCompleted) completer.complete();
  });
  return completer.future;
}
Future<void> _doUpdateFilteredItems() async {
  String newStatusMessage = '';
  // Set loading state *only* if search query is not empty
  if (_searchQuery.isNotEmpty && !_isAiSearching) {
    setState(() => _isAiSearching = true);
  }
  final query = _searchQuery.toLowerCase().trim();
  // Keys matched by AI smart search (strict tag/object match from Isar)
  Set<String> aiMatchedKeys = {};
  // Keys matched by filename (for any photo whose name contains the query)
  Set<String> nameMatchedKeys = {};
  // 1. Run strict AI smart search - only returns items where AI tags/objects match
  if (query.isNotEmpty) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      try {
        final searchResults = await assetRepository.searchByTagsStrict(userId, query);
        aiMatchedKeys = searchResults.map((r) => r.uniqueKey.replaceFirst('$userId::', '')).toSet();
      } catch (e) {
        debugPrint("Error during searchByTagsStrict: $e");
      }
    }
    // 2. Filename search for ALL items (cloud + local, including unscanned)
    for (final item in _driveItems) {
      if (item.name.toLowerCase().contains(query)) {
        nameMatchedKeys.add(item.getUniqueKey());
      }
    }
  }
  // Combined: an item matches if it has a matching AI tag OR a matching filename
  final Set<String> matchedKeys = {...aiMatchedKeys, ...nameMatchedKeys};
  // 2. Generate Error Message (no change)
  final errorServices = [];
  if (_oneDriveError) errorServices.add('OneDrive');
  if (_dropboxError) errorServices.add('Dropbox');
  if (_boxError) errorServices.add('Box'); // ✅ ADD
  if (_pCloudError) errorServices.add('pCloud');
  if (_megaError) errorServices.add('Mega'); // ✅ MEGA
  final connectedServices = [];
  if (_oneDriveAccessToken != null && !_oneDriveError) connectedServices.add('OneDrive');
  if (_dropboxAccessToken != null && !_dropboxError) connectedServices.add('Dropbox');
  //if (_hasGoogleDriveAccess) connectedServices.add('Google Drive');
  if (_boxAccessToken != null && !_boxError) connectedServices.add('Box'); // ✅ ADD
  if (_pCloudAccessToken != null && !_pCloudError) connectedServices.add('pCloud');
  if (_megaSessionId != null && !_megaError) connectedServices.add('Mega'); // ✅ MEGA
  if (errorServices.isNotEmpty) {
    newStatusMessage = "Connection to ${errorServices.join(' & ')} failed. Please reconnect.";
  }
  // --- End Error Message ---
  // 3. Apply sorting (no change)
  List<DriveItem> sortedItems = List<DriveItem>.from(_driveItems);
  sortedItems.sort((a, b) {
    // ... (Your existing sort logic) ...
    switch (_currentSortOption) {
      case SortOption.newestFirst:
        final dateA = (a.created != null && a.created!.year >= 2000) ? a.created : null;
        final dateB = (b.created != null && b.created!.year >= 2000) ? b.created : null;
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1; // Unknown/null dates go last
        if (dateB == null) return -1;
        return dateB.compareTo(dateA);
      case SortOption.oldestFirst:
        final dateA = (a.created != null && a.created!.year >= 2000) ? a.created : null;
        final dateB = (b.created != null && b.created!.year >= 2000) ? b.created : null;
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1; // Unknown/null dates go last
        if (dateB == null) return -1;
        return dateA.compareTo(dateB);
      case SortOption.nameAZ:
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      case SortOption.nameZA:
        return b.name.toLowerCase().compareTo(a.name.toLowerCase());
    }
  });
  // 4. Apply filters (Main change is here)
  setState(() {
    _filteredDriveItems = sortedItems.where((item) { // Filter the sorted list
      final key = item.getUniqueKey();
      if (_bin.contains(key)) return false; // Exclude binned items
      // ✅ MODIFY THIS BLOCK
      if (_currentSourceFilter == FilterSource.oneDrive &&
          item.source != PhotoSource.oneDrive) return false;
      if (_currentSourceFilter == FilterSource.dropbox &&
          item.source != PhotoSource.dropbox) return false;
      if (_currentSourceFilter == FilterSource.googleDrive &&
          item.source != PhotoSource.googleDrive) return false;
      if (_currentSourceFilter == FilterSource.box && // ✅ ADD
          item.source != PhotoSource.box) return false;
      // ✅ END BLOCK
      // ✅ ADD THIS BLOCK:
      if (_currentSourceFilter == FilterSource.pCloud &&
          item.source != PhotoSource.pCloud) return false;
      // ✅ MEGA FILTER:
      if (_currentSourceFilter == FilterSource.mega &&
          item.source != PhotoSource.mega) return false;
      // ✅ LOCAL GALLERY FILTER:
      if (_currentSourceFilter == FilterSource.local &&
          item.source != PhotoSource.local) return false;
      if (_currentTypeFilter == FilterType.photos && item.isVideo)
        return false;
      if (_currentTypeFilter == FilterType.videos && !item.isVideo)
        return false;
      // ✅ MODIFIED Search Filter (queries Isar AssetRecord directly)
      if (query.isNotEmpty) {
        if (!matchedKeys.contains(key)) return false;
      }
      return true; // Passed all filters
    }).toList();
    // 5. Update status message (no change)
    if (_filteredDriveItems.isEmpty) {
        if (_searchQuery.isNotEmpty || _currentSourceFilter != FilterSource.all || _currentTypeFilter != FilterType.all) {
            _statusMessage = 'No items match your search or filters.';
        } else if (newStatusMessage.isNotEmpty && !_isLoading) {
          _statusMessage = newStatusMessage; // Show connection error first
        } 
        // ✅ MODIFY THIS
        else if (_driveItems.isEmpty && !_isLoading && connectedServices.isEmpty && errorServices.isEmpty) {
          _statusMessage = 'Please connect an account from the side menu.';
        } else if (_driveItems.isEmpty && !_isLoading) {
            _statusMessage = 'No photos found in your connected accounts.';
        } else if (_driveItems.isNotEmpty && !_isLoading) {
            _statusMessage = 'No items to display.';
        }
    } else {
        _statusMessage = ''; // Clear status if items are displayed
    }
    // 6. Stop loading spinner
    _isAiSearching = false; 
  });
}
  // --- PASTE THIS REPLACEMENT METHOD ---
  // --- PASTE THIS REPLACEMENT METHOD ---
  // --- PASTE THIS REPLACEMENT METHOD ---
  Future<void> _loginOneDrive({bool fromHomePage = false}) async {
    if (widget.firebaseUser.isAnonymous) {
      _showGoogleSignInRequired();
      return;
    }
    if (_isOneDriveRefreshing || _isDropboxRefreshing) {
      if (mounted && !fromHomePage) { 
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('An authentication process is already in progress. Please wait a moment.'),
          backgroundColor: Colors.orange,
        ));
      }
      return;
    }
    if (!fromHomePage) {
      Navigator.pop(context);
    }
    setState(() {
      _isLoading = false; 
      _statusMessage = 'Redirecting to OneDrive...';
      _oneDriveError = false; 
      _isOneDriveRefreshing = true; // Set the lock
    });
    // --- START OF FIX ---
    bool loginSuccess = false; // 1. Add a success flag
    // --- END OF FIX ---
    try {
      final AuthorizationTokenResponse? result =
          await appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          oneDriveClientId,
          redirectUri,
          serviceConfiguration: oneDriveServiceConfiguration,
          scopes: oneDriveScope.split(' '),
        ),
      );
      if (result != null) {
        _onLoginSuccessOneDrive(result);
        // --- START OF FIX ---
        loginSuccess = true; // 2. Set the flag on success
        // _fetchAllPhotos(firstPage: true); // 3. REMOVE this line
        // --- END OF FIX ---
      } else {
        _onLoginFail('OneDrive login canceled or failed. Please try again.');
        _updateFilteredItems();
      }
    } catch (e) {
      _onLoginFail('OneDrive login error: ${e.toString()}');
      _updateFilteredItems();
    } finally {
      if (mounted) {
        setState(() => _isOneDriveRefreshing = false); // 4. Release the lock
      }
    }
    // --- START OF FIX ---
    // 5. Call _fetchAllPhotos AFTER the lock is released
    if (loginSuccess) {
      _fetchAllPhotos(firstPage: true);
    }
    // --- END OF FIX ---
   }
  // --- PASTE THIS REPLACEMENT METHOD ---
  // --- PASTE THIS REPLACEMENT METHOD ---
  Future<void> _loginDropbox({bool fromHomePage = false}) async {
    if (widget.firebaseUser.isAnonymous) {
      _showGoogleSignInRequired();
      return;
    }
    if (_isOneDriveRefreshing || _isDropboxRefreshing) {
      if (mounted && !fromHomePage) { 
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('An authentication process is already in progress. Please wait a moment.'),
          backgroundColor: Colors.orange,
        ));
      }
      return;
    }
    if (!fromHomePage) {
      Navigator.pop(context);
    }
    setState(() {
      _isLoading = false; 
      _statusMessage = 'Redirecting to Dropbox...';
      _dropboxError = false; 
      _isDropboxRefreshing = true; // Set the lock
    });
    // --- START OF FIX ---
    bool loginSuccess = false; // 1. Add a success flag
    // --- END OF FIX ---
    try {
      final AuthorizationTokenResponse? result =
          await appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          dropboxClientId,
          redirectUri,
          serviceConfiguration: dropboxServiceConfiguration,
          scopes: dropboxScope.split(' '),
          additionalParameters: {'token_access_type': 'offline'},
        ),
      );
      if (result != null) {
        _onLoginSuccessDropbox(result);
        // --- START OF FIX ---
        loginSuccess = true; // 2. Set the flag on success
        // _fetchAllPhotos(firstPage: true); // 3. REMOVE this line
        // --- END OF FIX ---
      } else {
        _onLoginFail('Dropbox login canceled or failed. Please try again.');
        _updateFilteredItems();
      }
    } catch (e) {
      _onLoginFail('Dropbox login error: ${e.toString()}');
      _updateFilteredItems();
    } finally {
      if (mounted) {
        setState(() => _isDropboxRefreshing = false); // 4. Release the lock
      }
    }
    // --- START OF FIX ---
    // 5. Call _fetchAllPhotos AFTER the lock is released
    if (loginSuccess) {
      _fetchAllPhotos(firstPage: true);
    }
    // --- END OF FIX ---
   }
  void _onLoginSuccessOneDrive(TokenResponse result) {
    analytics.logLogin(loginMethod: 'onedrive');
    final newRefreshToken = result.refreshToken ?? _oneDriveRefreshToken;
    setState(() {
      _oneDriveAccessToken = result.accessToken;
      if (newRefreshToken != null) _oneDriveRefreshToken = newRefreshToken;
      _oneDriveError = false; // Clear error on success
    });
    // Securely store the refresh token — never overwrite with null
    if (newRefreshToken != null) {
      secureStorage.write(key: _userKey('od_refresh_token'), value: newRefreshToken);
    }
    debugPrint("OneDrive Login Success");
  }
  void _onLoginSuccessDropbox(TokenResponse result) {
    analytics.logLogin(loginMethod: 'dropbox');
    final newRefreshToken = result.refreshToken ?? _dropboxRefreshToken;
    setState(() {
      _dropboxAccessToken = result.accessToken;
      if (newRefreshToken != null) _dropboxRefreshToken = newRefreshToken;
      _dropboxError = false; // Clear error on success
    });
    // Securely store the refresh token — never overwrite with null
    if (newRefreshToken != null) {
      secureStorage.write(key: _userKey('dbx_refresh_token'), value: newRefreshToken);
    }
    debugPrint("Dropbox Login Success");
  }
  void _onLoginFail(String message) {
     debugPrint("Login Fail: $message");
     if (mounted) {
       setState(() {
        _isLoading = false; // Ensure loading indicator stops
        _statusMessage = message;
        // Don't necessarily set error flags here, _tryAutoLogin handles specific errors
       });
     }
   }
  // --- Data Fetching & Parsing ---
 // ✅ REPLACEMENT METHOD: Correctly detects OneDrive videos
List<DriveItem> _parseOneDriveItems(Map<String, dynamic> jsonResponse) {
  final List<dynamic> items = jsonResponse['value'] ?? [];
  final List<DriveItem> driveItems = [];
  for (var item in items) {
    if (item['id'] != null &&
        item['name'] != null &&
        (item['file'] != null || item['video'] != null)) { // Check for file OR video metadata
      // 1. Determine if it's a video
      final mime = (item['file']?['mimeType'] as String?)?.toLowerCase() ?? '';
      // It is a video if it has the 'video' field OR the mime type starts with 'video/'
      final bool isVideo = item['video'] != null || mime.startsWith('video/');
      final bool isImage = mime.startsWith('image/');
      if (isImage || isVideo) {
        DateTime? created;
        try {
          // Prefer fileSystemInfo/createdDateTime, fallback to createdDateTime
          final createdString = item['fileSystemInfo']?['createdDateTime'] as String?
                               ?? item['createdDateTime'] as String?;
          if (createdString != null) {
            created = DateTime.tryParse(createdString)?.toLocal();
          }
        } catch (e) {
          debugPrint("Error parsing OneDrive created date for ${item['name']}: $e");
        }
        // OneDrive returns sha1Hash as Base64. Normalize to lowercase hex so it
        // matches Box (which returns hex SHA-1) for cross-provider deduplication.
        // quickXorHash is a non-standard algo — keep as-is (only used within OneDrive).
        String? rawContentHash = item['file']?['hashes']?['sha1Hash'] as String?
            ?? item['file']?['hashes']?['quickXorHash'] as String?;
        String? contentHash;
        if (rawContentHash != null) {
          try {
            // Detect if this looks like Base64 (contains +, /, or = padding)
            if (rawContentHash.contains('+') || rawContentHash.contains('/') || rawContentHash.contains('=')) {
              // Base64-encoded SHA-1 → decode to bytes → re-encode as lowercase hex
              final bytes = base64Decode(rawContentHash);
              contentHash = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
            } else {
              contentHash = rawContentHash.toLowerCase();
            }
          } catch (_) {
            contentHash = rawContentHash; // fallback: keep original if decode fails
          }
        }
        driveItems.add(DriveItem(
          id: item['id'],
          name: item['name'],
          source: PhotoSource.oneDrive,
          created: created,
          thumbnailUrl: item['thumbnails']?[0]?['large']?['url'] as String?,
          isVideo: isVideo, // ✅ CRITICAL: Set the isVideo flag!
          contentHash: contentHash,
        ));
      }
    }
  }
  return driveItems;
}
 // ✅ REPLACEMENT METHOD: Correctly detects video extensions
  List<DriveItem> _parseDropboxItems(Map<String, dynamic> jsonResponse) {
    final List<dynamic> items = jsonResponse['entries'] ?? [];
    final List<DriveItem> driveItems = [];
    for (var item in items) {
      final String tag = item['.tag'] ?? '';
      if (tag == 'file') {
        final String name = item['name'] as String? ?? '';
        final String pathLower = item['path_lower'] as String? ?? '';
        // ✅ FIX: Check extensions manually to set the flag
        final lowerName = name.toLowerCase();
        final bool isVideo = lowerName.endsWith('.mp4') || 
                             lowerName.endsWith('.mov') || 
                             lowerName.endsWith('.wmv') ||
                             lowerName.endsWith('.avi');
        final bool isImage = lowerName.endsWith('.jpg') || 
                             lowerName.endsWith('.jpeg') || 
                             lowerName.endsWith('.png') || 
                             lowerName.endsWith('.heic') ||
                             lowerName.endsWith('.webp');
        if (pathLower.isNotEmpty && (isImage || isVideo)) {
          DateTime? created;
          try {
            final clientModified = item['client_modified'] as String?;
            if (clientModified != null) {
              created = DateTime.tryParse(clientModified)?.toLocal();
            }
          } catch (e) {
            debugPrint("Error parsing date: $e");
          }
          final contentHash = item['content_hash'] as String?;
          driveItems.add(DriveItem(
            id: pathLower,
            name: name,
            source: PhotoSource.dropbox,
            created: created,
            isVideo: isVideo, // ✅ Pass the calculated flag
            contentHash: contentHash,
          ));
        }
      }
    }
    return driveItems;
  }
Future<bool> _fetchAllPhotos({bool firstPage = false}) async {
  if (!firstPage) {
    if (_isLoadingMore || !_hasMoreLocal) return false;
    _isLoadingMore = true;
  }
  try {
    final connectivityResult = await Connectivity().checkConnectivity();
    final isOffline = connectivityResult.contains(ConnectivityResult.none);
    if (isOffline) {
      if (firstPage) {
        setState(() {
          if (_driveItems.isEmpty) {
            _isLoading = true;
          }
          _statusMessage = "Offline. Updating local gallery...";
        });
      }
      final localItems = await _fetchLocalPhotos(firstPage: firstPage);
      if (!mounted) return false;
      setState(() {
        final itemMap = {for (var item in _driveItems) item.getUniqueKey(): item};
        for (var item in localItems) {
          itemMap[item.getUniqueKey()] = item;
        }
        _driveItems = itemMap.values.toList();
        if (firstPage) {
          _statusMessage = "Offline. Showing local & cached photos.";
        }
      });
      await _attachTagsToDriveItems();
      await _updateFilteredItems();
      return localItems.isNotEmpty;
    }
    if (firstPage) {
      setState(() {
        // FIX: Only show loader if we have NO photos (Background sync)
        if (_driveItems.isEmpty) {
           _isLoading = true;
        }
        _statusMessage = 'Syncing your gallery...';
        // ⚠️ CRITICAL FIX: Don't wipe the list if we have cached items!
        // Only wipe if caching is OFF or if the list is actually empty.
        if (!_useCaching || _driveItems.isEmpty) {
           _driveItems = []; 
        }
        _dropboxCursor = null;
        _hasMoreDropbox = true;
        _oneDriveError = false;
        _dropboxError = false;
        _boxError = false;
        _pCloudError = false;
        _megaError = false;
      });
    }
    // Run all fetches in parallel
    final results = await Future.wait([
      if (firstPage && _oneDriveAccessToken != null && !_oneDriveError)
        _fetchOneDrivePhotos(),
      if (_dropboxAccessToken != null && !_dropboxError && (firstPage || _hasMoreDropbox))
        _fetchDropboxPhotos(firstPage: firstPage),
      if (firstPage && _boxAccessToken != null && !_boxError)
        _fetchBoxPhotos(),
      // ✅ ADDED PCLOUD HERE
      if (firstPage && _pCloudAccessToken != null && !_pCloudError)
        _fetchPCloudPhotos(),
      // ✅ ADDED MEGA HERE
      if (firstPage && _megaSessionId != null && !_megaError)
        _fetchMegaPhotos(),
      // ✅ ADDED LOCAL GALLERY HERE
      if (firstPage || _hasMoreLocal)
        _fetchLocalPhotos(firstPage: firstPage),
    ]);
    final List<DriveItem> allNewItems = [];
    for (final result in results) {
      // Safe cast because all functions now return Future<List<DriveItem>>
      allNewItems.addAll(result as List<DriveItem>);
    }
    if (!mounted) return false;
    bool itemsFound = false;
    setState(() {
      final itemMap = {for (var item in _driveItems) item.getUniqueKey(): item};
      for (var item in allNewItems) {
        itemMap[item.getUniqueKey()] = item;
      }
      _driveItems = itemMap.values.toList();
      itemsFound = _driveItems.isNotEmpty;
    });
    await _attachTagsToDriveItems();
    await _updateFilteredItems();
    if (firstPage) {
      await _saveItemsToLocalCache(); // ✅ FIX 1: Must await so items are in DB before AI scan queries them
    }
    if (firstPage && _isPro) {
      _startBackgroundAiScan();
    }
    return itemsFound;
  } finally {
    if (mounted) {
      setState(() {
        if (firstPage) {
          _isLoading = false;
        }
        _isLoadingMore = false;
      });
    }
  }
}
/*
  // ... (Your existing _fetchOneDrivePhotos is fine) ...
  // ... (Your existing _fetchDropboxPhotos is fine) ...
  // ✅ PASTE THIS NEW METHOD
  Future<List<DriveItem>> _fetchGoogleDrivePhotos() async {
    if (!_hasGoogleDriveAccess) return [];
    debugPrint("Fetching Google Drive photos...");
    final String? token = await _getGoogleAuthToken();
    if (token == null) {
      debugPrint("Google Drive fetch failed: No auth token");
      return [];
    }
    final headers = {'Authorization': 'Bearer $token'};
    // This query finds all image or video files that are not in the trash.
    const String query = "(mimeType contains 'image/' or mimeType contains 'video/') and trashed = false";
    // This requests *only* the fields we need. This is critical for performance.
    const String fields = "nextPageToken, files(id, name, createdTime, thumbnailLink)";
    final uri = Uri.parse(
        '$googleDriveApiBase/files?q=${Uri.encodeComponent(query)}&fields=${Uri.encodeComponent(fields)}&pageSize=100');
    try {
      final response = await http.get(uri, headers: headers);
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        // TODO: Handle pagination using data['nextPageToken']
        debugPrint("Google Drive fetch successful.");
        return _parseGoogleDriveItems(data);
      } else {
        debugPrint('Google Drive API error: ${response.statusCode} - ${response.body}');
        if (response.statusCode == 401 || response.statusCode == 403) {
          if (mounted) setState(() => _hasGoogleDriveAccess = false); // Permission lost
          _updateFilteredItems();
        }
        return [];
      }
    } catch (e) {
      debugPrint('Google Drive fetch exception: $e');
      return [];
    }
  }
  // ... (Your existing _parseOneDriveItems is fine) ...
  // ... (Your existing _parseDropboxItems is fine) ...
  // ✅ PASTE THIS NEW METHOD
  // ... (inside _CloudPhotosPageState) ...
  // ✅ PASTE THIS REPLACEMENT METHOD
  List<DriveItem> _parseGoogleDriveItems(Map<String, dynamic> jsonResponse) {
    final List<dynamic> items = jsonResponse['files'] ?? [];
    final List<DriveItem> driveItems = [];
    for (var item in items) {
      if (item['id'] != null && item['name'] != null) {
        DateTime? created;
        try {
          final createdString = item['createdTime'] as String?;
          if (createdString != null) {
            created = DateTime.tryParse(createdString)?.toLocal();
          }
        } catch (e) {
          debugPrint("Error parsing Google Drive created date for ${item['name']}: $e");
        }
        driveItems.add(DriveItem(
          id: item['id'],
          name: item['name'],
          source: PhotoSource.googleDrive,
          created: created,
          // --- START OF FIX ---
          // Modify thumbnailLink to request a larger size (e.g., 800px)
          // Default is =s220. This gives us a better source for the thumbnail.
          thumbnailUrl: (item['thumbnailLink'] as String?)?.replaceAll('=s220', '=s800'),
          // --- END OF FIX ---
        ));
      }
    }
    // ✅ ADD THIS LINE
    debugPrint("Parsed ${driveItems.length} Google Drive items.");
    return driveItems;
  }
*/
  // ✅ PASTE THESE 2 NEW METHODS
  /// Fetches files from Box API using search
  Future<List<DriveItem>> _fetchBoxPhotos() async {
    if (_boxAccessToken == null || _boxError) return [];
    debugPrint("Fetching Box photos...");
    // Search for common image and video file extensions
    const String extensions = 'jpg,jpeg,png,gif,heic,webp,mp4,mov,wmv';
    // Request specific fields to minimize response size
    const String fields = 'id,name,created_at,type,sha1';
    // ✅ --- FIX ---
    // The Box API requires a query, but doesn't allow an empty string.
    // Let's try using a wildcard asterisk (*) to search for everything,
    // which will then be filtered by our file_extensions.
    final uri = Uri.parse(
        '$boxApiBase/search?query=20&file_extensions=$extensions&type=file&fields=$fields&limit=202');
    // ✅ --- END FIX ---
    try {
      // Use the authenticated helper
      final response = await _authenticatedGet(uri, PhotoSource.box);
      if (response.statusCode == 200) {
        // ✅ ADD THIS LINE
        debugPrint("Box JSON Response: ${response.body}");
        final Map<String, dynamic> data = json.decode(response.body);
        debugPrint("Box fetch successful.");
        // TODO: Handle pagination using data['offset'] and data['total_count']
        return _parseBoxItems(data);
      } else {
        debugPrint('Box API error: ${response.statusCode} - ${response.body}');
        if (response.statusCode == 401 || response.statusCode == 403) {
          if (mounted) setState(() => _boxError = true); // Permission lost
          _updateFilteredItems();
        }
        return [];
      }
    } catch (e) {
      debugPrint('Box fetch exception: $e');
      if (mounted) {
        setState(() => _boxError = true);
        _updateFilteredItems();
      }
      return [];
    }
  }
  /// Parses the JSON response from Box search
 // ✅ REPLACEMENT METHOD: Checks name for video extensions
  List<DriveItem> _parseBoxItems(Map<String, dynamic> jsonResponse) {
    final List<dynamic> items = jsonResponse['entries'] ?? [];
    final List<DriveItem> driveItems = [];
    for (var item in items) {
      if (item['type'] == 'file' && item['id'] != null && item['name'] != null) {
        DateTime? created;
        try {
          final createdString = item['created_at'] as String?;
          if (createdString != null) {
            created = DateTime.tryParse(createdString)?.toLocal();
          }
        } catch (e) {
          debugPrint("Error parsing Box date: $e");
        }
        final name = item['name'] as String;
        final lowerName = name.toLowerCase();
        // ✅ FIX: Determine isVideo based on name
        final bool isVideo = lowerName.endsWith('.mp4') || 
                             lowerName.endsWith('.mov') || 
                             lowerName.endsWith('.wmv') ||
                             lowerName.endsWith('.avi');
        // Box returns SHA-1 as lowercase hex — normalize to ensure consistent casing.
        final contentHash = (item['sha1'] as String?)?.toLowerCase();
        driveItems.add(DriveItem(
          id: item['id'],
          name: name,
          source: PhotoSource.box,
          created: created,
          isVideo: isVideo, // ✅ Pass true for videos
          contentHash: contentHash,
        ));
      }
    }
    debugPrint("Parsed ${driveItems.length} Box items.");
    return driveItems;
  }
// ... (rest of class) ...
  Future<List<DriveItem>> _fetchOneDrivePhotos() async {
  if (_oneDriveAccessToken == null) return [];
  debugPrint("Fetching OneDrive photos...");
  final Set<String> allItemIds = {};
  final List<DriveItem> allItems = [];
  // Define which fields and formats to include
  final selectFields = "id,name,file,video,createdDateTime,fileSystemInfo,thumbnails";
  final extensions = [
    '.jpg', '.jpeg', '.png', '.gif', '.mp4', '.mov', '.wmv', '.heic', '.webp'
  ];
  try {
    // ✅ This is the patch section you add before the main query
   final driveResponse = await _authenticatedGet( // <--- USE YOUR HELPER
      Uri.parse('https://graph.microsoft.com/v1.0/me/drive/root/children?\$select=$selectFields'),
      PhotoSource.oneDrive, // <--- PASS THE SOURCE
      // No headers needed, helper adds them
    );
    if (driveResponse.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(driveResponse.body);
      final List<DriveItem> items = _parseOneDriveItems(data);
      allItems.addAll(items);
    } else {
      debugPrint('Initial OneDrive fetch failed: ${driveResponse.statusCode}');
    }
    // Continue fetching for each file type if necessary
    for (String ext in extensions) {
      if (!mounted || _oneDriveError) break;
      final query =
          "https://graph.microsoft.com/v1.0/me/drive/root/search(q='$ext')?\$select=$selectFields";
      final response =
          await _authenticatedGet(Uri.parse(query), PhotoSource.oneDrive);
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<DriveItem> items = _parseOneDriveItems(data);
        for (var item in items) {
          if (!allItemIds.contains(item.id)) {
            allItemIds.add(item.id);
            allItems.add(item);
          }
        }
      } else {
        debugPrint(
            'OneDrive fetch error for $ext: ${response.statusCode} - ${response.body}');
      }
    }
    debugPrint("✅ OneDrive fetch finished. Found ${allItems.length} items.");
    return allItems;
  } catch (e) {
    debugPrint('❌Å’ OneDrive fetch exception: $e');
    if (mounted) {
      setState(() => _oneDriveError = true);
      _updateFilteredItems();
    }
    return [];
  }
}
   Future<List<DriveItem>> _fetchDropboxPhotos(
      {bool firstPage = false}) async {
        if (_dropboxAccessToken == null) return []; 
         debugPrint("Fetching Dropbox photos... First Page: $firstPage");
   // ✅ PASTE THIS CORRECTION
    // --- START OF FIX ---
    // Check for null cursor AND hasMore flag
    if (!firstPage && (!_hasMoreDropbox || _dropboxCursor == null)) {
    // --- END OF FIX ---
       debugPrint("Dropbox: No more items or null cursor, skipping continue fetch.");
       return [];
    }
    final headers = {
      'Content-Type': 'application/json',
      // Auth header is added by _authenticatedPost
    };
    final String url = firstPage
        ? '$dropboxApiBase/files/list_folder'
        : '$dropboxApiBase/files/list_folder/continue';
    final String body = firstPage
        ? json.encode({
            'path': '', 
            'recursive': true, 
            'limit': 200, 
            'include_media_info': false, 
            'include_deleted': false, 
          })
        : json.encode({'cursor': _dropboxCursor}); 
    try {
      // --- REPLACED http.post with _authenticatedPost ---
      final response = await _authenticatedPost(Uri.parse(url), PhotoSource.dropbox,
          headers: headers, body: body);
      if (response.statusCode == 200) {
        // ... (same parsing logic as before)
        final Map<String, dynamic> data = json.decode(response.body);
        final String? newCursor = data['cursor'] as String?;
        final bool hasMore = data['has_more'] as bool? ?? false;
        _dropboxCursor = newCursor;
        _hasMoreDropbox = hasMore;
        final items = _parseDropboxItems(data);
        debugPrint("Dropbox Fetch successful. Found ${items.length} items. Has More: $_hasMoreDropbox");
        return items;
      } 
      // --- 401 IS HANDLED AUTOMATICALLY ---
      else {
        debugPrint('Dropbox API error: ${response.statusCode} - ${response.body}');
         _hasMoreDropbox = false;
         if (mounted) setState(() => _dropboxError = true); 
         _updateFilteredItems();
        return [];
      }
    } catch (e) {
      debugPrint('Dropbox fetch exception (likely from refresh failure): $e');
      if (mounted) {
         setState(() {
            _dropboxError = true; 
            _hasMoreDropbox = false; 
         });
         _updateFilteredItems();
      }
      return [];
    }
   }
// ✅ AUTO-SAVER: Saves the list 3 seconds after the last change
  void _scheduleCacheSave() {
    if (!_useCaching) return;
    // Cancel previous timer if it's running (reset the clock)
    if (_cacheSaveTimer?.isActive ?? false) _cacheSaveTimer!.cancel();
    // Start a new timer
    _cacheSaveTimer = Timer(const Duration(seconds: 3), () {
      _saveItemsToLocalCache();
    });
  }
  // --- Thumbnail & Download URL Fetching ---
  // Improved error handling and token checking
 // --- PASTE THIS REPLACEMENT METHOD ---
 // ... (inside _CloudPhotosPageState) ...
Timer? _cacheSaveTimer; // ✅ For debouncing saves
 // --- PASTE THIS REPLACEMENT METHOD ---
// ✅ PASTE THIS REPLACEMENT METHOD
  Future<String?> _getThumbnailUrl(DriveItem item) async {
    if (item.source == PhotoSource.local) {
      return item.id;
    }
    // 1. FAST PATH: Return Base64 cache (Box/Google Drive)
    // If we have the image data saved, return it immediately.
    if (item.cachedBase64Thumbnail != null &&
        item.cachedBase64Thumbnail!.isNotEmpty) {
      return item.cachedBase64Thumbnail;
    }
    // 2. FAST PATH: Return URL cache (OneDrive/Dropbox/pCloud)
    // ✅ CRITICAL FIX: Return the URL even if we are offline or token is null.
    // CachedNetworkImage will use this URL to find the file on your phone's disk.
    if (item.thumbnailUrl != null && item.thumbnailUrl!.isNotEmpty) {
      // If it's a data URI (Dropbox sometimes), always return it
      if (item.thumbnailUrl!.startsWith('data:image')) {
        return item.thumbnailUrl;
      }
      // For standard URLs (OneDrive, pCloud, etc.), return them so cache works
      return item.thumbnailUrl;
    }
    // 3. STOP if we are offline and have no cache
    // Only check connectivity if we truly have NOTHING to show
    if (item.source == PhotoSource.oneDrive &&
        (_oneDriveAccessToken == null || _oneDriveError)) return null;
    if (item.source == PhotoSource.dropbox &&
        (_dropboxAccessToken == null || _dropboxError)) return null;
    //if (item.source == PhotoSource.googleDrive && !_hasGoogleDriveAccess) return null;
    if (item.source == PhotoSource.box &&
        (_boxAccessToken == null || _boxError)) return null;
    // FIX: Guard pCloud — was missing, causing futile API calls when disconnected
    if (item.source == PhotoSource.pCloud &&
        (_pCloudAccessToken == null || _pCloudError)) return null;
    String? url;
    try {
    /*  if (item.source == PhotoSource.googleDrive) {
        final String? gdriveThumbUrl = item.thumbnailUrl; // This is the API link
        if (gdriveThumbUrl == null) return null;
        final String? token = await _getGoogleAuthToken();
        if (token == null) return null;
        final response = await http.get(
          Uri.parse(gdriveThumbUrl),
          headers: {'Authorization': 'Bearer $token'},
        ).timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          final base64Image = base64Encode(response.bodyBytes);
          url = 'data:image/jpeg;base64,$base64Image';
          item.cachedBase64Thumbnail = url; // Save to memory
          _scheduleCacheSave(); // ✅ Save to disk!
        }
      }*/
       if (item.source == PhotoSource.box) {
        url = await _getBoxThumbnailUrl(item.id);
        if (url != null) {
          item.cachedBase64Thumbnail = url; // Save to memory
          _scheduleCacheSave(); // ✅ Save to disk!
        }
      }
      // ... OneDrive / Dropbox Fetch Logic ...
      else if (item.isVideo && item.source == PhotoSource.oneDrive) {
        url = await _getOneDriveThumbnailUrl(item.id);
      } else if (item.isVideo && item.source == PhotoSource.dropbox) {
        url = await _getDropboxThumbnailUrl(item.id, isVideo: true);
      } else if (item.source == PhotoSource.oneDrive) {
        url = await _getOneDriveThumbnailUrl(item.id);
      } else if (item.source == PhotoSource.dropbox) { 
        url = await _getDropboxThumbnailUrl(item.id);
      } else if (item.source == PhotoSource.pCloud) {
        url = await _getPCloudThumbnailUrl(item.id, isVideo: item.isVideo);
        // Fallback to full download URL ONLY for non-video photos if thumbnail generation failed
        if (url == null && !item.isVideo) {
          url = await _getDownloadUrl(item);
        }
      }
    } catch (e) {
      debugPrint("Error fetching thumbnail for ${item.name}: $e");
      return null;
    }
    // 4. Update the item and SAVE
    if (url != null) {
      // Don't overwrite GDrive/Box URLs as they use cachedBase64Thumbnail
      if (item.source != PhotoSource.googleDrive && item.source != PhotoSource.box) {
         item.thumbnailUrl = url;
         _scheduleCacheSave(); // ✅ Save fresh links to disk!
      }
    }
    return url;
  }
// ... (rest of class) ...
// --- PASTE THIS REPLACEMENT METHOD ---
// ✅ PASTE THIS REPLACEMENT METHOD
Future<String?> _getDownloadUrl(DriveItem item) async {
    if (item.source == PhotoSource.local) {
      return item.id;
    }
    // 1. FAST PATH: Return cached URL immediately
    if (item.downloadUrl != null && item.downloadUrl!.isNotEmpty) {
      return item.downloadUrl;
    }
    // 2. TOKEN CHECKS: Only fail if we are disconnected AND have no URL
    if (item.source == PhotoSource.oneDrive &&
        (_oneDriveAccessToken == null || _oneDriveError)) return null;
    if (item.source == PhotoSource.dropbox &&
        (_dropboxAccessToken == null || _dropboxError)) return null;
    if (item.source == PhotoSource.box && 
        (_boxAccessToken == null || _boxError)) return null;
    if (item.source == PhotoSource.pCloud &&
        (_pCloudAccessToken == null || _pCloudError)) return null;
    if (item.source == PhotoSource.mega &&
        (_megaSessionId == null || _megaError)) return null;
    String? url;
    try {
      // 3. FETCH LOGIC — provider-specific
      if (item.source == PhotoSource.box) {
        url = '$boxApiBase/files/${item.id}/content';
      } else if (item.source == PhotoSource.mega) {
        url = await _getMegaDownloadUrl(item.id);
      } else if (item.source == PhotoSource.oneDrive) {
        url = await _getOneDriveDownloadUrl(item.id);
      } else if (item.source == PhotoSource.pCloud) {
        // FIX: pCloud needs getfilelink API, NOT the Dropbox endpoint
        // getfilelink returns temporary CDN hosts + path that we combine into a URL
        final locationId = await secureStorage.read(key: _userKey('pcloud_location_id'));
        final primaryHost = (locationId == '2') ? 'eapi.pcloud.com' : 'api.pcloud.com';
        final fallbackHost = (locationId == '2') ? 'api.pcloud.com' : 'eapi.pcloud.com';

        Future<Map<String, dynamic>?> fetchLink(String host) async {
          try {
            final resp = await http.get(
              Uri.https(host, '/getfilelink', {
                'fileid': item.id,
                'access_token': _pCloudAccessToken ?? '',
              }),
            ).timeout(const Duration(seconds: 15));
            return json.decode(resp.body) as Map<String, dynamic>?;
          } catch (_) {
            return null;
          }
        }

        Map<String, dynamic>? data = await fetchLink(primaryHost);
        if (data == null || data['result'] == 2000) {
          final fallbackData = await fetchLink(fallbackHost);
          if (fallbackData != null && fallbackData['result'] == 0) {
            data = fallbackData;
            final correctLoc = fallbackHost.contains('eapi') ? '2' : '1';
            await secureStorage.write(key: _userKey('pcloud_location_id'), value: correctLoc);
          }
        }

        if (data != null && data['result'] == 0) {
          final hosts = data['hosts'] as List?;
          final path = data['path'] as String?;
          if (hosts != null && hosts.isNotEmpty && path != null) {
            url = 'https://${hosts[0]}$path';
          }
        } else if (data != null && (data['result'] == 1000 || data['result'] == 2094)) {
          debugPrint('[pCloud] getfilelink auth error: ${data['error']}');
          if (mounted) setState(() => _pCloudError = true);
        } else if (data != null) {
          debugPrint('[pCloud] getfilelink error result=${data['result']}: ${data['error']}');
        }
      } else {
        // Dropbox (uses path as id)
        url = await _getDropboxDownloadUrl(item.id);
      }
    } catch (e) {
      debugPrint('Error fetching download URL for ${item.name}: $e');
      return null;
    }
    // 4. CACHE THE RESULT
    if (url != null) {
      item.downloadUrl = url;
    }
    return url;
  }
  Future<String?> _getOneDriveThumbnailUrl(String itemId) async {
     if (_oneDriveAccessToken == null || _oneDriveError) return null; 
    final query =
        "$oneDriveGraphBase/me/drive/items/$itemId/thumbnails?select=large";
    try {
      // --- REPLACED http.get with _authenticatedGet ---
      final response = await _authenticatedGet(Uri.parse(query), PhotoSource.oneDrive)
                                 .timeout(const Duration(seconds: 10)); 
      if (response.statusCode == 200) {
        // ... (same parsing logic as before)
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> thumbnails = data['value'] ?? [];
        if (thumbnails.isNotEmpty && thumbnails[0]?['large']?['url'] != null) {
          return thumbnails[0]['large']['url'];
        } else {
           debugPrint("OneDrive thumbnail data missing for $itemId");
           return null; 
        }
      } 
      // --- 401 IS HANDLED AUTOMATICALLY ---
      else {
         debugPrint('OneDrive thumbnail error for $itemId: ${response.statusCode}');
         return null; 
      }
    } on TimeoutException {
       debugPrint('OneDrive thumbnail request timed out for $itemId');
       return null;
    } catch (e) {
      debugPrint('OneDrive thumbnail exception for $itemId (likely refresh failure): $e');
      // Error flag is set by _refreshAccessToken on failure
      return null;
    }
   }
  // --- PASTE THIS REPLACEMENT function ---
  Future<String?> _getDropboxThumbnailUrl(String itemPath, {bool isVideo = false}) async {
    if (_dropboxAccessToken == null || _dropboxError) return null;
    try {
      // --- START OF FIX ---
      // Use _authenticatedPost, which handles 401s and refreshes the token
      final response = await _authenticatedPost(
        Uri.parse('https://content.dropboxapi.com/2/files/get_thumbnail'),
        PhotoSource.dropbox, // 1. Pass the source
        headers: {
          // 2. Remove the 'Authorization' header (helper adds it)
          'Dropbox-API-Arg': jsonEncode({
            'path': itemPath,
            'format': isVideo ? 'png' : 'jpeg',
            'size': 'w640h480',
            'mode': 'fitone_bestfit',
          }),
        },
        // 3. No body is needed for this specific API call
      ).timeout(const Duration(seconds: 15));
      // --- END OF FIX ---
      if (response.statusCode == 200) {
        final base64Image = base64Encode(response.bodyBytes);
        return 'data:image/${isVideo ? 'png' : 'jpeg'};base64,$base64Image';
      } 
      // --- 401s are now handled automatically by the helper ---
      else {
        // This will now only catch other errors (e.g., 404, 500)
        debugPrint('Dropbox thumbnail failed for $itemPath: ${response.statusCode} ${response.body}');
        return null;
      }
    } on TimeoutException {
      debugPrint('Dropbox thumbnail timeout for $itemPath');
      return null;
    } catch (e) {
      // This will now catch the exception if the token REFRESH fails
      debugPrint('Dropbox thumbnail exception for $itemPath (likely refresh failure): $e');
      return null;
    }
  }
  Future<String?> _getOneDriveDownloadUrl(String itemId) async {
      if (_oneDriveAccessToken == null || _oneDriveError) return null;
    final query = "$oneDriveGraphBase/me/drive/items/$itemId?select=@microsoft.graph.downloadUrl";
    try {
      // --- REPLACED http.get with _authenticatedGet ---
      final response = await _authenticatedGet(Uri.parse(query), PhotoSource.oneDrive)
                                 .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final downloadUrl = data['@microsoft.graph.downloadUrl'] as String?;
        if (downloadUrl == null) {
           debugPrint("OneDrive download URL missing in response for $itemId");
        }
        return downloadUrl;
      } 
      // --- 401 IS HANDLED AUTOMATICALLY ---
      else {
         debugPrint('OneDrive download URL error for $itemId: ${response.statusCode}');
         return null;
      }
    } on TimeoutException {
       debugPrint('OneDrive download URL request timed out for $itemId');
       return null;
    } catch (e) {
      debugPrint('OneDrive download URL exception for $itemId (likely refresh failure): $e');
      return null;
    }
   }
  Future<String?> _getDropboxDownloadUrl(String itemPath) async {
      if (_dropboxAccessToken == null || _dropboxError) return null;
    final headers = {
      'Content-Type': 'application/json',
      // Auth header added by _authenticatedPost
    };
    final body = json.encode({'path': itemPath});
    try {
      // --- REPLACED http.post with _authenticatedPost ---
      final response = await _authenticatedPost(
        Uri.parse('$dropboxApiBase/files/get_temporary_link'),
        PhotoSource.dropbox,
        headers: headers,
        body: body,
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final link = data['link'] as String?;
        if (link == null) {
           debugPrint("Dropbox temporary link missing in response for $itemPath");
        }
        return link;
      } 
      // --- 401 IS HANDLED AUTOMATICALLY ---
      else {
        debugPrint('Dropbox temporary link error for $itemPath: ${response.statusCode} ${response.body}');
        return null;
      }
     } on TimeoutException {
       debugPrint('Dropbox temporary link request timed out for $itemPath');
       return null;
    } catch (e) {
      debugPrint('Dropbox temporary link exception for $itemPath (likely refresh failure): $e');
      return null;
    }
   }
   // ✅ PASTE THIS NEW METHOD
  Future<String?> _getBoxThumbnailUrl(String itemId) async {
    if (_boxAccessToken == null || _boxError) return null;
    // Request a 320x320 JPG thumbnail
    final uri = Uri.parse('$boxApiBase/files/$itemId/thumbnail.jpg?min_width=320&min_height=320');
    try {
      // Use the authenticated helper
      final response = await _authenticatedGet(uri, PhotoSource.box)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        // Return as Base64 string
        final base64Image = base64Encode(response.bodyBytes);
        return 'data:image/jpeg;base64,$base64Image';
      } else if (response.statusCode == 202) {
        // 202 means thumbnail is pending, we can't wait.
        debugPrint('Box thumbnail for $itemId is pending (202).');
        return null; // Or return a placeholder?
      } else {
        debugPrint('Box thumbnail error for $itemId: ${response.statusCode} - ${response.body}');
        return null;
      }
    } on TimeoutException {
      debugPrint('Box thumbnail request timed out for $itemId');
      return null;
    } catch (e) {
      debugPrint('Box thumbnail exception for $itemId (likely refresh failure): $e');
      return null;
    }
  }

  /// Fetches an on-demand 500x500 thumbnail for a pCloud item via /getthumblink.
  /// If the item is a video and pCloud has no generated thumbnail, returns null
  /// so the UI can cleanly display the video play badge without crashing the image decoder.
  Future<String?> _getPCloudThumbnailUrl(String fileId, {bool isVideo = false}) async {
    if (_pCloudAccessToken == null || _pCloudError) return null;
    try {
      final locationId = await secureStorage.read(key: _userKey('pcloud_location_id'));
      final primaryHost = (locationId == '2') ? 'eapi.pcloud.com' : 'api.pcloud.com';
      final fallbackHost = (locationId == '2') ? 'api.pcloud.com' : 'eapi.pcloud.com';

      Future<String?> fetchThumb(String host) async {
        try {
          final resp = await http.get(Uri.https(host, '/getthumblink', {
            'fileid': fileId,
            'size': '500x500',
            'crop': '0',
            'access_token': _pCloudAccessToken ?? '',
          })).timeout(const Duration(seconds: 10));
          if (resp.statusCode == 200) {
            final data = json.decode(resp.body);
            if (data['result'] == 0 && data['hosts'] != null && data['path'] != null) {
              final hosts = data['hosts'] as List;
              if (hosts.isNotEmpty) {
                return 'https://${hosts[0]}${data['path']}';
              }
            }
          }
        } catch (_) {}
        return null;
      }

      String? thumbUrl = await fetchThumb(primaryHost);
      if (thumbUrl == null) {
        thumbUrl = await fetchThumb(fallbackHost);
        if (thumbUrl != null) {
          final correctLoc = fallbackHost.contains('eapi') ? '2' : '1';
          await secureStorage.write(key: _userKey('pcloud_location_id'), value: correctLoc);
        }
      }
      return thumbUrl;
    } catch (e) {
      debugPrint('[pCloud] Thumbnail fetch error: $e');
      return null;
    }
  }
  // --- FIRESTORE Actions (Bin, Albums, Favorites handled by listeners/direct updates) ---
 // ✅ REPLACEMENT 1: Core Deletion Logic (Saves to Firestore)
 // ✅ REPLACEMENT: Robust _moveToBin (Safer & Cleans Albums)
 // ✅ REPLACEMENT: Correct _moveToBin logic
  Future<void> _moveToBin(DriveItem item) async {
    analytics.logEvent(name: 'delete_item');
    final key = item.getUniqueKey();
    setState(() {
      _bin.add(key);
      _favorites.remove(key); 
      // ⚠️ CRITICAL FIX: Do NOT remove from _driveItems.
      // We need to keep the object in memory so the Bin Page can display it.
      // _driveItems.removeWhere((i) => i.getUniqueKey() == item.getUniqueKey()); <--- REMOVED THIS
      // Instead, just re-run the filter. 
      // _updateFilteredItems() already hides anything inside _bin from the main grid.
      _updateFilteredItems(); 
    });
    // Sync with Firestore
    try {
      if (_userDocRef != null) {
        await _userDocRef!.update({
          'bin': FieldValue.arrayUnion([key]),
          'favorites': FieldValue.arrayRemove([key]),
           ..._getAlbumRemovalUpdates(key), 
        });
      }
    } catch (e) {
       debugPrint("❌Å’ Error syncing item to bin: $e");
    }
  }
   // Helper to generate Firestore update fields for removing an item from all albums
   Map<String, FieldValue> _getAlbumRemovalUpdates(String itemKey) {
     final updates = <String, FieldValue>{};
     _albums.forEach((albumName, itemKeys) {
        if (itemKeys.contains(itemKey)) {
          updates['albums.$albumName'] = FieldValue.arrayRemove([itemKey]);
        }
     });
     return updates;
   }
  Future<void> _restoreFromBin(DriveItem item) async {
    final key = item.getUniqueKey();
    try {
      await _userDocRef.update({
        'bin': FieldValue.arrayRemove([key]),
      });
      debugPrint("Restored item from bin: $key");
    } catch (e) {
       debugPrint("Error restoring item $key: $e");
       if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
             content: Text('Error restoring "${item.name}".'),
             backgroundColor: Colors.red,
          ));
       }
    }
   }
 // ✅ PASTE THIS REPLACEMENT METHOD
  Future<bool> _deleteFromProvider(DriveItem item) async {
     if (item.source == PhotoSource.oneDrive && (_oneDriveAccessToken == null || _oneDriveError)) return false;
     if (item.source == PhotoSource.dropbox && (_dropboxAccessToken == null || _dropboxError)) return false;
     if (item.source == PhotoSource.box && (_boxAccessToken == null || _boxError)) return false;
     // FIX: Guard pCloud delete — was falling through to Dropbox branch silently
     if (item.source == PhotoSource.pCloud && (_pCloudAccessToken == null || _pCloudError)) return false;
     try {
      http.Response response;
      if (item.source == PhotoSource.oneDrive) {
        final url = Uri.parse('$oneDriveGraphBase/me/drive/items/${item.id}');
        response = await _authenticatedDelete(url, PhotoSource.oneDrive)
                          .timeout(const Duration(seconds: 15));
        return response.statusCode == 204;
      } else if (item.source == PhotoSource.box) {
        final url = Uri.parse('$boxApiBase/files/${item.id}');
        response = await _authenticatedDelete(url, PhotoSource.box)
                          .timeout(const Duration(seconds: 15));
        return response.statusCode == 204;
      } else if (item.source == PhotoSource.pCloud) {
        // FIX: pCloud uses /deletefile?fileid=XXX&access_token=YYY with dual-host auto-fallback
        final locationId = await secureStorage.read(key: _userKey('pcloud_location_id'));
        final apiHost = (locationId == '2') ? 'eapi.pcloud.com' : 'api.pcloud.com';
        final fallbackHost = (locationId == '2') ? 'api.pcloud.com' : 'eapi.pcloud.com';

        Future<Map<String, dynamic>?> sendDelete(String host) async {
          try {
            final resp = await http.get(
              Uri.https(host, '/deletefile', {
                'fileid': item.id,
                'access_token': _pCloudAccessToken ?? '',
              }),
            ).timeout(const Duration(seconds: 15));
            return json.decode(resp.body) as Map<String, dynamic>?;
          } catch (_) {
            return null;
          }
        }

        Map<String, dynamic>? data = await sendDelete(apiHost);
        if (data == null || data['result'] == 2000) {
          final fbData = await sendDelete(fallbackHost);
          if (fbData != null && fbData['result'] == 0) {
            data = fbData;
            final correctLoc = fallbackHost.contains('eapi') ? '2' : '1';
            await secureStorage.write(key: _userKey('pcloud_location_id'), value: correctLoc);
          }
        }
        if (data != null && data['result'] == 0) return true;
        if (data != null && (data['result'] == 1000 || data['result'] == 2094)) {
          if (mounted) setState(() => _pCloudError = true);
        }
        debugPrint('[pCloud] deletefile error result=${data?['result']}: ${data?['error']}');
        return false;
      } else { // Dropbox
        final url = Uri.parse('$dropboxApiBase/files/delete_v2');
        final headers = { 'Content-Type': 'application/json' };
        final body = jsonEncode({'path': item.id});
        response = await _authenticatedPost(url, PhotoSource.dropbox, headers: headers, body: body)
                          .timeout(const Duration(seconds: 15));
        if (response.statusCode == 200) {
           return true;
        } else {
           debugPrint('Dropbox permanent delete error: ${response.statusCode} - ${response.body}');
           return false;
        }
      }
    } on TimeoutException {
       debugPrint('Timeout deleting ${item.name} from ${item.source.name}');
       return false;
    } catch (e) {
      debugPrint('Error deleting ${item.name} from ${item.source.name}: $e');
      if (e.toString().contains('401')) {
         if (mounted) {
            setState(() {
               if (item.source == PhotoSource.oneDrive) _oneDriveError = true;
               else if (item.source == PhotoSource.box) _boxError = true;
               else if (item.source == PhotoSource.pCloud) _pCloudError = true;
               else _dropboxError = true;
            });
            _updateFilteredItems();
         }
      }
      return false;
    }
  }
  Future<void> _permanentDelete(DriveItem item) async {
     // Dialog text varies by delete mode
     final isCloudDelete = _binDeleteFromCloud && item.source != PhotoSource.local;
     final isLocalDelete = _binDeleteFromCloud && item.source == PhotoSource.local;
     final isPhysicalDelete = isCloudDelete || isLocalDelete;
     final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isPhysicalDelete 
            ? (isCloudDelete ? 'Delete from Cloud?' : 'Delete from Device?')
            : 'Remove from App?'),
        content: Text(
            isCloudDelete
              ? 'Are you sure you want to permanently delete "${item.name}" from the cloud? This action CANNOT be undone.'
              : isLocalDelete
                ? 'Are you sure you want to permanently delete "${item.name}" from your device? This will move it to your device\'s system Trash/Photos Bin.'
                : 'Remove "${item.name}" from this app? The file will remain on the cloud provider or device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(isPhysicalDelete ? 'Delete' : 'Remove',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
     if (confirm != true) return;
     final key = item.getUniqueKey();
     // --- App-only removal path ---
     if (!isPhysicalDelete) {
       setState(() {
         _driveItems.removeWhere((i) => i.getUniqueKey() == key);
         _updateFilteredItems();
       });
       try {
         await _userDocRef.update({
           'bin': FieldValue.arrayRemove([key]),
           'favorites': FieldValue.arrayRemove([key]),
            ..._getAlbumRemovalUpdates(key),
         });
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('"${item.name}" removed from app.')));
         }
       } catch (e) {
         debugPrint("Firestore update error after app-only remove $key: $e");
       }
       return;
     }
     // --- Local device delete path ---
     if (isLocalDelete) {
       ScaffoldMessenger.of(context).hideCurrentSnackBar();
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(
             content: Text('Deleting "${item.name}" from device...')));
       }
       bool deletedFromDevice = false;
       try {
         final deletedIds = await PhotoManager.editor.deleteWithIds([item.id]);
         deletedFromDevice = deletedIds.contains(item.id);
       } catch (e) {
         debugPrint("Error trashing device photo ${item.id}: $e");
       }
       if (!mounted) return;
       ScaffoldMessenger.of(context).hideCurrentSnackBar();
       if (deletedFromDevice) {
         setState(() {
           _driveItems.removeWhere((i) => i.getUniqueKey() == key);
           _updateFilteredItems();
         });
         try {
           await _userDocRef.update({
             'bin': FieldValue.arrayRemove([key]),
             'favorites': FieldValue.arrayRemove([key]),
              ..._getAlbumRemovalUpdates(key),
           });
           if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
                 SnackBar(content: Text('"${item.name}" deleted from device.')));
           }
         } catch (e) {
            debugPrint("Firestore update error after device delete $key: $e");
         }
       } else {
           if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                 content: Text('Failed to delete "${item.name}" from device. Deletion cancelled or denied.'),
                 backgroundColor: Colors.orange,
             ));
           }
       }
       return;
     }
     // --- Cloud delete path ---
     ScaffoldMessenger.of(context).hideCurrentSnackBar();
     ScaffoldMessenger.of(context).showSnackBar(SnackBar(
         content: Text('Permanently deleting "${item.name}"...')));
     final bool deletedFromCloud = await _deleteFromProvider(item);
     if (!mounted) return;
     ScaffoldMessenger.of(context).hideCurrentSnackBar();
     if (deletedFromCloud) {
       setState(() {
         _driveItems.removeWhere((i) => i.getUniqueKey() == key);
         _updateFilteredItems();
        });
        try {
          await _userDocRef.update({
            'bin': FieldValue.arrayRemove([key]),
            'favorites': FieldValue.arrayRemove([key]),
             ..._getAlbumRemovalUpdates(key),
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('"${item.name}" permanently deleted.')));
          }
        } catch (e) {
           debugPrint("Firestore update error after permanent delete $key: $e");
           if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Error updating app data after deleting "${item.name}".'),
                backgroundColor: Colors.orange,
             ));
           }
        }
      } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(
                    'Failed to delete "${item.name}" from the cloud provider. It may have already been deleted externally.'),
                 backgroundColor: Colors.red,
                 ));
          }
     }
   }
  // --- FIRESTORE: Album Add Action ---
  Future<void> _addItemsToAlbum(List<String> itemKeys, String albumName) async {
     if (itemKeys.isEmpty) return;
     try {
       await _userDocRef.update({
         // Use dot notation to update specific map field
         'albums.$albumName': FieldValue.arrayUnion(itemKeys),
       });
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(
             content:
                 Text('Added ${itemKeys.length} items to album "$albumName"')));
       }
     } catch (e) {
        debugPrint("Error adding items to album $albumName: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
             content: Text('Error adding items to album "$albumName".'),
             backgroundColor: Colors.red,
          ));
        }
     }
   }
  Future<void> _showAddToAlbumDialog(List<String> itemKeys) async {
     if (itemKeys.isEmpty) return;
    final nameCtrl = TextEditingController();
    // Get current album names for display and checking existence
    final currentAlbumNames = _albums.keys.toList()
                             ..sort((a,b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
            title: Text('Add ${itemKeys.length} items to album'),
            content: SizedBox(
              width: double.maxFinite, // Make dialog use available width
              // Use SingleChildScrollView to prevent overflow if many albums exist
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  // --- List existing albums ---
                  if (currentAlbumNames.isNotEmpty)
                     ConstrainedBox(
                       constraints: BoxConstraints(
                          // Limit height of the album list
                          maxHeight: MediaQuery.of(context).size.height * 0.3,
                       ),
                       child: ListView(
                         shrinkWrap: true,
                         children: currentAlbumNames.map((name) => ListTile(
                               title: Text(name),
                               leading: const Icon(Icons.photo_album_outlined),
                               onTap: () => Navigator.pop(dialogContext, name), // Return selected album name
                             )).toList(),
                       ),
                     ),
                  if (currentAlbumNames.isNotEmpty) const Divider(),
                  // --- Option to create new album ---
                  TextField(
                      controller: nameCtrl,
                       autofocus: currentAlbumNames.isEmpty, // Autofocus if no albums exist
                      decoration: const InputDecoration(
                        labelText: 'New album name', // Use labelText
                        hintText: 'Or create a new one',
                        // border: UnderlineInputBorder(), // Keep simple border
                        // focusedBorder: UnderlineInputBorder(
                        //     borderSide: BorderSide(color: Colors.blue)),
                      )),
                ]),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel')),
              TextButton(
                  onPressed: () {
                     // Handle creation of new album
                    final newName = nameCtrl.text.trim();
                    if (newName.isNotEmpty) {
                       // --- FIXED: Changed widget.albums to _albums ---
                       if (_albums.containsKey(newName)) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                             content: Text('Album "$newName" already exists. Select it from the list or choose a different name.')));
                       } else {
                          // Create the new album field in Firestore first
                          _userDocRef.update({'albums.$newName': []}).then((_) {
                             if (mounted) Navigator.pop(context, newName); // Return the new name
                          }).catchError((e) {
                             debugPrint("Error creating new album field: $e");
                             if (mounted) {
                               ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text('Error creating album "$newName".'), backgroundColor: Colors.red));
                             }
                          });
                       }
                    } else if (currentAlbumNames.isEmpty) {
                       // If no albums exist and field is empty
                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Please enter a name for the new album.')));
                    } else {
                       // If albums exist but field is empty, likely means user didn't select/create
                       Navigator.pop(context); // Just close
                    }
                  },
                  child: const Text('Create & Add')),
            ],
          );
      },
    );
    // If an album name was returned (either selected or created)
    if (result != null && result.isNotEmpty) {
      await _addItemsToAlbum(itemKeys, result);
    }
  }
  // --- Grouping Logic (MODIFIED for Sorting) ---
  // Now returns List<DriveItem> instead of grouped map if sorted by name
  dynamic _getGroupedOrSortedItems(List<DriveItem> items) {
    // If sorting by name, just return the flat list (already sorted by _updateFilteredItems)
    if (_currentSortOption == SortOption.nameAZ || _currentSortOption == SortOption.nameZA) {
      return items;
    } else {
      // Otherwise, group by month (original logic for newest/oldest)
      final Map<String, List<DriveItem>> groups = {};
      for (final item in items) {
        final key = (item.created == null || item.created!.year < 2000)
            ? 'Unknown Date'
            : DateFormat.yMMMM().format(item.created!); // Group by Year-Month
        groups.putIfAbsent(key, () => []).add(item);
      }
      final entries = groups.entries.toList();
      // Sort the groups themselves based on the Year-Month key
      entries.sort((a, b) {
        if (a.key == 'Unknown Date') return 1; // Unknown always last
        if (b.key == 'Unknown Date') return -1;
        try {
          // Parse keys back to dates for comparison
          final dateA = DateFormat.yMMMM().parse(a.key);
          final dateB = DateFormat.yMMMM().parse(b.key);
          // Group sorting respects the main sort order (newest/oldest)
          return _currentSortOption == SortOption.newestFirst
              ? dateB.compareTo(dateA) // Newest month groups first
              : dateA.compareTo(dateB); // Oldest month groups first
        } catch (e) {
          debugPrint("Error parsing group date key: $e");
          return 0; // Should not happen if keys are generated correctly
        }
      });
      return entries; // Return list of map entries (groups)
    }
  }
  // --- Filter Dialog ---
  Future<void> _showFilterDialog() async {
     // Store current values to potentially reset on cancel
     FilterSource initialSource = _currentSourceFilter;
     FilterType initialType = _currentTypeFilter;
     final result = await showModalBottomSheet<Map<String, dynamic>>( // Return map of selected values
      context: context,
      isScrollControlled: true, // Allow taller sheet if needed
      useSafeArea: true, // Ensure content stays above system navigation bar on all devices
      builder: (BuildContext dialogContext) {
        // Use StatefulBuilder to manage temporary state within the dialog
        FilterSource tempSource = _currentSourceFilter;
        FilterType tempType = _currentTypeFilter;
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            // Calculate bottom padding to stay above system navigation bar
            final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
            final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;
            final safeBottom = bottomInset > 0 ? bottomInset : bottomPadding;
            return SafeArea(
              top: false, // Only apply safe area to bottom
              child: Container(
              padding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 16.0 + safeBottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Header ---
                  Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                        Text('Filter Options', style: Theme.of(context).textTheme.titleLarge),
                        IconButton( // Close button
                           icon: const Icon(Icons.close),
                           onPressed: () => Navigator.pop(context), // Just close on tap
                        ),
                     ],
                  ),
                  const Divider(),
                  // --- Source Filter ---
                  Padding(
                     padding: const EdgeInsets.symmetric(vertical: 8.0),
                     child: Text('Source', style: Theme.of(context).textTheme.titleMedium),
                  ),
                  RadioListTile<FilterSource>(
                    title: const Text('All Sources'),
                    value: FilterSource.all,
                    groupValue: tempSource,
                    onChanged: (value) => setDialogState(() => tempSource = value!),
                    dense: true, // Make tiles more compact
                  ),
                  RadioListTile<FilterSource>(
                    title: const Text('OneDrive'),
                    value: FilterSource.oneDrive,
                    groupValue: tempSource,
                     // Disable if OneDrive not connected/error? (Optional UX enhancement)
                     // onChanged: (_oneDriveAccessToken != null && !_oneDriveError) ? (value) => setDialogState(() => tempSource = value!) : null,
                     onChanged: (value) => setDialogState(() => tempSource = value!),
                    dense: true,
                  ),
                  RadioListTile<FilterSource>(
                    title: const Text('Dropbox'),
                    value: FilterSource.dropbox,
                    groupValue: tempSource,
                     // onChanged: (_dropboxAccessToken != null && !_dropboxError) ? (value) => setDialogState(() => tempSource = value!) : null,
                     onChanged: (value) => setDialogState(() => tempSource = value!),
                    dense: true,
                  ),
                  RadioListTile<FilterSource>(
                    title: const Text('Box'),
                    value: FilterSource.box,
                    groupValue: tempSource,
                     onChanged: (value) => setDialogState(() => tempSource = value!),
                    dense: true,
                  ),
                  // ✅ ADD THIS MISSING BLOCK FOR PCLOUD
                  RadioListTile<FilterSource>(
                    title: const Text('pCloud'),
                    value: FilterSource.pCloud, // Make sure FilterSource enum has .pCloud
                    groupValue: tempSource,
                    onChanged: (value) => setDialogState(() => tempSource = value!),
                    dense: true,
                  ),
                  RadioListTile<FilterSource>(
                    title: const Text('Device Gallery'),
                    value: FilterSource.local,
                    groupValue: tempSource,
                    onChanged: (value) => setDialogState(() => tempSource = value!),
                    dense: true,
                  ),
                  const Divider(),
                   // --- Type Filter ---
                  Padding(
                     padding: const EdgeInsets.symmetric(vertical: 8.0),
                     child: Text('Media Type', style: Theme.of(context).textTheme.titleMedium),
                  ),
                  RadioListTile<FilterType>(
                    title: const Text('All Media'),
                    value: FilterType.all,
                    groupValue: tempType,
                    onChanged: (value) => setDialogState(() => tempType = value!),
                    dense: true,
                  ),
                  RadioListTile<FilterType>(
                    title: const Text('Photos Only'),
                    value: FilterType.photos,
                    groupValue: tempType,
                    onChanged: (value) => setDialogState(() => tempType = value!),
                    dense: true,
                  ),
                  RadioListTile<FilterType>(
                    title: const Text('Videos Only'),
                    value: FilterType.videos,
                    groupValue: tempType,
                    onChanged: (value) => setDialogState(() => tempType = value!),
                    dense: true,
                  ),
                  const SizedBox(height: 16),
                  // --- Action Buttons ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton( // Reset Button
                        onPressed: () {
                           // Reset temp state back to initial values
                           setDialogState(() {
                             tempSource = initialSource;
                             tempType = initialType;
                           });
                        },
                        child: const Text('Reset'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          // Return the selected values
                          Navigator.pop(context, {'source': tempSource, 'type': tempType});
                        },
                        child: const Text('Apply Filters'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            );
          },
        );
      },
    );
     // Apply filters if user confirmed
     if (result != null) {
       setState(() {
         _currentSourceFilter = result['source'] as FilterSource;
         _currentTypeFilter = result['type'] as FilterType;
       });
       _updateFilteredItems(); // Trigger list update
     }
   }
  // --- NEW METHOD: Show Sort Dialog ---
  Future<void> _showSortDialog() async {
     SortOption initialSort = _currentSortOption; // Store initial value
    final result = await showModalBottomSheet<SortOption>( // Return selected SortOption
      context: context,
      builder: (BuildContext dialogContext) {
        SortOption tempSort = _currentSortOption; // Temporary state for the dialog
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return Container(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   // --- Header ---
                  Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                        Text('Sort by', style: Theme.of(context).textTheme.titleLarge),
                        IconButton( // Close button
                           icon: const Icon(Icons.close),
                           onPressed: () => Navigator.pop(context), // Just close
                        ),
                     ],
                  ),
                  const Divider(),
                  // --- Sort Options ---
                  RadioListTile<SortOption>(
                    title: const Text('Date: Newest First'),
                    value: SortOption.newestFirst,
                    groupValue: tempSort,
                    onChanged: (value) => setDialogState(() => tempSort = value!),
                     dense: true,
                  ),
                   RadioListTile<SortOption>(
                    title: const Text('Date: Oldest First'),
                    value: SortOption.oldestFirst,
                    groupValue: tempSort,
                    onChanged: (value) => setDialogState(() => tempSort = value!),
                     dense: true,
                  ),
                  RadioListTile<SortOption>(
                    title: const Text('Name (A-Z)'),
                    value: SortOption.nameAZ,
                    groupValue: tempSort,
                    onChanged: (value) => setDialogState(() => tempSort = value!),
                     dense: true,
                  ),
                  RadioListTile<SortOption>(
                    title: const Text('Name (Z-A)'),
                    value: SortOption.nameZA,
                    groupValue: tempSort,
                    onChanged: (value) => setDialogState(() => tempSort = value!),
                     dense: true,
                  ),
                  const SizedBox(height: 16),
                  // --- Action Buttons ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                       TextButton( // Reset Button
                        onPressed: () {
                           // Reset temp state back to initial value
                           setDialogState(() => tempSort = initialSort);
                        },
                        child: const Text('Reset'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context, tempSort); // Return selected option
                        },
                        child: const Text('Apply Sorting'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
     // Apply sort if user confirmed and value changed
     if (result != null && result != _currentSortOption) {
       setState(() {
         _currentSortOption = result;
       });
       _fetchAllPhotos(firstPage: true); // Reload from sources with new sort order
     }
  }
  // --- Freemium Dialog (MODIFIED for IAP) ---
 // --- Freemium Dialog (Refactored to accept Title & Message) ---
// --- Freemium Dialog (Simplified & Cleaner) ---
  // ---------------------------------------------------------------------------
  // UPDATED PRO DIALOG (Sales Pitch for Cloud Manager)
  // ---------------------------------------------------------------------------
  // ---------------------------------------------------------------------------
  // GENERIC PRO DIALOG (Sells Value to Everyone)
  // ---------------------------------------------------------------------------
  // FINAL "FOUNDING MEMBER" 3D GLASS DIALOG
  // ---------------------------------------------------------------------------
  void _showProDialog({String? title, String? message}) {
    analytics.logEvent(name: 'view_promotion', parameters: {'promotion_name': 'pro_upgrade'});
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        String selectedProductId = _kProSubscriptionId; // Default to Lifetime
        return StatefulBuilder(
          builder: (context, setDialogState) {
            ProductDetails? lifetimeProduct;
            ProductDetails? monthlyProduct;
            for (final prod in _products) {
              if (prod.id == _kProSubscriptionId) lifetimeProduct = prod;
              if (prod.id == _kProMonthlyId) monthlyProduct = prod;
            }
            final lifetimePrice = lifetimeProduct?.price ?? "₹1,300.00";
            final monthlyPrice = monthlyProduct?.price ?? "₹280.00";
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              backgroundColor: Colors.white,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. HEADER
                      const Row(
                        children: [
                          Expanded(
                            child: Text(
                              "✨ Unlock Unified Gallery Pro",
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        "One app to manage photos across all your cloud accounts",
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1565C0), // Blue accent
                        ),
                      ),
                      const SizedBox(height: 16),
                      // 2. FEATURE LIST (Ordered: Cloud Transfer first, Unified multi cloud gallery second)
                      _buildProFeatureRow(
                        const Text("🔄", style: TextStyle(fontSize: 18)),
                        "Cloud Transfer",
                        "Move or copy media between cloud providers.",
                      ),
                      _buildProFeatureRow(
                        const Text("☁️", style: TextStyle(fontSize: 18)),
                        "Unified Multi-Cloud Gallery",
                        "Connect Dropbox, OneDrive, Box & pCloud together.",
                      ),
                      _buildProFeatureRow(
                        const Text("📊", style: TextStyle(fontSize: 18)),
                        "Cloud Storage Insights",
                        "See storage usage across all connected clouds.",
                      ),
                      _buildProFeatureRow(
                        const Text("🗑️", style: TextStyle(fontSize: 18)),
                        "Remove Duplicates",
                        "Find and delete visually similar & identical files to free up space.",
                      ),
                      _buildProFeatureRow(
                        const Text("🔍", style: TextStyle(fontSize: 18)),
                        "AI Smart Search & Smart Albums",
                        "Search by photo contents, objects, text, and group them dynamically.",
                      ),
                      const SizedBox(height: 16),
                      // 3. PRICING SELECTOR
                      // Option 1: Monthly Subscription
                      GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            selectedProductId = _kProMonthlyId;
                          });
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: selectedProductId == _kProMonthlyId ? const Color(0xFFF0F7FF) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selectedProductId == _kProMonthlyId ? const Color(0xFF1565C0) : Colors.grey.shade300,
                              width: selectedProductId == _kProMonthlyId ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Radio<String>(
                                value: _kProMonthlyId,
                                groupValue: selectedProductId,
                                activeColor: const Color(0xFF1565C0),
                                onChanged: (val) {
                                  if (val != null) {
                                    setDialogState(() {
                                      selectedProductId = val;
                                    });
                                  }
                                },
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Monthly Subscription",
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                                    ),
                                    Text(
                                      "Cancel anytime",
                                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                monthlyPrice + "/mo",
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1565C0)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Option 2: Lifetime License (Best value)
                      GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            selectedProductId = _kProSubscriptionId;
                          });
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: selectedProductId == _kProSubscriptionId ? const Color(0xFFF0F7FF) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selectedProductId == _kProSubscriptionId ? const Color(0xFF1565C0) : Colors.grey.shade300,
                              width: selectedProductId == _kProSubscriptionId ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Radio<String>(
                                value: _kProSubscriptionId,
                                groupValue: selectedProductId,
                                activeColor: const Color(0xFF1565C0),
                                onChanged: (val) {
                                  if (val != null) {
                                    setDialogState(() {
                                      selectedProductId = val;
                                    });
                                  }
                                },
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      spacing: 6,
                                      children: [
                                        const Text(
                                          "Lifetime License",
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.shade700,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            "BEST VALUE",
                                            style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      "Pay once. Lifetime updates included",
                                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                lifetimePrice,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1565C0)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_iapError != null && _products.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(
                            _iapError!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red, fontSize: 12),
                          ),
                        ),
                      Center(
                        child: TextButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _restorePurchases();
                          },
                          icon: const Icon(Icons.restore, size: 16, color: Color(0xFF1565C0)),
                          label: const Text(
                            "Already purchased? Restore Purchases",
                            style: TextStyle(fontSize: 12.5, color: Color(0xFF1565C0), fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // 4. ACTION BUTTONS
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              "Maybe Later",
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1565C0),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: (_isIapLoading || _isPurchasePending)
                                ? null
                                : () async {
                                    if (_products.isEmpty) {
                                      _initIAP();
                                    } else {
                                      Navigator.pop(context);
                                      _buyProSubscription(selectedProductId);
                                    }
                                  },
                            child: (_isIapLoading || _isPurchasePending)
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : Text(
                                    _products.isEmpty ? "Retry Load" : "Unlock Pro",
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
  Widget _buildProFeatureRow(Widget leading, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFE3F2FD),
              shape: BoxShape.circle,
            ),
            child: leading,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildProFeature(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.blueAccent, size: 24),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
              ],
            ),
          ),
        ],
      ),
    );
  }
// ... (Code continues) ...
// ... (Code from Part 1 continues here) ...
  // --- MULTI-SELECT: Methods ---
  void _toggleSelectionMode({String? initialKey}) {
     // Don't toggle selection mode if a batch action is in progress
     if (_isBatchDownloading || _isBatchSharing) return;
     setState(() {
       _isSelecting = !_isSelecting;
       _selectedItemKeys.clear();
       if (_isSelecting && initialKey != null) {
         _selectedItemKeys.add(initialKey);
       }
     });
   }
   void _toggleItemSelection(String key) {
     // Don't change selection if a batch action is in progress
     if (_isBatchDownloading || _isBatchSharing) return;
     setState(() {
       if (_selectedItemKeys.contains(key)) {
         _selectedItemKeys.remove(key);
         // If last item is deselected, turn off selection mode
         if (_selectedItemKeys.isEmpty && _isSelecting) { // Check _isSelecting to avoid flicker
           _isSelecting = false;
         }
       } else {
         _selectedItemKeys.add(key);
       }
     });
   }
   // --- MULTI-SELECT: Batch Action Methods ---
   Future<void> _batchFavoriteSelected() async {
     if (_isBatchDownloading || _isBatchSharing || _selectedItemKeys.isEmpty) return; // Prevent concurrent actions
     // Determine if we are favoriting or unfavoriting based on the first item
     final firstKey = _selectedItemKeys.first;
     final shouldFavorite = !_favorites.contains(firstKey);
     try {
       await _userDocRef.update({
         'favorites': shouldFavorite
             ? FieldValue.arrayUnion(_selectedItemKeys.toList())
             : FieldValue.arrayRemove(_selectedItemKeys.toList()),
       });
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(
           content: Text('${shouldFavorite ? 'Favorited' : 'Unfavorited'} ${_selectedItemKeys.length} items.'),
         ));
         _toggleSelectionMode(); // Exit selection mode
       }
     } catch (e) {
        debugPrint("Batch favorite error: $e");
         if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: const Text('Error updating favorites.'), backgroundColor: Colors.red));
         }
     }
   }
   Future<void> _batchAddToAlbumSelected() async {
     if (_isBatchDownloading || _isBatchSharing || _selectedItemKeys.isEmpty) return;
     await _showAddToAlbumDialog(_selectedItemKeys.toList());
     // Keep selection mode active after adding to album? Or toggle off?
     // Let's toggle off for now for simplicity.
     _toggleSelectionMode();
   }
   Future<void> _batchMoveToBinSelected() async {
     if (_isBatchDownloading || _isBatchSharing || _selectedItemKeys.isEmpty) return;
      final keysToBin = _selectedItemKeys.toList(); // Copy keys before clearing selection
      final updates = <String, dynamic>{
        'bin': FieldValue.arrayUnion(keysToBin),
        'favorites': FieldValue.arrayRemove(keysToBin),
         // Also remove from albums
        // This requires generating updates based on current album state
         // ..._getBatchAlbumRemovalUpdates(keysToBin), // Generate multiple updates
      };
     try {
        // --- Generate album removal updates ---
        _albums.forEach((albumName, itemKeys) {
           final keysToRemoveFromAlbum = itemKeys.where((k) => keysToBin.contains(k)).toList();
           if (keysToRemoveFromAlbum.isNotEmpty) {
             updates['albums.$albumName'] = FieldValue.arrayRemove(keysToRemoveFromAlbum);
           }
        });
       // --- End album removal ---
       await _userDocRef.update(updates);
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(
           content: Text('Moved ${keysToBin.length} items to Bin.'),
         ));
         _toggleSelectionMode(); // Exit selection mode
       }
     } catch (e) {
        debugPrint("Batch move to bin error: $e");
         if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: const Text('Error moving items to Bin.'), backgroundColor: Colors.red));
         }
     }
   }
  // Batch Share Method
  Future<void> _batchShareSelected() async {
    analytics.logEvent(name: 'share', parameters: {'content_type': 'image', 'item_count': _selectedItemKeys.length});
    if (_isBatchSharing || _isBatchDownloading || _selectedItemKeys.isEmpty) return;
    setState(() => _isBatchSharing = true);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Preparing to share ${_selectedItemKeys.length} items...'),
        duration: const Duration(seconds: 10) // Longer duration
        ));
    final List<XFile> filesToShare = [];
    final tempDir = await getTemporaryDirectory();
    final selectedItems = _driveItems
        .where((item) => _selectedItemKeys.contains(item.getUniqueKey()))
        .toList();
    int filesPrepared = 0;
    List<String> failedItems = []; // Track names of failed items
    try {
      for (final item in selectedItems) {
         if (!mounted) break; // Check if still mounted
        try {
          if (item.source == PhotoSource.local) {
            final entity = await AssetEntity.fromId(item.id);
            final file = await entity?.file;
            if (file != null) {
              filesToShare.add(XFile(file.path));
              filesPrepared++;
            } else {
              failedItems.add(item.name);
            }
            continue;
          }
          final downloadUrl = await _getDownloadUrl(item);
          if (downloadUrl == null) {
            debugPrint('Share error: Could not get download URL for ${item.name}');
             failedItems.add(item.name);
            continue; // Skip this file
          }
          // Add timeout for individual file download
          final response = await http.get(Uri.parse(downloadUrl)).timeout(const Duration(seconds: 20));
          if (response.statusCode != 200) {
            debugPrint('Share error: Failed to download ${item.name} (Code: ${response.statusCode})');
             failedItems.add(item.name);
            continue; // Skip this file
          }
          final extension = item.name.contains('.')
              ? item.name.split('.').last
              : (item.isVideo ? 'mp4' : 'jpg');
           // More unique temp file name
          final fileName = 'share_${DateTime.now().millisecondsSinceEpoch}_${filesToShare.length}.$extension';
          final filePath = '${tempDir.path}/$fileName';
          final file = File(filePath);
          await file.writeAsBytes(response.bodyBytes);
          filesToShare.add(XFile(filePath));
          filesPrepared++;
        } on TimeoutException {
           debugPrint('Timeout downloading ${item.name} for sharing.');
           failedItems.add(item.name);
        } catch (e) {
            debugPrint('Error processing ${item.name} for sharing: $e');
             failedItems.add(item.name);
        }
      }
      if (!mounted) return; // Check again before sharing
      ScaffoldMessenger.of(context).hideCurrentSnackBar(); // Hide progress
      if (filesToShare.isNotEmpty) {
         if (failedItems.isNotEmpty) {
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(
               content: Text('Sharing $filesPrepared items. ${failedItems.length} failed to prepare.'),
               backgroundColor: Colors.orange,
            ));
         }
        await Share.shareXFiles(filesToShare, text: 'Shared from Cloud Photos');
      } else {
        throw Exception('No files could be prepared for sharing.');
      }
    } catch (e) {
      debugPrint('Batch Share error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error sharing files: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() => _isBatchSharing = false);
        _toggleSelectionMode(); // Exit selection mode
      }
      // Clean up temp files (don't need to await)
      for (final xfile in filesToShare) {
        try {
          final f = File(xfile.path);
          // ✅ FIX: Check existence first to avoid PathNotFoundException (Crashlytics fix)
          if (await f.exists()) {
            await f.delete();
          }
        } catch (e) {
          debugPrint("Error deleting temp share file ${xfile.path}: $e");
        }
      }
    }
  }
  // Batch Download Method
  Future<void> _batchDownloadSelected() async {
    analytics.logEvent(name: 'batch_download', parameters: {'item_count': _selectedItemKeys.length});
    if (_isBatchDownloading || _isBatchSharing || _selectedItemKeys.isEmpty) return;
    setState(() => _isBatchDownloading = true);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Downloading ${_selectedItemKeys.length} items to gallery...'),
        duration: const Duration(seconds: 10),
        ));
    int successCount = 0;
    List<String> failedItems = [];
    final selectedItems = _driveItems
        .where((item) => _selectedItemKeys.contains(item.getUniqueKey()))
        .toList();
    List<File> tempFiles = []; // Keep track of files to delete
    try {
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        final granted = await Gal.requestAccess();
        if (!granted) throw Exception('Storage permission denied');
      }
      final tempDir = await getTemporaryDirectory();
      for (final item in selectedItems) {
         if (!mounted) break;
        File? tempFile;
        try {
          if (item.source == PhotoSource.local) {
            final entity = await AssetEntity.fromId(item.id);
            final file = await entity?.file;
            if (file != null) {
              if (item.isVideo) {
                await Gal.putVideo(file.path, album: 'Cloud Photos');
              } else {
                await Gal.putImage(file.path, album: 'Cloud Photos');
              }
              successCount++;
            } else {
              failedItems.add(item.name);
            }
            continue;
          }
          final downloadUrl = await _getDownloadUrl(item);
          if (downloadUrl == null) throw Exception('Could not get download URL');
          // Add timeout
          final response = await http.get(Uri.parse(downloadUrl)).timeout(const Duration(seconds: 20));
          if (response.statusCode != 200) {
            throw Exception(
                'Failed to download file (code: ${response.statusCode})');
          }
          final isVideo = item.isVideo;
          final extension = item.name.contains('.')
              ? item.name.split('.').last
              : (isVideo ? 'mp4' : 'jpg');
           // More unique name
          final fileName = 'download_${DateTime.now().millisecondsSinceEpoch}_$successCount.$extension';
          final filePath = '${tempDir.path}/$fileName';
          tempFile = File(filePath);
          tempFiles.add(tempFile); // Add to list for cleanup
          await tempFile.writeAsBytes(response.bodyBytes);
          if (isVideo) {
            await Gal.putVideo(filePath, album: 'Cloud Photos');
          } else {
            await Gal.putImage(filePath, album: 'Cloud Photos');
          }
          successCount++;
        } on TimeoutException {
           debugPrint('Timeout downloading ${item.name} for saving.');
           failedItems.add(item.name);
        } catch (e) {
          debugPrint('Error downloading ${item.name}: $e');
           failedItems.add(item.name);
          // Don't delete tempFile here if save failed, cleanup happens in finally
        }
      }
      if (!mounted) return; // Check again
      ScaffoldMessenger.of(context).hideCurrentSnackBar(); // Hide progress
      if (successCount > 0) {
         String message = 'Saved $successCount items to gallery.';
         if (failedItems.isNotEmpty) {
            message += ' ${failedItems.length} failed.';
         }
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(message),
            backgroundColor: failedItems.isEmpty ? Colors.green : Colors.orange,
            ));
      } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to save any items. (${failedItems.length} errors).'),
            backgroundColor: Colors.red,
            ));
      }
    } catch (e) {
      // Catch errors like permission denial
      debugPrint('Batch Download error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving files: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() => _isBatchDownloading = false);
        _toggleSelectionMode(); // Exit selection mode
      }
      // Clean up ALL temp files created during this batch
      for (final file in tempFiles) {
         try {
           if (await file.exists()) {
             await file.delete();
           }
         } catch (e) {
           debugPrint("Error deleting temp download file ${file.path}: $e");
         }
      }
    }
  }
// 🔑’ LOGIC: Who is allowed to connect?
  // --- NEW: GOOGLE LOGIN DIALOG (For Deferred Auth) ---
  void _showGoogleSignInRequired() {
    // Guard: widget may be disposed (especially on MIUI) between tap and callback
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Sign In Required"),
        content: const Text("Please sign in with Google to save your cloud connections."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginPage()));
            },
            child: const Text("Sign In with Google"),
          ),
        ],
      ),
    );
  }
  void _handleCloudLogin(String serviceName, Function loginMethod) {
    // 🔑¥ NEW: DEFERRED LOGIN CHECK (Consent First, Login Later)
    // If user is currently a GUEST (Anonymous), force them to login before connecting clouds.
    if (widget.firebaseUser.isAnonymous) {
      _showGoogleSignInRequired();
      return;
    }
    // 1. If User is PRO, they can do anything.
    if (_isPro) {
      loginMethod();
      return;
    }
    // 2. DROPBOX is always Pro Only (High API Cost)
    if (serviceName == 'Dropbox') {
      _showProDialog(
        title: "Unlock Dropbox", 
        message: "Dropbox integration is a Premium feature due to high API costs. Upgrade to connect."
      );
      return;
    }
    // 3. For all other services (Standard), apply "1-Slot Free" Rule
    // Count how many are CURRENTLY connected
    // FIX Bug 5: use refresh token OR access token — on startup only the refresh token
    // is in state (access token arrives after token exchange), so checking access token
    // alone would undercount connected services right after app launch.
    int connectedCount = 0;
   // if (_hasGoogleDriveAccess) connectedCount++;
    if (_oneDriveAccessToken != null || _oneDriveRefreshToken != null) connectedCount++;
    if (_boxAccessToken != null || _boxRefreshToken != null) connectedCount++;
    if (_pCloudAccessToken != null) connectedCount++;
    if (_megaSessionId != null) connectedCount++;
    // Check if they are trying to reconnect an EXISTING service (not adding a new one)
    bool isRefreshing = false;
    //if (serviceName == 'Google Drive' && _hasGoogleDriveAccess) isRefreshing = true;
    if (serviceName == 'OneDrive' && (_oneDriveAccessToken != null || _oneDriveRefreshToken != null)) isRefreshing = true;
    if (serviceName == 'Box' && (_boxAccessToken != null || _boxRefreshToken != null)) isRefreshing = true;
    if (serviceName == 'pCloud' && _pCloudAccessToken != null) isRefreshing = true;
    if (serviceName == 'Mega' && _megaSessionId != null) isRefreshing = true;
    // If they already used their 1 free slot, block them
    if (connectedCount >= 1 && !isRefreshing) {
      _showProDialog(
        title: "Limit Reached",
        message: "Free users can connect 1 cloud account.\n\nYou already have an account connected. Upgrade to Pro to combine multiple clouds!"
      );
      return;
    }
    // If passed all checks, allow login
    loginMethod();
  }
  // --- UI Building ---
 // --- THIS IS THE FULL, REBUILT _buildDrawer METHOD ---
 // --- THIS IS THE FULL, REBUILT _buildDrawer METHOD ---
  // --- PASTE THIS REPLACEMENT METHOD ---
  // --- REBUILT DRAWER TO MATCH SCREENSHOT STYLE ---
  // --- REBUILT DRAWER: MATCHES SCREENSHOT & INCLUDES ALL SERVICES ---
// ✅ REPLACEMENT: Modern Drawer (Larger Size)
  // --- REBUILT DRAWER: MODERN, CLEAN & TRUSTWORTHY ---
 // --- BASIC & CLEAN DRAWER ---
 // --- "THE STRUCTURED SIDEBAR" ---
// --- "THE MODERN CARD DRAWER" ---
// --- "THE CLASSIC BLUE" DRAWER ---
// --- "THE MODERN SOFT" DRAWER ---
Widget _buildDrawer() {
    // 1. Calculate how many accounts are currently connected
    int connectedCount = 0;
    //if (_hasGoogleDriveAccess) connectedCount++;
    if ((_oneDriveAccessToken != null || _oneDriveRefreshToken != null) && !_oneDriveError) connectedCount++;
    if ((_boxAccessToken != null || _boxRefreshToken != null) && !_boxError) connectedCount++;
    if (_pCloudAccessToken != null && !_pCloudError) connectedCount++;
    if (_megaSessionId != null && !_megaError) connectedCount++;
    // 2. Define Lock Logic
    // Dropbox is ALWAYS locked for free users
    bool isDropboxLocked = !_isPro; 
    // Others are locked if you are Free AND have used your 1 slot (and aren't already connected to it)
    bool isSlotFull = !_isPro && connectedCount >= 1;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Drawer(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      surfaceTintColor: Colors.transparent,
      width: 280,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
            topRight: Radius.circular(20), bottomRight: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  // -------------------------------------------
                  // 1. CLICKABLE HEADER (Opens Sign In when guest, Settings when logged in)
                  // -------------------------------------------
                  InkWell(
                    onTap: () {
                       Navigator.pop(context); // Close drawer
                       if (widget.firebaseUser.isAnonymous) {
                         Future.microtask(() {
                           if (mounted) {
                             Navigator.push(
                               context,
                               MaterialPageRoute(builder: (context) => const LoginPage()),
                             );
                           }
                         });
                       } else {
                         Future.microtask(() {
                           if (mounted) {
                             Navigator.push(
                               context,
                               MaterialPageRoute(builder: (context) => _buildSettingsPage()),
                             );
                           }
                         });
                       }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 30),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: isDark ? Colors.blue.shade800 : Colors.blue.shade100, width: 2),
                            ),
                            child: CircleAvatar(
                              radius: 36,
                              backgroundColor: isDark ? Colors.blue.shade900 : Colors.blue.shade50,
                              backgroundImage: widget.firebaseUser.photoURL != null
                                  ? NetworkImage(widget.firebaseUser.photoURL!)
                                  : null,
                              child: widget.firebaseUser.photoURL == null
                                  ? Icon(Icons.person, size: 40, color: isDark ? Colors.blue.shade300 : Colors.blue.shade300)
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.firebaseUser.isAnonymous 
                                ? "Guest Mode" 
                                : (widget.firebaseUser.displayName ?? "User"),
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface),
                          ),
                          const SizedBox(height: 4),
                          if (!widget.firebaseUser.isAnonymous && _isPro)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                "PRO MEMBER",
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange.shade800),
                              ),
                            )
                          else
                            Text(
                              widget.firebaseUser.isAnonymous 
                                ? "Tap to Sign In" 
                                : "Tap for Settings",
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                        ],
                      ),
                    ),
                  ),
                  // -------------------------------------------
                  // 3. MENU ITEMS — Bug Fix 4: Tab-aware features
                  // -------------------------------------------
                  // --- PHOTOS TAB features ---
                  if (_selectedTab == 0) ...[ 
                    _buildSoftItem(Icons.folder_open_rounded, "Albums", false, () {
                      Navigator.pop(context);
                      analytics.logEvent(name: 'screen_view', parameters: {'screen_name': 'Albums'});
                       Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => AlbumsPage(
                                    userDocRef: _userDocRef,
                                    allItems: _driveItems
                                        .where((item) => !_bin.contains(item.getUniqueKey()))
                                        .toList(),
                                    allItemsWithBin: _driveItems,
                                    binKeys: _bin,
                                    onRestore: _restoreFromBin,
                                    onPermanentDelete: _permanentDelete,
                                    albums: _albums,
                                    albumCovers: _albumCovers,
                                    favorites: _favorites,
                                    getThumbnailUrl: _getThumbnailUrl,
                                    getDownloadUrl: _getDownloadUrl,
                                    onAddItemsToAlbum: _addItemsToAlbum,
                                    onFavoriteChanged: (key, isFav) {
                                      _userDocRef.update({
                                        'favorites': isFav
                                            ? FieldValue.arrayUnion([key])
                                            : FieldValue.arrayRemove([key])
                                      });
                                    },
                                    onMoveToBin: _moveToBin,
                                    oneDriveAccessToken: _oneDriveAccessToken,
                                    dropboxAccessToken: _dropboxAccessToken,
                                    boxAccessToken: _boxAccessToken,
                                    useCaching: _useCaching,
                                  )));
                     }),
                  ],
                  // Cloud Hub — cross-cloud insights and management
                  // Cloud Hub — cross-cloud insights and management
                  _buildSoftItem(Icons.cloud_sync_outlined, "Cloud Hub", false, () {
                    Navigator.pop(context);
                    analytics.logEvent(name: 'screen_view', parameters: {'screen_name': 'CloudHub'});
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => CloudHubPage(
                                  driveItems: _driveItems,
                                  bin: _bin,
                                  favorites: _favorites,
                                  albums: _albums,
                                  oneDriveConnected: (_oneDriveAccessToken != null || _oneDriveRefreshToken != null) && !_oneDriveError,
                                  dropboxConnected: (_dropboxAccessToken != null || _dropboxRefreshToken != null) && !_dropboxError,
                                  boxConnected: (_boxAccessToken != null || _boxRefreshToken != null) && !_boxError,
                                  pCloudConnected: _pCloudAccessToken != null && !_pCloudError,
                                  megaConnected: _megaSessionId != null && !_megaError,
                                  isPro: _isPro,
                                  // Pass tokens for storage quota API calls
                                  oneDriveAccessToken: _oneDriveAccessToken,
                                  dropboxAccessToken: _dropboxAccessToken,
                                  boxAccessToken: _boxAccessToken,
                                  pCloudAccessToken: _pCloudAccessToken,
                                   // Pass live AI scan state for Photo Index card
                                   isAiScanning: ForegroundScanner().isScanning.value,
                                   aiScanProgress: ForegroundScanner().progress.value,
                                   aiScanTotal: ForegroundScanner().total.value,
                                   aiScanStatus: ForegroundScanner().status.value,
                                   onUpload: _uploadToProvider,
                                   onDelete: _deleteFromProvider,
                                   onGetDownloadUrl: _getDownloadUrl,
                                )));
                  }),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 8),
                    child: Text("ACCOUNTS",
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[400])),
                  ),
                  // -------------------------------------------
                  // 4. CLOUD SERVICES (With Logic)
                  // -------------------------------------------
                  // OneDrive (Locked if slot full and not already connected)
                  _buildSoftCloudItem(
                      "OneDrive",
                      (_oneDriveAccessToken != null || _oneDriveRefreshToken != null) && !_oneDriveError,
                      isSlotFull && _oneDriveAccessToken == null, // LOCKED?
                      () => _handleCloudLogin('OneDrive',
                          () => _loginOneDrive(fromHomePage: false))),
                  // Dropbox (Locked if NOT Pro)
                  _buildSoftCloudItem(
                      "Dropbox",
                      (_dropboxAccessToken != null || _dropboxRefreshToken != null) && !_dropboxError,
                      isDropboxLocked, // LOCKED?
                      () => _handleCloudLogin(
                          'Dropbox', () => _loginDropbox(fromHomePage: false))),
                  // Box (Locked if slot full)
                  _buildSoftCloudItem(
                      "Box",
                      (_boxAccessToken != null || _boxRefreshToken != null) && !_boxError,
                      isSlotFull && _boxAccessToken == null, // LOCKED?
                      () => _handleCloudLogin(
                          'Box', () => _loginBox(fromHomePage: false))),
                  // pCloud (Locked if slot full)
                  _buildSoftCloudItem(
                      "pCloud",
                      _pCloudAccessToken != null && !_pCloudError,
                      isSlotFull && _pCloudAccessToken == null, // LOCKED?
                      () => _handleCloudLogin('pCloud', _loginToPCloud)),
                  /*
                  // Mega (Locked if slot full)
                  _buildSoftCloudItem(
                      "Mega",
                      _megaSessionId != null && !_megaError,
                      isSlotFull && _megaSessionId == null, // LOCKED?
                      () => _handleCloudLogin('Mega', _loginToMega)),
                  */
                  // Google Drive (Locked if slot full)
                  // Uncomment if you want Google Drive in the list
                  /*
                  _buildSoftCloudItem(
                      "Google Drive",
                      _hasGoogleDriveAccess,
                      isSlotFull && !_hasGoogleDriveAccess, 
                      () => _handleCloudLogin('Google Drive', () => _loginGoogleDrive(fromHomePage: false))),
                  */
                  // EXTRAS — only relevant on Photos tab
                  if (_selectedTab == 0) ...[
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.only(left: 16, bottom: 8),
                      child: Text("TOOLS",
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[400])),
                    ),
                    _buildSoftItem(Icons.copy_all_rounded, "Duplicate Photos", false, () {
                      if (!_isPro) {
                        _showProDialog(title: "Duplicates Finder");
                        return;
                      }
                      Navigator.pop(context);
                      final imageExtensions = {'.jpg', '.jpeg', '.png', '.gif', '.heic', '.heif', '.webp', '.bmp', '.tiff', '.tif'};
                      final imageItemsOnly = _driveItems.where((item) {
                        if (_bin.contains(item.getUniqueKey())) return false;
                        if (item.isFolder) return false;
                        final ext = item.name.toLowerCase();
                        return imageExtensions.any((e) => ext.endsWith(e));
                      }).toList();
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => DuplicatesPage(
                                    allItems: imageItemsOnly,
                                    getThumbnailUrl: _getThumbnailUrl,
                                    getDownloadUrl: _getDownloadUrl,
                                    onMoveToBin: _moveToBin,
                                    onFavoriteChanged: (key, isFav) {
                                      _userDocRef.update({
                                        'favorites': isFav
                                            ? FieldValue.arrayUnion([key])
                                            : FieldValue.arrayRemove([key])
                                      });
                                    },
                                    onShowAddToAlbumDialog: _showAddToAlbumDialog,
                                    oneDriveAccessToken: _oneDriveAccessToken,
                                    dropboxAccessToken: _dropboxAccessToken,
                                    boxAccessToken: _boxAccessToken,
                                    useCaching: _useCaching,
                                    favorites: _favorites,
                                    bin: _bin,
                                  )));
                    }),
                  ],
                  const SizedBox(height: 12),
                ],
              ),
            ),
            // 5. FOOTER
            // Desktop App Banner (above footer)
            _buildDesktopBanner(),
            // Small & subtle Report a Bug option right above Settings and Logout
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                Navigator.pop(context);
                _sendFeedbackOrBugReport(isBug: true);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.bug_report_outlined,
                      size: 13,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      "Report a Bug",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 4.0, bottom: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Settings
                  IconButton(
                    icon: Icon(Icons.settings_outlined, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                    tooltip: "Settings",
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => _buildSettingsPage()));
                    },
                  ),
                  // Logout
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.redAccent),
                    tooltip: "Logout",
                    onPressed: _logout,
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  // --- SUPPORT & FEEDBACK HANDLER ---
  Future<void> _sendFeedbackOrBugReport({required bool isBug}) async {
    final connected = <String>[];
    if ((_oneDriveAccessToken != null || _oneDriveRefreshToken != null) && !_oneDriveError) connected.add("OneDrive");
    if ((_dropboxAccessToken != null || _dropboxRefreshToken != null) && !_dropboxError) connected.add("Dropbox");
    if ((_boxAccessToken != null || _boxRefreshToken != null) && !_boxError) connected.add("Box");
    if (_pCloudAccessToken != null && !_pCloudError) connected.add("pCloud");
    if (_megaSessionId != null && !_megaError) connected.add("Mega");

    final String subject = isBug
        ? "Bug Report - Cloud Photos (${_packageInfo.version})"
        : "Feedback & Suggestions - Cloud Photos";

    final String body = isBug
        ? "\n\n--- Please describe the issue above this line ---\n\n"
          "App Version: ${_packageInfo.version} (${_packageInfo.buildNumber})\n"
          "Connected Clouds: ${connected.isEmpty ? 'None' : connected.join(', ')}\n"
          "User ID: ${widget.firebaseUser.uid}\n"
        : "\n\n--- Tell us what you like or what can be improved ---\n\n"
          "App Version: ${_packageInfo.version} (${_packageInfo.buildNumber})\n";

    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'kartikurkude701@gmail.com',
      queryParameters: {
        'subject': subject,
        'body': body,
      },
    );

    try {
      final bool launched = await launchUrl(emailLaunchUri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        _showEmailFallbackDialog();
      }
    } catch (e) {
      if (mounted) {
        _showEmailFallbackDialog();
      }
    }
  }

  void _showEmailFallbackDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.mail_outline, color: Colors.blueAccent),
            SizedBox(width: 8),
            Text("Contact Support"),
          ],
        ),
        content: const Text(
          "Could not open an email app directly.\n\nPlease email your bug report or feedback to:\n\nkartikurkude701@gmail.com",
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(const ClipboardData(text: "kartikurkude701@gmail.com"));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Email copied to clipboard!")),
              );
            },
            child: const Text("Copy Email"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }
  // --- HELPER 1: Soft Rounded Item ---
  Widget _buildSoftItem(
      IconData icon, String title, bool isSelected, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? Colors.blue[300]! : Colors.blue[700]!;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        leading: Icon(
          icon,
          size: 22,
          color: isSelected ? primary : onSurface.withOpacity(0.6),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? primary : onSurface,
          ),
        ),
        // This shape makes it pill-shaped
        shape: const StadiumBorder(),
        tileColor: isSelected ? primary.withOpacity(0.12) : Colors.transparent,
        onTap: onTap,
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
      ),
    );
  }
  // --- HELPER 2: Soft Cloud Item ---
 // --- HELPER 2: Soft Cloud Item (Now with LOCKS) ---
  Widget _buildSoftCloudItem(String name, bool isConnected, bool isLocked, VoidCallback onTap) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return ListTile(
      leading: Icon(
        // If connected: Green Check
        // If locked: Grey Lock
        // If available: Empty Circle
        isConnected ? Icons.check_circle : (isLocked ? Icons.lock_outline : Icons.circle_outlined),
        color: isConnected ? Colors.green : (isLocked ? Colors.grey : onSurface.withOpacity(0.4)),
        size: 18,
      ),
      title: Text(
        name,
        style: TextStyle(
            fontSize: 14,
            // Grey out text if locked
            color: isConnected ? onSurface : (isLocked ? Colors.grey : onSurface.withOpacity(0.6))),
      ),
      trailing: isConnected
          ? null // Nothing if connected
          : (isLocked
              // Show Lock icon if locked
              ? const Icon(Icons.lock, size: 16, color: Colors.grey) 
              // Show Blue Plus if available
              : const Icon(Icons.add, size: 18, color: Colors.blue)),
      onTap: onTap,
      dense: true,
      visualDensity: const VisualDensity(vertical: -2),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
    );
  }
  // --- Desktop App Promo Banner ---
  Future<void> _dismissDesktopBanner() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('desktop_banner_dismissed', true);
    if (mounted) setState(() => _isDesktopBannerDismissed = true);
  }
  Widget _buildDesktopBanner() {
    // Desktop promotion banner permanently disabled
    return const SizedBox.shrink();
    // ignore: dead_code
    if (_isDesktopBannerDismissed) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F6FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBDD7F5), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFDCEEFD),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.desktop_windows_rounded,
                color: Color(0xFF1565C0), size: 22),
          ),
          const SizedBox(width: 12),
          // Text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Unified Gallery Desktop',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A2744),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'View all your cloud photos on your PC.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final uri = Uri.parse('https://imagstore.com');
                    if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                  child: Text(
                    'imagstore.com →',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1565C0),
                      decoration: TextDecoration.underline,
                      decorationColor: const Color(0xFF1565C0).withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Dismiss button
          GestureDetector(
            onTap: _dismissDesktopBanner,
            child: const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.close, size: 16, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
  // --- HELPER 1: Standard Item ---
  Widget _buildClassicItem(
      IconData icon, String title, bool isSelected, VoidCallback onTap) {
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? const Color(0xFF1565C0) : Colors.grey[700],
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? const Color(0xFF1565C0) : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onTap: onTap,
      dense: true,
      visualDensity: const VisualDensity(vertical: -1),
    );
  }
  // --- HELPER 2: Cloud Item (Simple Text Status) ---
  Widget _buildClassicCloudItem(
      String name, bool isConnected, VoidCallback onTap) {
    return ListTile(
      leading: Icon(
        isConnected ? Icons.cloud_done : Icons.cloud_off,
        color: isConnected ? Colors.green : Colors.grey,
      ),
      title: Text(name),
      trailing: Text(
        isConnected ? "Connected" : "Link",
        style: TextStyle(
          color: isConnected ? Colors.green : Colors.blue,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      onTap: onTap,
      dense: true,
      visualDensity: const VisualDensity(vertical: -2),
    );
  }
  // --- HELPERS FOR CARD STYLE ---
  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 6),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
      ),
    );
  }
  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12), // Rounded card
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))
        ]
      ),
      child: Column(children: children),
    );
  }
  Widget _buildDivider() {
    return const Divider(height: 1, thickness: 1, color: Color(0xFFF2F2F7), indent: 50);
  }
  Widget _buildCardItem(IconData icon, String title, {Color? iconColor, VoidCallback? onTap, bool isLocked = false, String? subtitle}) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: (iconColor ?? Colors.blue).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20, color: iconColor ?? Colors.blue),
      ),
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(fontSize: 12)) : null,
      trailing: isLocked 
          ? const Icon(Icons.lock_outline, size: 16, color: Colors.grey)
          : const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      onTap: onTap,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }
  Widget _buildCloudItem(String name, bool isConnected, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isConnected ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          isConnected ? Icons.cloud_done : Icons.cloud_off, 
          size: 20, 
          color: isConnected ? Colors.green : Colors.grey
        ),
      ),
      title: Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isConnected ? "Connected" : "Not Linked",
            style: TextStyle(
              fontSize: 12, 
              color: isConnected ? Colors.green : Colors.grey
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
        ],
      ),
    );
  }
  // --- HELPER: Rounded List Item ---
  Widget _buildRoundedItem(IconData icon, String title, bool isSelected, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFE3F2FD) : Colors.transparent, // Highlight background
        borderRadius: BorderRadius.circular(10), // Rounded corners
      ),
      child: ListTile(
        leading: Icon(
          icon,
          size: 22,
          color: isSelected ? const Color(0xFF1565C0) : Colors.black54,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? const Color(0xFF1565C0) : Colors.black87,
          ),
        ),
        dense: true,
        visualDensity: const VisualDensity(vertical: -1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onTap: onTap,
      ),
    );
  }
  // --- HELPER: Cloud Status Item (Vertical) ---
  Widget _buildStatusItem(String name, bool isConnected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Row(
          children: [
            // Status Dot
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isConnected ? Colors.green : Colors.grey[300],
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            // Cloud Name
            Text(
              name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isConnected ? Colors.black87 : Colors.grey[600],
              ),
            ),
            const Spacer(),
            // Action Text
            if (!isConnected)
              const Text(
                "Connect",
                style: TextStyle(fontSize: 12, color: Color(0xFF1565C0), fontWeight: FontWeight.w600),
              ),
          ],
        ),
      ),
    );
  }
  // --- HELPER 1: Standard List Item ---
  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isSelected = false,
    bool isLocked = false,
    String? subtitle,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
      leading: Icon(
        icon,
        size: 22,
        color: isSelected ? const Color(0xFF1565C0) : Colors.black54, // Blue if selected
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          color: isSelected ? const Color(0xFF1565C0) : Colors.black87,
        ),
      ),
      subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(fontSize: 12)) : null,
      trailing: isLocked 
          ? const Icon(Icons.lock_outline, size: 16, color: Colors.grey) 
          : null,
      onTap: onTap,
      dense: true,
      visualDensity: const VisualDensity(vertical: -1),
    );
  }
  // --- HELPER 2: Simple Cloud Icon Status ---
  Widget _buildCloudIcon(IconData icon, bool isConnected) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        // Blue background if connected, Grey if not
        color: isConnected ? const Color(0xFFE3F2FD) : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        icon,
        size: 20,
        // Blue icon if connected, Grey if not
        color: isConnected ? const Color(0xFF1565C0) : Colors.grey[400],
      ),
    );
  }
  // --- DRAWER HELPER METHODS ---
  /// Creates a small section title (e.g., "LIBRARY")
  Widget _buildDrawerSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8, top: 8),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.grey[500],
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
  /// Specialized builder for Cloud Service items (shows status/lock)
  Widget _buildCloudDrawerItem(String name, IconData icon, bool isConnected, bool isLocked, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      child: ListTile(
        leading: Icon(
          icon, 
          color: isConnected ? const Color(0xFF1565C0) : Colors.grey[400], // Blue if connected
          size: 22
        ),
        title: Text(
          name,
          style: TextStyle(
            fontSize: 15, 
            fontWeight: FontWeight.w500,
            color: isConnected ? Colors.black87 : Colors.grey[600]
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isConnected) 
              const Icon(Icons.check_circle, color: Colors.green, size: 18), // Success indicator
            if (isLocked) 
              const Icon(Icons.lock_outline, size: 18, color: Colors.grey), // Lock indicator
          ],
        ),
        dense: true,
        visualDensity: const VisualDensity(vertical: -1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        onTap: onTap,
      ),
    );
  }
  // --- UPDATED Helpers for Larger UI ---
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 13, // Slightly larger
          fontWeight: FontWeight.bold,
          color: Colors.grey[700],
          letterSpacing: 1.2,
        ),
      ),
    );
  }
  // --- Unified Settings Page ---
  Widget _buildSettingsPage() {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? null : Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black
        ),
        title: Text(
            "Settings",
            style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black
            )
        ),
      ),
      body: StatefulBuilder(
        builder: (BuildContext context, StateSetter setSettingsState) {
          return ListView(
            children: [
              // --- THEME SETTINGS ---
              ListTile(
                leading: const Icon(Icons.brightness_6_outlined),
                title: const Text("Application Theme"),
                subtitle: const Text("Choose default theme"),
                trailing: DropdownButton<ThemeMode>(
                  value: themeNotifier.value,
                  onChanged: (ThemeMode? newMode) async {
                    if (newMode != null) {
                      themeNotifier.value = newMode;
                      await _saveThemePreference(newMode);
                      setSettingsState(() {});
                      setState(() {});
                    }
                  },
                  items: const [
                    DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
                    DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                    DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
                  ],
                ),
              ),
              const Divider(height: 24),
              // --- BIN BEHAVIOR ---
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
                child: Text("Bin & Deletion",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold
                  )
                ),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.delete_forever_outlined),
                title: const Text("Delete from Cloud/Device"),
                subtitle: Text(
                  _binDeleteFromCloud
                    ? "Permanently removes files from cloud storage and device gallery when deleted from Bin"
                    : "Removes files from this app only — files stay on the cloud/device",
                ),
                value: _binDeleteFromCloud,
                onChanged: (bool value) {
                  _saveBinDeletePreference(value);
                  setSettingsState(() {});
                },
              ),
              const Divider(height: 24),
              // --- DATA MANAGEMENT ---
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
                child: Text("Data Management",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold
                  )
                ),
              ),
              ListTile(
                leading: const Icon(Icons.delete_sweep_outlined),
                title: const Text("Clear Cache"),
                subtitle: const Text("Free up temporary thumbnail storage"),
                onTap: () async {
                  await _clearImageCache();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("✨ Cache cleared successfully!"),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
              // --- ABOUT & SUPPORT ---
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
                child: Text("Support",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold
                  )
                ),
              ),
              ListTile(
                leading: const Icon(Icons.help_outline_rounded),
                title: const Text("Help & Feedback"),
                subtitle: const Text("Report a bug, suggest features, app info"),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => _buildAboutPage()),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.no_accounts, color: Theme.of(context).colorScheme.error),
                title: Text("Delete Account", style: TextStyle(color: Theme.of(context).colorScheme.error)),
                subtitle: const Text("Permanently remove account & all data"),
                onTap: _showDeleteAccountDialog,
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
  Widget _buildAboutPage() {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("About & Feedback"),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text("App Version"),
            subtitle: Text("${_packageInfo.version} (${_packageInfo.buildNumber})"),
          ),
          ListTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: const Text("Report a Bug"),
            subtitle: const Text("Send diagnostic info & issue details"),
            onTap: () => _sendFeedbackOrBugReport(isBug: true),
          ),
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: const Text("Send Feedback"),
            subtitle: const Text("Suggest features or improvements"),
            onTap: () => _sendFeedbackOrBugReport(isBug: false),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text("Privacy Policy"),
            onTap: _openPrivacyPolicy,
          ),
          ListTile(
            leading: const Icon(Icons.gavel),
            title: const Text("Terms of Service"),
            onTap: () {
               // Add URL launcher logic here if you have a Terms page
            },
          ),
        ],
      ),
    );
  }
  Widget _buildBody() {
      final displayedItems = _filteredDriveItems;
    // Get either the grouped map or the flat sorted list
    final dynamic itemsData = _getGroupedOrSortedItems(displayedItems);
    // --- START OF NEW LOGIC ---
    // Check if we should show the "Connections" welcome page.
    // This is true if:
    // 1. We are not loading.
    // 2. We are not in a search/filter view.
    // 3. Both accounts are disconnected (and not in an error state).
    // 4. We have no drive items at all.
    final bool showConnectionsPage = !_isLoading &&
        _driveItems.isEmpty &&
        _searchQuery.isEmpty &&
        _currentSourceFilter == FilterSource.all &&
        _currentTypeFilter == FilterType.all &&
        _oneDriveAccessToken == null &&
        _dropboxAccessToken == null &&
        _boxAccessToken == null && // ✅ ADD
        _pCloudAccessToken == null && // <--- ADDED THIS!
        _megaSessionId == null && // ✅ MEGA
     //   !_hasGoogleDriveAccess && // ✅ FIX: Also check Google Drive
        !_oneDriveError &&
        !_dropboxError&&
        !_boxError&& // ✅ ADD
        !_pCloudError &&
        !_megaError; // ✅ MEGA
    if (showConnectionsPage) {
      return _buildConnectionsBody(); // Show the new welcome page
    }
    // --- END OF NEW LOGIC ---
  // ... inside _buildBody() ...
if (_isFirestoreLoading || _isAiSearching || (_isLoading && displayedItems.isEmpty && !_oneDriveError && !_dropboxError)) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 20),
        Text(
            _isFirestoreLoading
                ? 'Loading your data...'
                : _isAiSearching // ✅ ADD THIS
                    ? 'Searching...' // ✅ ADD THIS
                    : _statusMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16)),
      ],
    ),
  );
}
// ... (rest of _buildBody) ...
    // ✅ PASTE THIS REPLACEMENT BLOCK
    if (displayedItems.isEmpty) {
      // --- START OF NEW POLISHED EMPTY STATE ---
      IconData icon;
      String title;
      String subtitle;
      // Check for search/filter results
      if (_searchQuery.isNotEmpty ||
          _currentSourceFilter != FilterSource.all ||
          _currentTypeFilter != FilterType.all) {
        icon = Icons.search_off_rounded;
        title = 'No Results Found';
        subtitle = 'Try adjusting your search or filters.';
      } 
      // Check for connection errors
      else if (_oneDriveError || _dropboxError) {
        icon = Icons.cloud_off_rounded;
        title = 'Connection Failed';
        subtitle = _statusMessage; // This already has the error (e.g., "Connection to Dropbox failed...")
      } 
      // Check for no photos found in connected accounts
      else if (_driveItems.isEmpty &&
          (_oneDriveAccessToken != null || _dropboxAccessToken != null)) {
        icon = Icons.photo_library_outlined;
        title = 'No Photos Found';
        subtitle = 'Your connected accounts dont have any photos or videos.';
      } 
      // This is the default "no photos" message
      else {
        icon = Icons.photo_library_outlined;
        title = 'No Photos';
        subtitle = 'Your photo gallery is empty.';
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 100,
                color: _oneDriveError || _dropboxError ? Colors.red.shade300 : Colors.grey[600],
              ),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.black54),
              ),
            ],
          ),
        ),
      );
      // --- END OF NEW POLISHED EMPTY STATE ---
    }
     return RefreshIndicator(
  color: Theme.of(context).primaryColor,
  backgroundColor: Theme.of(context).cardColor,
  onRefresh: () async {
    // This triggers the manual sync when you pull down
    await _fetchAllPhotos(firstPage: true);
  },
  child: NotificationListener<ScrollNotification>(
    onNotification: (ScrollNotification scrollInfo) {
      if (scrollInfo.metrics.axis == Axis.vertical &&
          !_isLoading &&
          !_isLoadingMore &&
          (_hasMoreDropbox || _hasMoreLocal) &&
          scrollInfo.metrics.pixels >=
              scrollInfo.metrics.maxScrollExtent - 600) {
        _fetchAllPhotos(firstPage: false);
      }
      return false;
    },
       child: CustomScrollView(
         key: const PageStorageKey('photos_scroll_view'),
         cacheExtent: 600.0, // PERF: halved to limit off-screen GPU work
         slivers: [
           // --- Conditionally build grouped or flat list ---
           if (itemsData is List<MapEntry<String, List<DriveItem>>>) ...[
              // Build grouped view (original logic)
              for (final group in itemsData) ...[
                SliverToBoxAdapter(
                  key: ValueKey('header_${group.key}'),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                    child: Text(
                      group.key,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                SliverPadding(
                  key: ValueKey('grid_${group.key}'),
                  padding: const EdgeInsets.all(2.0),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4, crossAxisSpacing: 2.0, mainAxisSpacing: 2.0,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = group.value[index];
                        final itemKey = item.getUniqueKey();
                        return RepaintBoundary(
                         child: PhotoThumbnail(
                          key: ValueKey(itemKey),
                           item: item,
                           getThumbnailUrl: _getThumbnailUrl,
                           useCaching: _useCaching,
                           isFavorite: _favorites.contains(itemKey),
                           isInSelectionMode: _isSelecting,
                           isSelected: _selectedItemKeys.contains(itemKey),
                           onLongPress: () => _toggleSelectionMode(initialKey: itemKey),
                           onTap: () {
                             if (_isSelecting) {
                               _toggleItemSelection(itemKey);
                             } else {
                               _getThumbnailUrl(item); // Pre-fetch thumbnail URL
                               final originalIndex = displayedItems.indexWhere(
                                   (i) => i.getUniqueKey() == itemKey);
                               if (originalIndex != -1) {
                                // --- START OF PRE-FETCH ---
                                _getDownloadUrl(item); 
                                if (originalIndex + 1 < displayedItems.length) {
                                  _getDownloadUrl(displayedItems[originalIndex + 1]);
                                }
                                if (originalIndex - 1 >= 0) {
                                  _getDownloadUrl(displayedItems[originalIndex - 1]);
                                }
                                // --- END OF PRE-FETCH ---
                                 Navigator.push(
                                   context,
                                   MaterialPageRoute(
                                     builder: (context) => PhotoViewerPage(
                                       items: displayedItems,
                                       initialIndex: originalIndex,
                                       getDownloadUrl: _getDownloadUrl,
                                       getThumbnailUrl: _getThumbnailUrl,
                                       favorites: _favorites,
                                       bin: _bin,
                                       onFavoriteChanged: (key, isFavorite) {
                                           _userDocRef.update({
                                             'favorites': isFavorite ? FieldValue.arrayUnion([key]) : FieldValue.arrayRemove([key])
                                           });
                                       },
                                       onMoveToBin: _moveToBin,
                                       onAddToAlbum: (item) => _showAddToAlbumDialog([item.getUniqueKey()]),
                                       oneDriveAccessToken: _oneDriveAccessToken,
                                       dropboxAccessToken: _dropboxAccessToken,
                                       boxAccessToken: _boxAccessToken,
                                       useCaching: _useCaching,
                                     ),
                                   ),
                                 );
                               }
                             }
                           },
                           onFavoriteTap: () {
                             if (_isSelecting) return;
                             final key = item.getUniqueKey();
                             final isFavorite = _favorites.contains(key);
                             _userDocRef.update({
                               'favorites': !isFavorite ? FieldValue.arrayUnion([key]) : FieldValue.arrayRemove([key])
                             });
                           },
                         ),
                        );
                      },
                      childCount: group.value.length,
                      addAutomaticKeepAlives: false, // PERF: allow Flutter to recycle off-screen tiles
                      addRepaintBoundaries: true,
                    ),
                  ),
                ),
              ],
           ] else if (itemsData is List<DriveItem>) ...[
             // Build flat grid view (when sorted by name)
             SliverPadding(
               key: const ValueKey('flat_grid'),
               padding: const EdgeInsets.all(2.0),
               sliver: SliverGrid(
                 gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                   crossAxisCount: 4, crossAxisSpacing: 2.0, mainAxisSpacing: 2.0,
                 ),
                 delegate: SliverChildBuilderDelegate(
                   (context, index) {
                     final item = itemsData[index];
                     final itemKey = item.getUniqueKey();
                     return RepaintBoundary(
                       child: PhotoThumbnail(
                         key: ValueKey(itemKey),
                         item: item,
                         getThumbnailUrl: _getThumbnailUrl,
                         useCaching: _useCaching,
                         isFavorite: _favorites.contains(itemKey),
                         isInSelectionMode: _isSelecting,
                         isSelected: _selectedItemKeys.contains(itemKey),
                         onLongPress: () => _toggleSelectionMode(initialKey: itemKey),
                         onTap: () {
                           if (_isSelecting) {
                             _toggleItemSelection(itemKey);
                           } else {
                             _getThumbnailUrl(item);
                             final originalIndex = itemsData.indexWhere(
                                 (i) => i.getUniqueKey() == itemKey);
                             if (originalIndex != -1) {
                               // Pre-fetch surrounding items
                               _getDownloadUrl(item);
                               if (originalIndex + 1 < itemsData.length) {
                                 _getDownloadUrl(itemsData[originalIndex + 1]);
                               }
                               if (originalIndex - 1 >= 0) {
                                 _getDownloadUrl(itemsData[originalIndex - 1]);
                               }
                               Navigator.push(
                                 context,
                                 MaterialPageRoute(
                                   builder: (context) => PhotoViewerPage(
                                     items: itemsData,
                                     initialIndex: originalIndex,
                                     getDownloadUrl: _getDownloadUrl,
                                     getThumbnailUrl: _getThumbnailUrl,
                                     favorites: _favorites,
                                     bin: _bin,
                                     onFavoriteChanged: (key, isFavorite) {
                                       _userDocRef.update({
                                         'favorites': isFavorite ? FieldValue.arrayUnion([key]) : FieldValue.arrayRemove([key])
                                       });
                                     },
                                     onMoveToBin: _moveToBin,
                                     onAddToAlbum: (item) => _showAddToAlbumDialog([item.getUniqueKey()]),
                                     oneDriveAccessToken: _oneDriveAccessToken,
                                     dropboxAccessToken: _dropboxAccessToken,
                                     boxAccessToken: _boxAccessToken,
                                     useCaching: _useCaching,
                                   ),
                                 ),
                               );
                             }
                           }
                         },
                         onFavoriteTap: () {
                           if (_isSelecting) return;
                           final key = item.getUniqueKey();
                           final isFavorite = _favorites.contains(key);
                           _userDocRef.update({
                             'favorites': !isFavorite ? FieldValue.arrayUnion([key]) : FieldValue.arrayRemove([key])
                           });
                         },
                        ), // PhotoThumbnail
                      ); // RepaintBoundary
                   },
                    childCount: itemsData.length,
                    addAutomaticKeepAlives: false, // PERF: allow Flutter to recycle off-screen tiles
                    addRepaintBoundaries: true,
                 ),
               ),
             ),
           ],
           if (_isLoadingMore)
             const SliverToBoxAdapter(
               child: Padding(
                 padding: EdgeInsets.symmetric(vertical: 24.0),
                 child: Center(
                   child: SizedBox(
                     width: 24,
                     height: 24,
                     child: CircularProgressIndicator(strokeWidth: 2.5),
                   ),
                 ),
               ),
             ),
         ],
       ),
     )
     );
   }
   // --- PASTE THIS NEW METHOD ---
  // --- PASTE THIS REPLACEMENT METHOD ---
  Widget _buildConnectionsBody() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.cloud_queue_rounded,
              size: 100,
              color: Color(0xFF0078D4),
            ),
            const SizedBox(height: 24),
            Text(
              'Welcome, ${widget.firebaseUser.displayName?.split(' ').first ?? 'User'}!',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold), // <-- CORRECT
            ),
            const SizedBox(height: 12),
            Text(
              'Get started by connecting your first cloud account.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.black54),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              icon: const Icon(Icons.cloud_upload_outlined, color: Colors.white),
              label: const Text('Connect OneDrive', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0078D4), // OneDrive blue
                minimumSize: const Size(double.infinity, 50),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              onPressed: () {
                _loginOneDrive(fromHomePage: true);
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.all_inbox, color: Colors.white),
              label: const Text('Connect Dropbox', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0061FE), // Dropbox blue
                minimumSize: const Size(double.infinity, 50),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            onPressed: () {
  // ✅ SECURE: Checks if user is Pro or has Free Slot left
  _handleCloudLogin('Dropbox', () {
     _loginDropbox(fromHomePage: true);
  });
},
            ),
            // ✅ NEW: Google Drive Button
        /*    const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.add_to_drive_outlined, color: Colors.white),
              label: const Text('Connect Google Drive', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F9D58), // Google Green
                minimumSize: const Size(double.infinity, 50),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              onPressed: () {
                _loginGoogleDrive(fromHomePage: true);
              },
            ),*/
            const SizedBox(height: 24),
            // ✅ NEW: Box Button
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.inventory_2_outlined, color: Colors.white),
              label: const Text('Connect Box', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF005FED), // Box Blue
                minimumSize: const Size(double.infinity, 50),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              onPressed: () {
                _loginBox(fromHomePage: true);
              },
            ),
            Text(
              "You can add more accounts later from the side menu.",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),
            // Desktop app promo banner
            _buildDesktopBanner(),
          ],
        ),
      ),
    );
  }
  AppBar _buildAppBar() {
    // --- CONTEXTUAL APP BAR (Selection Mode) ---
    if (_isSelecting) {
      return AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _toggleSelectionMode,
        ),
        title: Text(
          '${_selectedItemKeys.length} selected',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold),
        ),
        elevation: 1,
        actions: [
           if (_isBatchDownloading || _isBatchSharing)
              Container(
                padding: const EdgeInsets.only(right: 16.0),
                child: Center(
                  child: SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary),
                  ),
                ),
              ),
        ],
      );
    }
    // --- Bug Fix 6: FILES TAB SEARCH MODE ---
    if (_selectedTab == 1 && _isFilesSearching) {
      return AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            setState(() { _isFilesSearching = false; _filesSearchController.clear(); });
            _filesPageKey.currentState?.applySearch('');
          },
        ),
        title: TextField(
          controller: _filesSearchController,
          autofocus: true,
          style: TextStyle(fontSize: 18, color: Theme.of(context).colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: 'Search files...',
            hintStyle: TextStyle(color: Theme.of(context).hintColor),
            border: InputBorder.none,
          ),
          onChanged: (value) => _filesPageKey.currentState?.applySearch(value),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              _filesSearchController.clear();
              _filesPageKey.currentState?.applySearch('');
            },
          ),
        ],
      );
    }
    // --- PHOTOS TAB SEARCH MODE ---
    if (_selectedTab == 0 && _isSearching) {
      return AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() { _isSearching = false; _searchController.clear(); }),
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: TextStyle(fontSize: 18, color: Theme.of(context).colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: 'Search photos...',
            hintStyle: TextStyle(color: Theme.of(context).hintColor),
            border: InputBorder.none,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => _searchController.clear(),
          ),
        ],
      );
    }
    // --- Bug Fix 6: FILES TAB STANDARD APP BAR ---
    if (_selectedTab == 1) {
      return AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
        title: Text(
          'Files',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        actions: [
          // Search for Files
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => setState(() => _isFilesSearching = true),
          ),
          // Duplicate Files
          IconButton(
            icon: const Icon(Icons.copy_all_rounded),
            tooltip: 'Find Duplicate Files',
            onPressed: () {
              if (_isPro) {
                final filesState = _filesPageKey.currentState;
                if (filesState != null) {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => DuplicateFinderPage(
                    items: filesState._allDocs,
                    onDelete: _moveToBin,
                    onRefresh: () => _filesPageKey.currentState?._fetchAllDocs(),
                  )));
                }
              } else {
                _showProDialog(title: 'Duplicate File Finder');
              }
            },
          ),
          // Refresh Files
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Files',
            onPressed: () => _filesPageKey.currentState?._fetchAllDocs(),
          ),
        ],
      );
    }
    // --- PHOTOS STANDARD APP BAR ---
    return AppBar(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      elevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
      title: Text(
        'Gallery',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.bold,
          fontSize: 22,
        ),
      ),
      actions: [
        // AI Button
        IconButton(
          icon: Icon(
            Icons.auto_awesome,
            color: _isPro ? Colors.amber.shade700 : Colors.grey,
          ),
          onPressed: () {
             if (_isPro) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('AI Search Active')));
             } else {
               _showProDialog();
             }
          },
          tooltip: 'AI Tools',
        ),
        // Search (Photos)
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: () => setState(() => _isSearching = true),
        ),
        // Sort and Filter (Photos)
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (String result) {
            if (result == 'sort') {
              _showSortDialog();
            } else if (result == 'filter') {
              _showFilterDialog();
            }
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            const PopupMenuItem<String>(
              value: 'sort',
              child: Row(
                children: [
                  Icon(Icons.sort, size: 20),
                  SizedBox(width: 12),
                  Text('Sort'),
                ],
              ),
            ),
            const PopupMenuItem<String>(
              value: 'filter',
              child: Row(
                children: [
                  Icon(Icons.filter_list, size: 20),
                  SizedBox(width: 12),
                  Text('Filter'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
   // --- MULTI-SELECT: Build Bottom Action Bar ---
   Widget? _buildBottomActionBar() {
      if (!_isSelecting) return null;
      // Determine initial favorite state for the toggle button
      bool allFavorited = _selectedItemKeys.isNotEmpty &&
                          _selectedItemKeys.every((key) => _favorites.contains(key));
      return BottomAppBar(
         child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              IconButton(
                icon: Icon(allFavorited ? Icons.favorite : Icons.favorite_border),
                tooltip: allFavorited ? 'Unfavorite Selected' : 'Favorite Selected',
                // Disable button while another batch action is running
                onPressed: (_isBatchDownloading || _isBatchSharing) ? null : _batchFavoriteSelected,
              ),
              IconButton(
                icon: const Icon(Icons.playlist_add),
                tooltip: 'Add Selected to Album',
                onPressed: (_isBatchDownloading || _isBatchSharing) ? null : _batchAddToAlbumSelected,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Move Selected to Bin',
                onPressed: (_isBatchDownloading || _isBatchSharing) ? null : _batchMoveToBinSelected,
              ),
              // --- Share and Download Buttons ---
              _isBatchSharing
                ? const Padding(
                    // Use padding to match IconButton's tap target size
                    padding: EdgeInsets.all(12.0),
                    child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)),
                  )
                : IconButton(
                    icon: const Icon(Icons.share_outlined),
                    tooltip: 'Share Selected',
                    // Disable button while another batch action is running
                    onPressed: (_isBatchDownloading || _isBatchSharing) ? null : _batchShareSelected,
                  ),
              _isBatchDownloading
                ? const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)),
                  )
                : IconButton(
                    icon: const Icon(Icons.download_outlined),
                    tooltip: 'Download Selected',
                    // Disable button while another batch action is running
                    onPressed: (_isBatchDownloading || _isBatchSharing) ? null : _batchDownloadSelected,
                  ),
            ],
         ),
      );
   }
   Future<List<String>> _generateTagsFromImage(File imageFile) async {
    try {
      final ImageLabeler labeler = ImageLabeler(
        options: ImageLabelerOptions(confidenceThreshold: 0.6),
      );
      final InputImage inputImage = InputImage.fromFile(imageFile);
      final List<ImageLabel> labels = await labeler.processImage(inputImage);
      await labeler.close(); // Close to free memory
      final tags = labels.map((e) => e.label).toList();
      debugPrint("✅ AI tags generated: $tags");
      return tags;
    } catch (e) {
      debugPrint("❌ AI tagging failed: $e");
      debugPrint("❌ AI tagging failed: $e");
      return [];
    }
  }
Future<void> _analyzeImageForTags(String imageUrl, DriveItem item) async {
    try {
      final dir = await getTemporaryDirectory();
      // ✅ FIX: Sanitize filename (Android crashes if filenames have ':')
      final safeFileName = imageUrl.split('/').last.replaceAll(':', '_');
      final filePath = '${dir.path}/$safeFileName';
      final file = File(filePath);
      // Only download if we haven't already
      if (!await file.exists()) {
        if (imageUrl.startsWith('http')) {
          final response = await http.get(Uri.parse(imageUrl));
          await file.writeAsBytes(response.bodyBytes);
        } else {
          return; // Skip if not a valid URL
        }
      }
      final tags = await _generateTagsFromImage(file);
      // ✅ mounted and setState will now work because we are inside the class
      if (mounted) {
         setState(() {
           item.aiTags = tags; // Use .aiTags for DriveItem
         });
      }
      // Cleanup to save space
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint("❌ Tag generation failed for ${item.name}: $e");
    }
  }
  @override
  Widget build(BuildContext context) {
    // Consent is given, show the main app
    return Scaffold(
      appBar: _buildAppBar(),
      drawer: _buildDrawer(),
      body: _buildBody(),
      // If in multi-select mode show the action bar; otherwise no bottom nav needed
      bottomNavigationBar: _isSelecting ? _buildBottomActionBar() : null,
    );
  }
  // =============================================================================
  // --- FILES TAB: Helper Methods (Ported from Unified Files App) ---
  // =============================================================================
  IconData _getSourceIcon(PhotoSource source) {
    switch (source) {
      case PhotoSource.oneDrive: return Icons.cloud_outlined;
      case PhotoSource.dropbox: return Icons.storage_rounded;
      case PhotoSource.box: return Icons.archive_outlined;
      case PhotoSource.pCloud: return Icons.cloud_download_outlined;
      default: return Icons.cloud_queue;
    }
  }
  Color _getSourceColor(PhotoSource source) {
    switch (source) {
      case PhotoSource.oneDrive: return const Color(0xFF0078D4);
      case PhotoSource.dropbox: return const Color(0xFF0061FF);
      case PhotoSource.box: return const Color(0xFF0061D5);
      case PhotoSource.pCloud: return const Color(0xFF2ECC71);
      default: return Colors.grey;
    }
  }
  /// Shows a bottom sheet to move a file to another connected cloud. Pro-only.
  void _showMoveToCloudSheet(DriveItem item) {
    if (!_isPro) {
      _showProDialog(
        title: 'Cloud Transfer',
        message: 'Moving files between clouds is a Pro feature. Upgrade to seamlessly transfer files across all your accounts.',
      );
      return;
    }
    const int maxTransferSize = 5 * 1024 * 1024; // 5 MB
    if (item.size != null && item.size! > maxTransferSize) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File too large for transfer (5 MB limit).')),
      );
      return;
    }
    final List<PhotoSource> otherConnected = [];
    if (_oneDriveAccessToken != null && item.source != PhotoSource.oneDrive) otherConnected.add(PhotoSource.oneDrive);
    if (_dropboxAccessToken != null && item.source != PhotoSource.dropbox) otherConnected.add(PhotoSource.dropbox);
    if (_boxAccessToken != null && item.source != PhotoSource.box) otherConnected.add(PhotoSource.box);
    if (_pCloudAccessToken != null && item.source != PhotoSource.pCloud) otherConnected.add(PhotoSource.pCloud);
    if (otherConnected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No other cloud accounts connected.')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Move File to...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ...otherConnected.map((source) => ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getSourceColor(source).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_getSourceIcon(source), color: _getSourceColor(source), size: 20),
                ),
                title: Text(source.name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  _transferCloudFile(item, source);
                },
              )),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }
  /// Upload a local [file] with [name] to [destination] cloud. Pro-only write feature.
  Future<bool> _uploadToProvider(File file, String name, PhotoSource destination) async {
    String? token;
    if (destination == PhotoSource.oneDrive) token = _oneDriveAccessToken;
    else if (destination == PhotoSource.dropbox) token = _dropboxAccessToken;
    else if (destination == PhotoSource.box) token = _boxAccessToken;
    else if (destination == PhotoSource.pCloud) token = _pCloudAccessToken;
    if (token == null) return false;
    try {
      if (destination == PhotoSource.oneDrive) {
        final url = Uri.parse('https://graph.microsoft.com/v1.0/me/drive/root:/$name:/content');
        final response = await http.put(url,
          headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/octet-stream'},
          body: await file.readAsBytes(),
        );
        return response.statusCode == 200 || response.statusCode == 201;
      } else if (destination == PhotoSource.dropbox) {
        final url = Uri.parse('https://content.dropboxapi.com/2/files/upload');
        final arg = jsonEncode({
          'path': '/$name',
          'mode': 'add',
          'autorename': true,
          'mute': false,
          'strict_conflict': false,
        });
        final response = await http.post(url,
          headers: {
            'Authorization': 'Bearer $token',
            'Dropbox-API-Arg': arg,
            'Content-Type': 'application/octet-stream',
          },
          body: await file.readAsBytes(),
        );
        return response.statusCode == 200;
      } else if (destination == PhotoSource.box) {
        final url = Uri.parse('https://upload.box.com/api/2.0/files/content');
        final request = http.MultipartRequest('POST', url);
        request.headers['Authorization'] = 'Bearer $token';
        request.fields['attributes'] = jsonEncode({'name': name, 'parent': {'id': '0'}});
        request.files.add(await http.MultipartFile.fromPath('file', file.path));
        final response = await request.send();
        return response.statusCode == 201;
      } else if (destination == PhotoSource.pCloud) {
        final String? locationId = await secureStorage.read(key: _userKey('pcloud_location_id'));
        final String primaryHost = (locationId == '2') ? 'eapi.pcloud.com' : 'api.pcloud.com';
        final String fallbackHost = (locationId == '2') ? 'api.pcloud.com' : 'eapi.pcloud.com';

        Future<bool> sendUpload(String host) async {
          try {
            final url = Uri.https(host, '/uploadfile', {
              'folderid': '0',
              'access_token': token,
              'nopartial': '1',
            });
            final request = http.MultipartRequest('POST', url);
            request.files.add(await http.MultipartFile.fromPath('file', file.path));
            final streamedResponse = await request.send().timeout(const Duration(minutes: 5));
            if (streamedResponse.statusCode == 200) {
              final body = await streamedResponse.stream.bytesToString();
              final data = json.decode(body);
              if (data['result'] == 0) return true;
            }
          } catch (_) {}
          return false;
        }

        bool success = await sendUpload(primaryHost);
        if (!success) {
          success = await sendUpload(fallbackHost);
          if (success) {
            final correctLoc = fallbackHost.contains('eapi') ? '2' : '1';
            await secureStorage.write(key: _userKey('pcloud_location_id'), value: correctLoc);
          }
        }
        return success;
      }
    } catch (e) {
      debugPrint('Upload error to ${destination.name}: $e');
    }
    return false;
  }
  /// Download a file from its cloud and re-upload to [destination]. Pro-only.
  Future<void> _transferCloudFile(DriveItem item, PhotoSource destination) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Transferring file... (Download & Upload)'),
              ],
            ),
          ),
        ),
      ),
    );
    File? tempFile;
    try {
      final downloadUrl = await _getDownloadUrl(item);
      if (downloadUrl == null) throw Exception('Could not get download URL');
      // Memory-safe streaming download
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(downloadUrl));
      if (item.source == PhotoSource.box && _boxAccessToken != null) {
        request.headers['Authorization'] = 'Bearer $_boxAccessToken';
      }
      final response = await client.send(request);
      if (response.statusCode != 200) throw Exception('Download failed (${response.statusCode})');
      final tempDir = await getTemporaryDirectory();
      tempFile = File('${tempDir.path}/transfer_${item.name}');
      final sink = tempFile.openWrite();
      await response.stream.pipe(sink);
      await sink.close();
      final uploadSuccess = await _uploadToProvider(tempFile, item.name, destination);
      if (!uploadSuccess) throw Exception('Upload to ${destination.name} failed');
      final deleteSuccess = await _deleteFromProvider(item);
      if (mounted) Navigator.pop(context); // Close loading dialog
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(deleteSuccess
              ? 'Moved "${item.name}" to ${destination.name}'
              : 'Copied to ${destination.name} (original not deleted).'),
          backgroundColor: deleteSuccess ? Colors.green : Colors.orange,
        ));
      }
      await _fetchAllPhotos(firstPage: true);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Transfer error: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (tempFile != null && await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }
// --- PhotoThumbnail Widget (Updated for Multi-Select) ---
}
class PhotoThumbnail extends StatefulWidget {
  final DriveItem item;
  final Future<String?> Function(DriveItem item) getThumbnailUrl;
  final VoidCallback? onTap;
  final bool isFavorite;
  final VoidCallback? onFavoriteTap;
  final bool useCaching;
  // --- MULTI-SELECT: New properties ---
  final bool isInSelectionMode;
  final bool isSelected;
  final VoidCallback? onLongPress;
  const PhotoThumbnail({
    super.key,
    required this.item,
    required this.getThumbnailUrl,
    this.onTap,
    required this.isFavorite,
    this.onFavoriteTap,
    required this.useCaching,
    // --- MULTI-SELECT: Add required params ---
    required this.isInSelectionMode,
    required this.isSelected,
    this.onLongPress,
  });
  @override
  State<PhotoThumbnail> createState() => _PhotoThumbnailState();
}
// --- PASTE THIS REPLACEMENT CLASS in main.dart ---
class _PhotoThumbnailState extends State<PhotoThumbnail> {
  late Future<String?> _thumbnailUrlFuture;
  Future<AssetEntity?>? _localAssetFuture; // ✅ Store AssetEntity Future
  int _retryCount = 0; // Bug Fix 2: track retries
  @override
  void initState() {
    super.initState();
    _initThumbnailFuture();
  }
  void _initThumbnailFuture() {
    if (widget.item.source == PhotoSource.local) {
      if (widget.item.localAsset == null) {
        _localAssetFuture = AssetEntity.fromId(widget.item.id);
      }
    } else {
      _thumbnailUrlFuture = widget.getThumbnailUrl(widget.item);
    }
  }
  @override
  void didUpdateWidget(covariant PhotoThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.item.getUniqueKey() != oldWidget.item.getUniqueKey() ||
        widget.useCaching != oldWidget.useCaching) {
      setState(() {
        _retryCount = 0;
        _initThumbnailFuture();
      });
    }
    if (widget.item.source != PhotoSource.local &&
        widget.item.thumbnailUrl == null &&
        oldWidget.item.thumbnailUrl != null) {
      setState(() {
        _retryCount = 0;
        _initThumbnailFuture();
      });
    }
  }
  /// Bug Fix 2: Retry fetching the URL once on image load failure
  void _retryLoad() {
    if (_retryCount < 1) {
      setState(() {
        _retryCount++;
        // Clear cached thumbnail URL so a fresh one is fetched
        widget.item.thumbnailUrl = null;
        _initThumbnailFuture();
      });
    }
  }
  //
  // ✅ NEW HELPER WIDGET for the loading effect
  //
  Widget _buildShimmerPlaceholder() {
    return Container(
      color: const Color(0xFFF5F5F5), // Static neutral placeholder (avoids shimmer jank on fast scroll)
    );
  }
  Widget _buildStandardImage(String imageUrl) {
    if (imageUrl.startsWith('data:image')) {
      try {
        return Image.memory(base64Decode(imageUrl.split(',').last),
            fit: BoxFit.cover, gaplessPlayback: true); // gapless helps with flicker
      } catch (e) {
        return Container(
            color: Colors.grey[200],
            child: Icon(
                widget.item.isVideo
                    ? Icons.videocam_off_outlined
                    : Icons.broken_image,
                color: Colors.red));
      }
    }
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      gaplessPlayback: true, // gapless helps with flicker
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        // ✅ USE SHIMMER
        return _buildShimmerPlaceholder();
      },
      errorBuilder: (context, error, stackTrace) {
        // Bug Fix 2: Show icon + retry on failure
        WidgetsBinding.instance.addPostFrameCallback((_) => _retryLoad());
        return Container(
          color: Colors.grey[200],
          child: Icon(
            widget.item.isVideo ? Icons.videocam_off_outlined : Icons.broken_image_outlined,
            color: Colors.grey[400],
          ),
        );
      },
    );
  }
  Widget _buildCachedImage(String imageUrl) {
    if (imageUrl.startsWith('data:image')) {
      try {
        return Image.memory(base64Decode(imageUrl.split(',').last),
            fit: BoxFit.cover, gaplessPlayback: true);
      } catch (e) {
        return Container(
            color: Colors.grey[200],
            child: Icon(
                widget.item.isVideo
                    ? Icons.videocam_off_outlined
                    : Icons.broken_image_outlined,
                color: Colors.grey[400]));
      }
    }
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      useOldImageOnUrlChange: true,
      cacheKey: "${widget.item.getUniqueKey()}_thumb",
      // Decode to 150×150 in memory — enough for 4-column grid, saves ~4× RAM
      memCacheWidth: 150,
      memCacheHeight: 150,
      placeholder: (context, url) => _buildShimmerPlaceholder(),
      // Bug Fix 2: On cached image error, retry once then show icon
      errorWidget: (context, url, error) {
        if (_retryCount < 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _retryLoad());
          return _buildShimmerPlaceholder();
        }
        return GestureDetector(
          onTap: _retryLoad,
          child: Container(
            color: Colors.grey[100],
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image_outlined, color: Colors.grey[400], size: 28),
                const SizedBox(height: 4),
                Text('Tap to retry', style: TextStyle(fontSize: 9, color: Colors.grey[400])),
              ],
            ),
          ),
        );
      },
    );
  }
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // --- MULTI-SELECT: Use all handlers ---
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.0),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // --- Image Builder (Local vs Network) ---
            if (widget.item.source == PhotoSource.local)
              widget.item.localAsset != null
                  ? AssetEntityImage(
                      widget.item.localAsset!,
                      isOriginal: false,
                      thumbnailSize: const ThumbnailSize.square(150),
                      gaplessPlayback: true,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey[200],
                        child: Icon(
                          widget.item.isVideo
                              ? Icons.videocam_off_outlined
                              : Icons.broken_image_outlined,
                          color: Colors.grey[400],
                        ),
                      ),
                    )
                  : FutureBuilder<AssetEntity?>(
                      future: _localAssetFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return _buildShimmerPlaceholder();
                        }
                        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
                          return Container(
                            color: Colors.grey[200],
                            child: Icon(
                              widget.item.isVideo
                                  ? Icons.videocam_off_outlined
                                  : Icons.broken_image_outlined,
                              color: Colors.grey[400],
                            ),
                          );
                        }
                        widget.item.localAsset = snapshot.data;
                        return AssetEntityImage(
                          snapshot.data!,
                          isOriginal: false,
                          thumbnailSize: const ThumbnailSize.square(150),
                      gaplessPlayback: true,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: Colors.grey[200],
                            child: Icon(
                              widget.item.isVideo
                                  ? Icons.videocam_off_outlined
                                  : Icons.broken_image_outlined,
                              color: Colors.grey[400],
                            ),
                          ),
                        );
                      },
                    )
            else
              FutureBuilder<String?>(
                future: _thumbnailUrlFuture,
                builder: (context, snapshot) {
                  // Show placeholder immediately if no cached URL exists yet
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      widget.item.thumbnailUrl == null) {
                    return _buildShimmerPlaceholder();
                  }
                  // Use cached URL first if available, otherwise use snapshot data
                  final imageUrl = widget.item.thumbnailUrl ?? snapshot.data;
                  if (imageUrl == null || imageUrl.isEmpty) {
                    return Container(
                        color: Colors.grey[200],
                        child: Icon(
                            widget.item.isVideo
                                ? Icons.videocam_off_outlined
                                : Icons.broken_image,
                            color: Colors.grey));
                  }
                  return widget.useCaching
                      ? _buildCachedImage(imageUrl)
                      : _buildStandardImage(imageUrl);
                },
              ),
            // --- MULTI-SELECT: Selection Overlay ---
            if (widget.isInSelectionMode)
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                color: widget.isSelected
                    ? Colors.black.withOpacity(0.5)
                    : Colors.transparent,
                child: widget.isSelected
                    ? const Center(
                        child: Icon(Icons.check_circle,
                            color: Colors.white, size: 30))
                    : null,
              ),
            // --- ICONS OVERLAY ---
            if (!widget.isInSelectionMode) ...[
              // ✅ MODIFIED: Favorite Indicator (Visual Only)
              // Only show if it IS a favorite. No GestureDetector (not clickable).
              if (widget.isFavorite)
                Positioned(
                  top: 5,
                  right: 5,
                  child: Container(
                    padding: const EdgeInsets.all(3.0),
                    decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3), // Subtle background
                        shape: BoxShape.circle),
                    child: const Icon(
                        Icons.favorite,
                        color: Colors.redAccent, // Red heart
                        size: 14), // Tiny size
                  ),
                ),
              // Video Icon Overlay
              if (widget.item.isVideo)
                Positioned(
                  bottom: 4,
                  left: 4,
                  child: Icon(Icons.play_circle_fill_outlined,
                      color: Colors.white,
                      size: 20,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 2)]),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
// --- PhotoViewerPage Widget (MODIFIED) ---
class PhotoViewerPage extends StatefulWidget {
    final List<DriveItem> items;
  final int initialIndex;
  final Future<String?> Function(DriveItem item) getDownloadUrl;
  final Set<String> favorites;
  final Set<String> bin;
  final void Function(String key, bool isFavorite) onFavoriteChanged;
  final Future<void> Function(DriveItem item) onMoveToBin;
  final Future<void> Function(DriveItem item) onAddToAlbum;
  final String? oneDriveAccessToken;
  final String? dropboxAccessToken;
  final String? boxAccessToken; // ✅ ADD
  final bool useCaching;
// ✅ ADD THIS LINE
  final Future<String?> Function(DriveItem item) getThumbnailUrl;
  const PhotoViewerPage({
    super.key,
    required this.items,
    required this.initialIndex,
    required this.getDownloadUrl,
    required this.favorites,
    required this.bin,
    required this.onFavoriteChanged,
    required this.onMoveToBin,
    required this.onAddToAlbum,
    required this.oneDriveAccessToken,
    required this.dropboxAccessToken,
    required this.boxAccessToken, // ✅ ADD
    required this.useCaching,
    // ✅ ADD THIS LINE
    required this.getThumbnailUrl,
  });
  @override
  State<PhotoViewerPage> createState() => _PhotoViewerPageState();
 }
class _PhotoViewerPageState extends State<PhotoViewerPage> {
  late final PageController _pageController;
  late int _currentIndex;
  late bool _isCurrentFavorite;
  late bool _isCurrentInBin;
  bool _isDownloading = false;
  bool _isSharing = false;
  VideoPlayerController? _videoController;
  Future<void>? _initializeVideoPlayerFuture;
  bool _isVideoLoading = false;
  bool _isVideoError = false;
  // Controls whether top AppBar & bottom controls are visible (tap photo to toggle immersive mode)
  bool _showChrome = true;
  bool _showTags = false; // Controls if the tag panel is visible
  bool _isTagging = false; // Tracks if ML Kit is currently scanning

  void _toggleChrome() {
    setState(() {
      _showChrome = !_showChrome;
    });
  }
  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _updateStatus();
    if (widget.items[_currentIndex].isVideo) {
      _initializeVideoPlayer(widget.items[_currentIndex]);
    }
  }
 // ✅ REPLACEMENT METHOD
  @override
  void dispose() {
    _pageController.dispose();
    _videoController?.removeListener(_onVideoControllerUpdate); // ✅ Remove listener
    _videoController?.dispose();
    super.dispose();
  }
  // --- PASTE THIS REPLACEMENT METHOD ---
 // ✅ PASTE THIS REPLACEMENT METHOD
 // ✅ REPLACEMENT METHOD: Fixes video player not updating UI or loading correctly
  Future<void> _initializeVideoPlayer(DriveItem item) async {
    // 1. Cleanup old controller first
    final oldController = _videoController;
    if (oldController != null) {
      oldController.removeListener(_onVideoControllerUpdate); // Stop listening
      await oldController.dispose(); // Dispose
    }
    _videoController = null; // Clear reference
    if (!item.isVideo) {
      if (mounted) setState(() {
        _isVideoLoading = false;
        _isVideoError = false;
      });
      return;
    }
    // 2. Set loading state
    if (mounted) setState(() {
      _isVideoLoading = true;
      _isVideoError = false;
    });
    try {
      if (item.source == PhotoSource.local) {
        final entity = await AssetEntity.fromId(item.id);
        final file = await entity?.file;
        if (file == null) throw Exception('Could not get local video file');
        final newController = VideoPlayerController.file(file);
        await newController.initialize();
        if (!mounted) {
          await newController.dispose();
          return;
        }
        final currentItem = widget.items[_currentIndex];
        if (currentItem.getUniqueKey() != item.getUniqueKey()) {
           await newController.dispose();
           return; // Ignore this result, we moved to a new item
        }
        _videoController = newController;
        _videoController!.addListener(_onVideoControllerUpdate);
        setState(() {
          _isVideoLoading = false;
        });
        return;
      }
      String? videoUrl = await widget.getDownloadUrl(item);
      if (videoUrl == null) throw Exception('Could not get video URL');
      // 3. Prepare Headers (Google Drive / Box)
      Map<String, String> httpHeaders = {};
     /* if (item.source == PhotoSource.googleDrive) {
        final token = await _getGoogleAuthToken();
        if (token != null) httpHeaders = {'Authorization': 'Bearer $token'};*/
       if (item.source == PhotoSource.box) {
         if (widget.boxAccessToken != null) {
            httpHeaders = {'Authorization': 'Bearer ${widget.boxAccessToken}'};
         }
      }
      // 4. Create & Initialize Controller (with auto-refresh retry on stale/expired CDN links)
      VideoPlayerController newController = VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
        httpHeaders: httpHeaders,
      );
      try {
        await newController.initialize();
      } catch (initErr) {
        // If the CDN link expired (common with pCloud temporary links), clear cached URL and retry once
        if (item.source != PhotoSource.local) {
          debugPrint('Network video initialize failed ($initErr), refreshing stream URL...');
          await newController.dispose();
          item.downloadUrl = null;
          videoUrl = await widget.getDownloadUrl(item);
          if (videoUrl == null) throw Exception('Could not refresh video URL: $initErr');
          newController = VideoPlayerController.networkUrl(
            Uri.parse(videoUrl),
            httpHeaders: httpHeaders,
          );
          await newController.initialize();
        } else {
          rethrow;
        }
      }
      // 5. Race Condition Check: Did user swipe away while loading?
      if (!mounted) {
        await newController.dispose();
        return;
      }
      final currentItem = widget.items[_currentIndex];
      if (currentItem.getUniqueKey() != item.getUniqueKey()) {
         await newController.dispose();
         return; // Ignore this result, we moved to a new item
      }
      // 6. Success: Assign controller and Add Listener
      _videoController = newController;
      _videoController!.addListener(_onVideoControllerUpdate); // ✅ KEY FIX
      setState(() {
        _isVideoLoading = false;
      });
    } catch (e) {
      debugPrint('Error preparing video player: $e');
      item.downloadUrl = null; // Clear stale URL on failure so next attempt gets a fresh link
      if (mounted) {
        setState(() {
          _isVideoLoading = false;
          _isVideoError = true;
        });
      }
    }
  }
  // ✅ NEW HELPER: Simple listener to rebuild UI on video events
  void _onVideoControllerUpdate() {
    if (mounted) setState(() {});
  }
Future<String?> _getGoogleAuthToken() async {
    final GoogleSignIn gSignIn = googleSignIn;
    try {
      final auth = await gSignIn.currentUser?.authentication;
      return auth?.accessToken;
    } catch (e) {
      debugPrint("Error getting Google auth token: $e");
      return null;
    }
  }
  void _updateStatus() {
    if (!mounted) return;
    // Check bounds before accessing item
    if (_currentIndex < 0 || _currentIndex >= widget.items.length) return;
    final currentKey = widget.items[_currentIndex].getUniqueKey();
    setState(() {
      _isCurrentFavorite = widget.favorites.contains(currentKey);
      _isCurrentInBin = widget.bin.contains(currentKey);
    });
  }
  // --- PASTE THIS REPLACEMENT METHOD in _PhotoViewerPageState ---
  // --- PASTE THIS REPLACEMENT METHOD in _PhotoViewerPageState ---
  void _onPageChanged(int index) {
    // Check bounds before proceeding
    if (index < 0 || index >= widget.items.length) return;
    // ✅ RESET TAG STATE ON SWIPE
    setState(() {
      _showTags = false;
      _isTagging = false; 
    });
    final newItem = widget.items[index];
    if (newItem.isVideo) {
      // ... (rest of your video logic is unchanged) ...
      if (_currentIndex != index) {
        _initializeVideoPlayer(newItem);
      }
    } else {
      _videoController?.pause();
      setState(() {
        _isVideoLoading = false;
        _isVideoError = false;
      });
    }
    setState(() {
      _currentIndex = index;
    });
    // Call updateStatus AFTER setting the index
    _updateStatus();
    // --- (Pre-fetching logic is unchanged) ---
    if (index + 1 < widget.items.length) {
      widget.getDownloadUrl(widget.items[index + 1]);
    }
    if (index - 1 >= 0) {
      widget.getDownloadUrl(widget.items[index - 1]);
    }
    // We no longer auto-run analysis here. The user will tap the icon.
    // _runTagAnalysis(widget.items[index]); // <-- REMOVE/COMMENT OUT THIS LINE
  }
  // --- PASTE THIS NEW METHOD in _PhotoViewerPageState (e.g., after _onPageChanged) ---
// --- PASTE THIS REPLACEMENT METHOD in _PhotoViewerPageState ---
  Future<void> _runTagAnalysis(DriveItem item) async {
    // Don't re-run if tags exist or if it's a video
    if (item.aiTags != null || item.isVideo) {
      return;
    }
    // ✅ SET LOADING STATE
    setState(() => _isTagging = true);
    final String? imageUrl = await widget.getThumbnailUrl(item);
    if (imageUrl == null || !mounted) {
      // ✅ REMOVE LOADING STATE ON FAILURE
      if (mounted) setState(() => _isTagging = false);
      return;
    }
    File? tempFile;
    try {
      if (item.source == PhotoSource.local) {
        final entity = await AssetEntity.fromId(item.id);
        final file = await entity?.file;
        if (file == null) throw Exception('Could not get local image file');
        tempFile = file;
      } else {
        final dir = await getTemporaryDirectory();
        final filePath = '${dir.path}/${item.getUniqueKey()}_tag.jpg';
        tempFile = File(filePath);
        if (imageUrl.startsWith('data:image')) {
          await tempFile.writeAsBytes(base64Decode(imageUrl.split(',').last));
        } else {
          final response = await http.get(Uri.parse(imageUrl));
          if (response.statusCode != 200) {
            throw Exception('Failed to download thumbnail for tagging');
          }
          await tempFile.writeAsBytes(response.bodyBytes);
        }
      }
      // 2. Run ML Kit
      final ImageLabeler labeler = ImageLabeler(
        options: ImageLabelerOptions(confidenceThreshold: 0.6),
      );
      final InputImage inputImage = InputImage.fromFile(tempFile);
      final List<ImageLabel> labels = await labeler.processImage(inputImage);
      await labeler.close();
      final tags = labels.map((e) => e.label).toList();
      // 3. Update the UI
      if (mounted) {
        setState(() {
          item.aiTags = tags.isNotEmpty ? tags : []; // Store empty list if no tags
          _showTags = true; // Automatically show tags after scan
        });
      }
    } catch (e) {
      debugPrint("❌Å’ AI tagging failed for ${item.name}: $e");
    } finally {
      // 4. Clean up temp file - with enhanced safety
      if (tempFile != null && item.source != PhotoSource.local) {
        try {
          final exists = await tempFile.exists();
          if (exists) {
            await tempFile.delete();
          }
        } catch (e) {
          debugPrint("⚠️ Could not delete temp AI tag file (non-critical): $e");
        }
      }
      // ✅ ALWAYS REMOVE LOADING STATE
      if (mounted) {
        setState(() => _isTagging = false);
      }
    }
  }
  void _toggleFavorite() {
    // Check bounds
    if (_currentIndex < 0 || _currentIndex >= widget.items.length) return;
    final currentKey = widget.items[_currentIndex].getUniqueKey();
    final newFavoriteStatus = !_isCurrentFavorite;
    widget.onFavoriteChanged(currentKey, newFavoriteStatus);
    // No need to call setState here, Firestore listener will update _isPro
    // setState(() => _isCurrentFavorite = newFavoriteStatus);.
    // --- START OF FIX ---
    // Manually trigger a UI rebuild for the icon
    setState(() {
      _isCurrentFavorite = newFavoriteStatus;
    });
    // --- END OF FIX ---
  }
 Future<void> _moveToBinCurrent() async {
    if (_currentIndex < 0 || _currentIndex >= widget.items.length) return;
    // ✅ FIX: Show confirmation dialog first
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move to Bin?'),
        content: const Text('Are you sure you want to move this item to the Bin?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Move to Bin', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirm != true) return; // Stop if cancelled
    final currentItem = widget.items[_currentIndex];
    _videoController?.pause();
    await widget.onMoveToBin(currentItem);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Moved to Bin')));
      Navigator.pop(context); // Close viewer after deleting
    }
  }
  Future<void> _addToAlbumCurrent() async {
     // Check bounds
    if (_currentIndex < 0 || _currentIndex >= widget.items.length) return;
    final currentItem = widget.items[_currentIndex];
    await widget.onAddToAlbum(currentItem);
  }
  Future<void> _shareCurrent() async {
     // Check bounds
    if (_isSharing || _currentIndex < 0 || _currentIndex >= widget.items.length) return;
    setState(() => _isSharing = true);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Preparing to share...')));
    File? tempFile; // Store ref to delete later
    try {
      final currentItem = widget.items[_currentIndex];
      if (currentItem.source == PhotoSource.local) {
        final entity = await AssetEntity.fromId(currentItem.id);
        final file = await entity?.file;
        if (file == null) throw Exception('Could not resolve local file');
        if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
        await Share.shareXFiles([XFile(file.path)], text: currentItem.name);
        return;
      }
      String? downloadUrl = await widget.getDownloadUrl(currentItem);
      if (downloadUrl == null) throw Exception('Could not get download URL');
      http.Response response = await http.get(Uri.parse(downloadUrl)).timeout(const Duration(seconds: 60));
      // Auto-refresh expired CDN links (HTTP 401, 403, 404, 410)
      if ((response.statusCode == 401 || response.statusCode == 403 || response.statusCode == 404 || response.statusCode == 410) &&
          currentItem.source != PhotoSource.local) {
        debugPrint('[Share] Download URL expired (HTTP ${response.statusCode}), refreshing link...');
        currentItem.downloadUrl = null;
        downloadUrl = await widget.getDownloadUrl(currentItem);
        if (downloadUrl != null) {
          response = await http.get(Uri.parse(downloadUrl)).timeout(const Duration(seconds: 60));
        }
      }
      if (response.statusCode != 200)
        throw Exception('Failed to download file');
      final tempDir = await getTemporaryDirectory();
      final extension = currentItem.name.contains('.')
          ? currentItem.name.split('.').last
          : (currentItem.isVideo ? 'mp4' : 'jpg');
      // Use a more unique name to avoid potential conflicts
      final fileName =
          'share_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final filePath = '${tempDir.path}/$fileName';
      tempFile = File(filePath); // Assign to tempFile
      await tempFile.writeAsBytes(response.bodyBytes);
      if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
      await Share.shareXFiles([XFile(filePath)], text: currentItem.name);
    } catch (e) {
      debugPrint('Share error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error sharing: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
      // Clean up temp file - with enhanced safety
      if (tempFile != null) {
        try {
          // Check if file exists before attempting deletion
          final exists = await tempFile.exists();
          if (exists) {
            await tempFile.delete();
            debugPrint("✅ Temp share file deleted successfully");
          }
        } catch (e) {
          // Only log, don't crash - file might have been auto-cleaned
          debugPrint("⚠️ Could not delete temp share file (non-critical): $e");
        }
      }
    }
  }
  Future<void> _downloadCurrent() async {
     // Check bounds
    if (_isDownloading || _currentIndex < 0 || _currentIndex >= widget.items.length) return;
    setState(() => _isDownloading = true);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Downloading...')));
    File? tempFile; // Store ref to delete later
    try {
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        final granted = await Gal.requestAccess();
        if (!granted) throw Exception('Storage permission denied');
      }
      final currentItem = widget.items[_currentIndex];
      String? downloadUrl = await widget.getDownloadUrl(currentItem);
      if (downloadUrl == null) throw Exception('Could not get download URL');
      http.Response response = await http.get(Uri.parse(downloadUrl)).timeout(const Duration(seconds: 60));
      // Auto-refresh expired CDN links (HTTP 401, 403, 404, 410)
      if ((response.statusCode == 401 || response.statusCode == 403 || response.statusCode == 404 || response.statusCode == 410) &&
          currentItem.source != PhotoSource.local) {
        debugPrint('[Download] Download URL expired (HTTP ${response.statusCode}), refreshing link...');
        currentItem.downloadUrl = null;
        downloadUrl = await widget.getDownloadUrl(currentItem);
        if (downloadUrl != null) {
          response = await http.get(Uri.parse(downloadUrl)).timeout(const Duration(seconds: 60));
        }
      }
      if (response.statusCode != 200)
        throw Exception(
            'Failed to download file (code: ${response.statusCode})');
      final isVideo = currentItem.isVideo;
      final tempDir = await getTemporaryDirectory();
      final extension = currentItem.name.contains('.')
          ? currentItem.name.split('.').last
          : (isVideo ? 'mp4' : 'jpg');
       // Use a more unique name
      final fileName =
          'download_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final filePath = '${tempDir.path}/$fileName';
      tempFile = File(filePath); // Assign to tempFile
      await tempFile.writeAsBytes(response.bodyBytes);
      if (isVideo) {
        await Gal.putVideo(filePath, album: 'Cloud Photos');
      } else {
        await Gal.putImage(filePath, album: 'Cloud Photos');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Saved to gallery!')));
      }
    } catch (e) {
      debugPrint('Download error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error downloading: $e')));
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
      // Clean up temp file - with enhanced safety
      if (tempFile != null) {
        try {
          // Check if file exists before attempting deletion
          final exists = await tempFile.exists();
          if (exists) {
            await tempFile.delete();
            debugPrint("✅ Temp download file deleted successfully");
          }
        } catch (e) {
          // Only log, don't crash - file might have been auto-cleaned
          debugPrint("⚠️ Could not delete temp download file (non-critical): $e");
        }
      }
    }
  }
  // --- Info Panel Method ---
 // --- Info Panel Method ---
  Future<void> _showInfoPanel() async {
    if (_currentIndex < 0 || _currentIndex >= widget.items.length) return;
    final item = widget.items[_currentIndex];
    // 1. Format Date
    String formattedDate;
    if (item.created != null) {
      try {
        formattedDate = DateFormat.yMMMMd().add_jm().format(item.created!);
      } catch (e) {
        formattedDate = 'Invalid Date';
      }
    } else {
      formattedDate = 'Unknown';
    }
    // ✅ FIX: Handle ALL sources correctly
    String sourceName;
    IconData sourceIcon;
    switch (item.source) {
      case PhotoSource.oneDrive:
        sourceName = "OneDrive";
        sourceIcon = Icons.cloud_queue;
        break;
      case PhotoSource.dropbox:
        sourceName = "Dropbox";
        sourceIcon = Icons.cloud_outlined;
        break;
      case PhotoSource.googleDrive:
        sourceName = "Google Drive";
        sourceIcon = Icons.add_to_drive;
        break;
      case PhotoSource.box:
        sourceName = "Box";
        sourceIcon = Icons.inventory_2_outlined;
        break;
      case PhotoSource.pCloud:
        sourceName = "pCloud";
        sourceIcon = Icons.cloud;
        break;
      default:
        sourceName = "Unknown";
        sourceIcon = Icons.cloud_off;
    }
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.4,
          minChildSize: 0.3,
          maxChildSize: 0.6,
          builder: (BuildContext context, ScrollController scrollController) {
            return Container(
              padding: const EdgeInsets.only(top: 16.0, left: 16.0, right: 16.0),
              child: ListView(
                controller: scrollController,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                   ),
                  Text('Details', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  ListTile(
                    leading: const Icon(Icons.file_present_outlined),
                    title: const Text('File Name'),
                    subtitle: Text(item.name, overflow: TextOverflow.ellipsis, maxLines: 2),
                   ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: const Text('Date Created'),
                    subtitle: Text(formattedDate),
                  ),
                  const Divider(),
                  ListTile(
                     leading: Icon(sourceIcon),
                    title: const Text('Source'),
                    subtitle: Text(sourceName), // ✅ Shows correct source now
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        );
      },
    );
  }
  Future<void> _editCurrent() async {
    if (_isDownloading || _currentIndex < 0 || _currentIndex >= widget.items.length) return;
    final item = widget.items[_currentIndex];
    if (item.isVideo) return;
    File? imageFile;
    File? tempFile;
    setState(() {
      _isDownloading = true;
    });
    try {
      if (item.source == PhotoSource.local) {
        final entity = await AssetEntity.fromId(item.id);
        imageFile = await entity?.file;
      } else {
        String? url = await widget.getDownloadUrl(item);
        if (url != null) {
           http.Response response = await http.get(Uri.parse(url));
           if ((response.statusCode == 401 || response.statusCode == 403 || response.statusCode == 404 || response.statusCode == 410) &&
               item.source != PhotoSource.local) {
             item.downloadUrl = null;
             url = await widget.getDownloadUrl(item);
             if (url != null) {
               response = await http.get(Uri.parse(url));
             }
           }
           if (response.statusCode == 200) {
              final tempDir = await getTemporaryDirectory();
              final file = File('${tempDir.path}/temp_edit_img_${DateTime.now().millisecondsSinceEpoch}.jpg');
              await file.writeAsBytes(response.bodyBytes);
              imageFile = file;
              tempFile = file;
           }
        }
      }
      if (imageFile == null) {
        throw Exception('Failed to get image file for editing');
      }
      setState(() {
        _isDownloading = false;
      });
      if (!mounted) return;
      final Uint8List? editedBytes = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProImageEditor.file(
            imageFile!,
            callbacks: ProImageEditorCallbacks(
              onImageEditingComplete: (Uint8List bytes) async {
                Navigator.pop(context, bytes);
              },
            ),
          ),
        ),
      );
      if (editedBytes != null) {
        final tempDir = await getTemporaryDirectory();
        final editedFile = File('${tempDir.path}/edited_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await editedFile.writeAsBytes(editedBytes);
        await Gal.putImage(editedFile.path, album: 'Edited Photos');
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Edited image saved to Gallery')),
           );
        }
      }
    } catch (e) {
       if (mounted) {
         setState(() {
           _isDownloading = false;
         });
         ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error editing image: $e')),
         );
       }
    } finally {
       if (tempFile != null) {
         try { await tempFile.delete(); } catch(_) {}
       }
    }
  }
// --- PASTE THIS REPLACEMENT METHOD ---
  // --- START OF FIX: Use 'dynamic' to bypass analyzer bug ---
 // ... (inside _PhotoViewerPageState) ...
  // --- PASTE THIS REPLACEMENT METHOD ---
  // --- START OF FIX: Use 'dynamic' to bypass analyzer bug ---
  Map<String, String> _getHttpHeadersSync(DriveItem item) {
    if (item.source == PhotoSource.box) {
      final token = widget.boxAccessToken;
      if (token != null) {
        return {'Authorization': 'Bearer $token'};
      }
    }
    return const <String, String>{};
  }
  dynamic _getLowResProvider(DriveItem item) {
  if (item.source == PhotoSource.local) {
    if (item.localAsset != null) {
      return AssetEntityImageProvider(
        item.localAsset!,
        isOriginal: false,
        thumbnailSize: const ThumbnailSize.square(150),
      );
    }
  }
    // --- END OF FIX ---
    // --- START OF FIX 1: Check for cached Base64 thumbnail (from GDrive) ---
    if (item.cachedBase64Thumbnail != null &&
        item.cachedBase64Thumbnail!.startsWith('data:image')) {
      try {
        return MemoryImage(
            base64Decode(item.cachedBase64Thumbnail!.split(',').last));
      } catch (e) {
        return null; // Invalid base64
      }
    }
    // --- END OF FIX 1 ---
    if (item.thumbnailUrl != null && item.thumbnailUrl!.isNotEmpty) {
      if (item.thumbnailUrl!.startsWith('data:image')) {
        // Handle Dropbox's base64 thumbnails
        try {
          return MemoryImage(base64Decode(item.thumbnailUrl!.split(',').last));
        } catch (e) {
          return null;
        }
      } else {
        // Handle OneDrive's network thumbnails
        // GDrive will now be caught by the block above and won't reach here
        return widget.useCaching
            ? CachedNetworkImageProvider(
                item.thumbnailUrl!,
                cacheKey: "${item.getUniqueKey()}_thumb",
              )
            : NetworkImage(item.thumbnailUrl!);
      }
    }
    return null;
  }
// ... (rest of class) ...
// --- FINAL: Smooth, Cached & Flicker-Free Image Viewer ---
// --- PASTE THIS REPLACEMENT METHOD ---
// --- PASTE THIS REPLACEMENT METHOD in PhotoViewerPage ---
// --- PASTE THIS REPLACEMENT METHOD ---
 // --- PASTE THIS REPLACEMENT METHOD in _PhotoViewerPageState ---
// --- PASTE THIS REPLACEMENT METHOD in _PhotoViewerPageState ---
PhotoViewGalleryPageOptions _buildGalleryPage(DriveItem item) {
    if (item.source == PhotoSource.local) {
      if (item.isVideo) {
        return PhotoViewGalleryPageOptions.customChild(
          child: Center(child: _buildVideoPlayerWidget()),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.contained,
          initialScale: PhotoViewComputedScale.contained,
          onTapUp: (context, _, __) => _toggleChrome(),
        );
      }
      if (item.localAsset != null) {
        return PhotoViewGalleryPageOptions.customChild(
          child: PhotoView(
            imageProvider: AssetEntityImageProvider(
              item.localAsset!,
              isOriginal: true,
            ),
            gaplessPlayback: true,
            enableRotation: false,
            backgroundDecoration: const BoxDecoration(color: Colors.black),
            onTapUp: (context, _, __) => _toggleChrome(),
          ),
        );
      }
      return PhotoViewGalleryPageOptions.customChild(
        child: FutureBuilder<AssetEntity?>(
          future: AssetEntity.fromId(item.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              final lowResProvider = _getLowResProvider(item);
              if (lowResProvider != null) {
                return Center(
                  child: Image(
                    image: lowResProvider,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                  ),
                );
              }
              return const Center(child: CircularProgressIndicator(strokeWidth: 2));
            }
            if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
              return const Center(
                child: Icon(Icons.broken_image, color: Colors.white, size: 60),
              );
            }
            item.localAsset = snapshot.data;
            return PhotoView(
              imageProvider: AssetEntityImageProvider(
                snapshot.data!,
                isOriginal: true,
              ),
              gaplessPlayback: true,
              enableRotation: false,
              backgroundDecoration: const BoxDecoration(color: Colors.black),
              onTapUp: (context, _, __) => _toggleChrome(),
            );
          },
        ),
      );
    }
    if (item.isVideo) {
      return PhotoViewGalleryPageOptions.customChild(
        child: Center(child: _buildVideoPlayerWidget()),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.contained,
        initialScale: PhotoViewComputedScale.contained,
        onTapUp: (context, _, __) => _toggleChrome(),
      );
    }
    final String? cachedUrl = item.downloadUrl;
    return PhotoViewGalleryPageOptions.customChild(
      child: Column(
        children: [
          Expanded(
            child: (cachedUrl != null && cachedUrl.isNotEmpty)
                ? PhotoView(
                    imageProvider: CachedNetworkImageProvider(
                      cachedUrl,
                      cacheKey: "${item.getUniqueKey()}_full",
                      headers: _getHttpHeadersSync(item),
                    ),
                    gaplessPlayback: true,
                    enableRotation: false,
                    backgroundDecoration: const BoxDecoration(color: Colors.black),
                    onTapUp: (context, _, __) => _toggleChrome(),
                    loadingBuilder: (context, event) {
                      final lowResProvider = _getLowResProvider(item);
                      if (lowResProvider != null) {
                        return Center(
                          child: Image(
                            image: lowResProvider,
                            fit: BoxFit.contain,
                            gaplessPlayback: true,
                          ),
                        );
                      }
                      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                    },
                    errorBuilder: (context, error, stackTrace) {
                      item.downloadUrl = null; // Clear stale URL so subsequent reloads fetch a fresh link
                      final lowResProvider = _getLowResProvider(item);
                      if (lowResProvider != null) {
                        return Center(
                          child: Image(
                            image: lowResProvider,
                            fit: BoxFit.contain,
                            gaplessPlayback: true,
                        ),
                      );
                    }
                    return const Center(child: Icon(Icons.broken_image, color: Colors.white));
                  },
                )
              : FutureBuilder<String?>(
                  future: widget.getDownloadUrl(item),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      final lowResProvider = _getLowResProvider(item);
                      if (lowResProvider != null) {
                        return Center(
                          child: Image(
                            image: lowResProvider,
                            fit: BoxFit.contain,
                            gaplessPlayback: true,
                          ),
                        );
                      }
                      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                    }
                    if (snapshot.hasError || !snapshot.hasData || snapshot.data == null || snapshot.data!.isEmpty) {
                      final lowResProvider = _getLowResProvider(item);
                      if (lowResProvider != null) {
                        return Center(
                          child: Image(
                            image: lowResProvider,
                            fit: BoxFit.contain,
                            gaplessPlayback: true,
                          ),
                        );
                      }
                      return const Center(child: Icon(Icons.broken_image, color: Colors.white, size: 60));
                    }
                    final String imageUrl = snapshot.data!;
                    item.downloadUrl = imageUrl;
                    final httpHeaders = _getHttpHeadersSync(item);
                    return PhotoView(
                      imageProvider: CachedNetworkImageProvider(
                        imageUrl,
                        cacheKey: "${item.getUniqueKey()}_full",
                        headers: httpHeaders,
                      ),
                      gaplessPlayback: true,
                      enableRotation: false,
                      backgroundDecoration: const BoxDecoration(color: Colors.black),
                      onTapUp: (context, _, __) => _toggleChrome(),
                      loadingBuilder: (context, event) {
                        final lowResProvider = _getLowResProvider(item);
                        if (lowResProvider != null) {
                          return Center(
                            child: Image(
                              image: lowResProvider,
                              fit: BoxFit.contain,
                              gaplessPlayback: true,
                            ),
                          );
                        }
                        return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                      },
                      errorBuilder: (context, error, stackTrace) {
                        final lowResProvider = _getLowResProvider(item);
                        if (lowResProvider != null) {
                          return Center(
                            child: Image(
                              image: lowResProvider,
                              fit: BoxFit.contain,
                              gaplessPlayback: true,
                            ),
                          );
                        }
                        return const Center(child: Icon(Icons.broken_image, color: Colors.white));
                      },
                    );
                  },
                ),
          ),
          AnimatedOpacity(
            opacity: _showTags ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: IgnorePointer(
              ignoring: !_showTags,
              child: (item.aiTags != null && item.aiTags!.isNotEmpty)
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 10.0),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 120),
                        child: SingleChildScrollView(
                          child: Wrap(
                            spacing: 6.0,
                            runSpacing: 4.0,
                            children: item.aiTags!
                                .map((tag) => Chip(
                                      label: Text(tag, style: const TextStyle(color: Colors.white, fontSize: 12)),
                                      backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                                      padding: const EdgeInsets.all(4),
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ))
                                .toList(),
                          ),
                        ),
                      ),
                    )
                  : null,
            ),
          ),
        ],
      ),
      heroAttributes: PhotoViewHeroAttributes(tag: item.getUniqueKey()),
      minScale: PhotoViewComputedScale.contained * 0.8,
      maxScale: PhotoViewComputedScale.covered * 2,
      initialScale: PhotoViewComputedScale.contained,
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return '${duration.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  Widget _buildBottomVideoControls() {
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return const SizedBox.shrink();
    }
    final position = _videoController!.value.position;
    final duration = _videoController!.value.duration;
    final isPlaying = _videoController!.value.isPlaying;
    final isFinished = position >= duration;
    final isMuted = _videoController!.value.volume == 0;

    final posMs = position.inMilliseconds.toDouble();
    final durMs = duration.inMilliseconds.toDouble();
    final currentSliderVal = (durMs > 0) ? posMs.clamp(0.0, durMs) : 0.0;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withValues(alpha: 0.85),
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Scrub Slider with Live Thumb
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3.5,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
                  activeTrackColor: Theme.of(context).primaryColor,
                  inactiveTrackColor: Colors.white24,
                  thumbColor: Colors.white,
                  overlayColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                ),
                child: Slider(
                  value: currentSliderVal,
                  min: 0.0,
                  max: durMs > 0 ? durMs : 1.0,
                  onChanged: (value) {
                    _videoController!.seekTo(Duration(milliseconds: value.toInt()));
                  },
                ),
              ),
              // 2. Control Row: Timestamp, Play/Pause, Rewind/Forward, Mute
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Timestamp e.g. 01:23 / 04:56
                  Text(
                    '${_formatDuration(position)} / ${_formatDuration(duration)}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  // Center Controls: Rewind 10s, Play/Pause, Forward 10s
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.replay_10_rounded, color: Colors.white, size: 24),
                        tooltip: 'Rewind 10s',
                        onPressed: () {
                          final newPos = position - const Duration(seconds: 10);
                          _videoController!.seekTo(newPos < Duration.zero ? Duration.zero : newPos);
                        },
                      ),
                      IconButton(
                        icon: Icon(
                          isFinished
                              ? Icons.replay_rounded
                              : (isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded),
                          color: Colors.white,
                          size: 38,
                        ),
                        onPressed: () {
                          if (isPlaying) {
                            _videoController!.pause();
                          } else {
                            if (isFinished) {
                              _videoController!.seekTo(Duration.zero);
                            }
                            _videoController!.play();
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.forward_10_rounded, color: Colors.white, size: 24),
                        tooltip: 'Forward 10s',
                        onPressed: () {
                          final newPos = position + const Duration(seconds: 10);
                          _videoController!.seekTo(newPos > duration ? duration : newPos);
                        },
                      ),
                    ],
                  ),
                  // Mute / Unmute
                  IconButton(
                    icon: Icon(
                      isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                      color: Colors.white70,
                      size: 22,
                    ),
                    tooltip: isMuted ? 'Unmute' : 'Mute',
                    onPressed: () {
                      _videoController!.setVolume(isMuted ? 1.0 : 0.0);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomPhotoActions() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withValues(alpha: 0.85),
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // 1. Share
              _buildPhotoActionButton(
                icon: Icons.share_outlined,
                label: 'Share',
                onTap: _isSharing ? null : _shareCurrent,
                isLoading: _isSharing,
              ),
              // 2. Favorite
              _buildPhotoActionButton(
                icon: _isCurrentFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                iconColor: _isCurrentFavorite ? Colors.redAccent : Colors.white,
                label: _isCurrentFavorite ? 'Favorited' : 'Favorite',
                onTap: _toggleFavorite,
              ),
              // 3. Delete / Move to Bin
              _buildPhotoActionButton(
                icon: Icons.delete_outline_rounded,
                iconColor: Colors.white,
                label: 'Delete',
                onTap: _moveToBinCurrent,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    Color iconColor = Colors.white,
    bool isLoading = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
              )
            else
              Icon(icon, color: iconColor, size: 26),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: iconColor.withValues(alpha: 0.9),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlayerWidget() {
    if (_isVideoLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    if (_isVideoError || _videoController == null || !_videoController!.value.isInitialized) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 60),
            SizedBox(height: 10),
            Text('Could not load video', style: TextStyle(color: Colors.white)),
          ],
        ),
      );
    }
    final isPlaying = _videoController!.value.isPlaying;
    final isFinished = _videoController!.value.position >= _videoController!.value.duration;
    final showCenterPlayIcon = !isPlaying || isFinished;

    return Center(
      child: AspectRatio(
        aspectRatio: _videoController!.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            VideoPlayer(_videoController!),
            // Center Play/Replay Indicator Overlay
            GestureDetector(
              onTap: () {
                if (isPlaying) {
                  _videoController!.pause();
                } else {
                  if (isFinished) {
                    _videoController!.seekTo(Duration.zero);
                  }
                  _videoController!.play();
                }
              },
              behavior: HitTestBehavior.translucent,
              child: AnimatedOpacity(
                opacity: showCenterPlayIcon ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isFinished ? Icons.replay_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 56.0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentIndex < 0 || _currentIndex >= widget.items.length) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: const Center(
          child: Text('Error: Invalid item index.', style: TextStyle(color: Colors.red)),
        ),
      );
    }
    final currentItem = widget.items[_currentIndex];
    final actions = _isCurrentInBin
        ? <Widget>[]
        : <Widget>[
            if (_isSharing)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.0,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            if (_isDownloading)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.0,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (value) {
                switch (value) {
                  case 'info':
                    _showInfoPanel();
                    break;
                  case 'edit':
                    _editCurrent();
                    break;
                  case 'add_to_album':
                    _addToAlbumCurrent();
                    break;
                  case 'download':
                    _downloadCurrent();
                    break;
                  case 'share':
                    _shareCurrent();
                    break;
                  case 'favorite':
                    _toggleFavorite();
                    break;
                  case 'move_to_bin':
                    _moveToBinCurrent();
                    break;
                }
              },
              itemBuilder: (BuildContext context) {
                return [
                  const PopupMenuItem<String>(
                    value: 'info',
                    child: Row(
                      children: [
                        Icon(Icons.info_outline),
                        SizedBox(width: 8),
                        Text('Info'),
                      ],
                    ),
                  ),
                  if (!currentItem.isVideo)
                    const PopupMenuItem<String>(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                  const PopupMenuItem<String>(
                    value: 'add_to_album',
                    child: Row(
                      children: [
                        Icon(Icons.playlist_add),
                        SizedBox(width: 8),
                        Text('Add to Album'),
                      ],
                    ),
                  ),
                  if (currentItem.source != PhotoSource.local)
                    const PopupMenuItem<String>(
                      value: 'download',
                      child: Row(
                        children: [
                          Icon(Icons.download_outlined),
                          SizedBox(width: 8),
                          Text('Download'),
                        ],
                      ),
                    ),
                ];
              },
            ),
          ];

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Fullscreen Photo / Video Gallery (Tapping toggles chrome)
          GestureDetector(
            onTap: _toggleChrome,
            behavior: HitTestBehavior.translucent,
            child: PhotoViewGallery.builder(
              itemCount: widget.items.length,
              builder: (context, index) {
                if (index < 0 || index >= widget.items.length) {
                  return PhotoViewGalleryPageOptions.customChild(
                    child: const Center(child: Text('Error')),
                  );
                }
                return _buildGalleryPage(widget.items[index]);
              },
              pageController: _pageController,
              onPageChanged: _onPageChanged,
              scrollPhysics: const BouncingScrollPhysics(),
              backgroundDecoration: const BoxDecoration(color: Colors.black),
              loadingBuilder: (context, event) =>
                  const Center(child: CircularProgressIndicator()),
            ),
          ),
          // 2. Animated Top Header (AppBar with Title, Back button, Menu, Gradient)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedSlide(
              offset: _showChrome ? Offset.zero : const Offset(0, -1),
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: AnimatedOpacity(
                opacity: _showChrome ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.75),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: AppBar(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      title: Text(
                        currentItem.name,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                      iconTheme: const IconThemeData(color: Colors.white),
                      actions: actions,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // 3. Animated Bottom Bar: Video Controls for Videos OR Primary Action Bar for Photos
          if (currentItem.isVideo)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: AnimatedSlide(
                offset: _showChrome ? Offset.zero : const Offset(0, 1),
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: AnimatedOpacity(
                  opacity: _showChrome ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  child: _buildBottomVideoControls(),
                ),
              ),
            )
          else if (!_isCurrentInBin)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: AnimatedSlide(
                offset: _showChrome ? Offset.zero : const Offset(0, 1),
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: AnimatedOpacity(
                  opacity: _showChrome ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  child: _buildBottomPhotoActions(),
                ),
              ),
            ),
        ],
      ),
    );
  }
// --- FavoritesPage Widget ---
}
class FavoritesPage extends StatefulWidget {
  final List<DriveItem> allItems;
  final Set<String> favoriteKeys;
  final Future<String?> Function(DriveItem item) getThumbnailUrl;
  final Future<String?> Function(DriveItem item) getDownloadUrl;
  final void Function(String key, bool isFavorite) onFavoriteChanged;
  final Future<void> Function(DriveItem item) onMoveToBin;
  final Future<void> Function(List<String> keys) onShowAddToAlbumDialog;
  final String? oneDriveAccessToken;
  final String? dropboxAccessToken;
  final String? boxAccessToken;
  final bool useCaching;
  const FavoritesPage({
    super.key,
    required this.allItems,
    required this.favoriteKeys,
    required this.getThumbnailUrl,
    required this.getDownloadUrl,
    required this.onFavoriteChanged,
    required this.onMoveToBin,
    required this.onShowAddToAlbumDialog,
    required this.oneDriveAccessToken,
    required this.dropboxAccessToken,
    required this.boxAccessToken,
    required this.useCaching,
  });
  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}
class _FavoritesPageState extends State<FavoritesPage> {
  List<DriveItem> _favoriteItems = [];
  @override
  void initState() {
    super.initState();
    _filterFavorites();
  }
  @override
  void didUpdateWidget(covariant FavoritesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.favoriteKeys != oldWidget.favoriteKeys ||
        widget.allItems.length != oldWidget.allItems.length) {
      _filterFavorites();
    }
  }
  void _filterFavorites() {
    // Filter items based on keys AND ensure they still exist in allItems
    // (handles case where item might have been deleted elsewhere)
    final currentFavoriteKeys = widget.favoriteKeys;
    setState(() {
       _favoriteItems = widget.allItems.where((item) {
          return currentFavoriteKeys.contains(item.getUniqueKey());
       }).toList();
    });
  }
  void _unfavoriteItem(DriveItem item) {
    widget.onFavoriteChanged(item.getUniqueKey(), false);
    // No need for setState, Firestore listener will update parent and trigger rebuild
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Favorites')),
      body: _favoriteItems.isEmpty
          ? const Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                  Icon(Icons.favorite_border, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No favorite photos yet.', style: TextStyle(fontSize: 16))
                ]))
          : GridView.builder(
              padding: const EdgeInsets.all(2.0),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 2.0,
                  mainAxisSpacing: 2.0),
              itemCount: _favoriteItems.length,
              itemBuilder: (context, index) {
                final item = _favoriteItems[index];
                return PhotoThumbnail(key: ValueKey(item.getUniqueKey()), item: item,
                  getThumbnailUrl: widget.getThumbnailUrl,
                  isFavorite: true, // Always true on this page
                  onFavoriteTap: () => _unfavoriteItem(item),
                  useCaching: widget.useCaching,
                  isSelected: false, // Not selectable here
                  isInSelectionMode: false, // Not selectable here
                 onTap: () {
                     final viewerIndex = _favoriteItems.indexWhere(
                        (i) => i.getUniqueKey() == item.getUniqueKey());
                     if (viewerIndex != -1) {
                       // --- START OF PRE-FETCH ---
                       widget.getThumbnailUrl(item); // Pre-fetch thumbnail
                       widget.getDownloadUrl(item); // Pre-fetch download URL
                       // Pre-fetch the next item (if it exists)
                       if (viewerIndex + 1 < _favoriteItems.length) {
                         widget.getDownloadUrl(_favoriteItems[viewerIndex + 1]);
                       }
                       // Pre-fetch the previous item (if it exists)
                       if (viewerIndex - 1 >= 0) {
                         widget.getDownloadUrl(_favoriteItems[viewerIndex - 1]);
                       }
                       // --- END OF PRE-FETCH ---
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => PhotoViewerPage(
                                      items: _favoriteItems, // Pass only favorites
                                      initialIndex: viewerIndex,
                                      getDownloadUrl: widget.getDownloadUrl,
                                      getThumbnailUrl: widget.getThumbnailUrl,
                                      favorites: widget.favoriteKeys,
                                      bin: const {}, // Bin not relevant here
                                      onFavoriteChanged: widget.onFavoriteChanged,
                                      onMoveToBin: widget.onMoveToBin,
                                      onAddToAlbum: (item) =>
                                          widget.onShowAddToAlbumDialog(
                                              [item.getUniqueKey()]),
                                      oneDriveAccessToken:
                                          widget.oneDriveAccessToken,
                                      dropboxAccessToken:
                                          widget.dropboxAccessToken,
                                          boxAccessToken: widget.boxAccessToken,
                                      useCaching: widget.useCaching,
                                    )));
                     }
                  },
                );
              },
            ),
    );
  }
}
// --- BinPage Widget ---
class BinPage extends StatefulWidget {
  final List<DriveItem> allItems; // Needs all items to find by key
  final Set<String> binKeys;
  final Future<String?> Function(DriveItem item) getThumbnailUrl;
  final Future<String?> Function(DriveItem item) getDownloadUrl;
  final Future<void> Function(DriveItem item) onRestore;
  final Future<void> Function(DriveItem item) onPermanentDelete;
  final String? oneDriveAccessToken;
  final String? dropboxAccessToken;
  final bool useCaching;
  const BinPage({
    super.key,
    required this.allItems,
    required this.binKeys,
    required this.getThumbnailUrl,
    required this.getDownloadUrl,
    required this.onRestore,
    required this.onPermanentDelete,
    required this.oneDriveAccessToken,
    required this.dropboxAccessToken,
    required this.useCaching,
  });
  @override
  State<BinPage> createState() => _BinPageState();
}
class _BinPageState extends State<BinPage> {
  List<DriveItem> _binnedItems = [];
  @override
  void initState() {
    super.initState();
    _filterBinnedItems();
  }
  @override
  void didUpdateWidget(covariant BinPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.binKeys != oldWidget.binKeys ||
        widget.allItems.length != oldWidget.allItems.length) {
      _filterBinnedItems();
    }
  }
  void _filterBinnedItems() {
    // Filter using allItems to find the actual DriveItem objects
     final currentBinKeys = widget.binKeys;
     setState(() {
        _binnedItems = widget.allItems.where((item) {
           return currentBinKeys.contains(item.getUniqueKey());
        }).toList();
     });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bin')),
      body: _binnedItems.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.delete_sweep_outlined, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Bin is empty.', style: TextStyle(fontSize: 16)),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(2.0),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 2.0,
                  mainAxisSpacing: 2.0),
              itemCount: _binnedItems.length,
              itemBuilder: (context, index) {
                final item = _binnedItems[index];
                return Stack(fit: StackFit.expand, children: [
                  GestureDetector(
                    onTap: () {
                      final viewerIndex = _binnedItems.indexWhere(
                          (i) => i.getUniqueKey() == item.getUniqueKey());
                      if (viewerIndex != -1) {
                        // --- START OF PRE-FETCH ---
                        widget.getThumbnailUrl(item); // Pre-fetch thumbnail
                        widget.getDownloadUrl(item); // Pre-fetch download URL
                        // Pre-fetch the next item (if it exists)
                        if (viewerIndex + 1 < _binnedItems.length) {
                          widget.getDownloadUrl(_binnedItems[viewerIndex + 1]);
                        }
                        // Pre-fetch the previous item (if it exists)
                        if (viewerIndex - 1 >= 0) {
                          widget.getDownloadUrl(_binnedItems[viewerIndex - 1]);
                        }
                        // --- END OF PRE-FETCH ---
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => PhotoViewerPage(
                                      items: _binnedItems, // Pass only binned items
                                      initialIndex: viewerIndex,
                                      getDownloadUrl: widget.getDownloadUrl,
                                      getThumbnailUrl: widget.getThumbnailUrl,
                                      favorites: const {}, // Not relevant in Bin viewer
                                      bin: widget.binKeys, // Pass bin keys
                                      onFavoriteChanged: (_, __) {}, // No favoriting from Bin
                                      onMoveToBin: (_) async {}, // Cannot move to bin from bin
                                      onAddToAlbum: (_) async {}, // No adding to album from bin
                                      oneDriveAccessToken:
                                          widget.oneDriveAccessToken,
                                      dropboxAccessToken:
                                          widget.dropboxAccessToken,
                                          boxAccessToken: null, // ✅ ADD (Box items not supported in bin viewer yet)
                                      useCaching: widget.useCaching,
                                    )));
                      }
                    },
                    child: Opacity(
                        opacity: 0.7,
                        child: PhotoThumbnail(
                            item: item,
                            getThumbnailUrl: widget.getThumbnailUrl,
                            isFavorite: false, // Never favorite in bin
                            onFavoriteTap: null, // No favoriting from bin
                            onTap: null, // Tap handled by outer GestureDetector
                            useCaching: widget.useCaching,
                            isSelected: false, // Not selectable
                            isInSelectionMode: false, // Not selectable
                            )),
                  ),
                  // --- Action Buttons Overlay ---
                  Positioned(
                    bottom: 4,
                    right: 4,
                    left: 4,
                    child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(6)),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              IconButton(
                                  icon: const Icon(Icons.restore_from_trash, color: Colors.white, size: 20),
                                  tooltip: 'Restore',
                                  onPressed: () => widget.onRestore(item),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints()),
                              IconButton(
                                  icon: const Icon(Icons.delete_forever, color: Colors.redAccent, size: 20),
                                  tooltip: 'Delete Permanently',
                                  onPressed: () => widget.onPermanentDelete(item),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints()),
                            ]))
                   ),
                ]);
              },
            ),
    );
  }
}
// --- Albums Page (MODIFIED with Smart Albums) ---
/// Model for auto-generated smart albums.
class _SmartAlbumDef {
  final String name;
  final IconData icon;
  final Color color;
  final List<DriveItem> Function(List<DriveItem> items, Set<String> favorites) filter;
  const _SmartAlbumDef({
    required this.name,
    required this.icon,
    required this.color,
    required this.filter,
  });
}
class AlbumsPage extends StatefulWidget {
  final DocumentReference userDocRef;
  final List<DriveItem> allItems;
  final Map<String, List<String>> albums;
  final Map<String, String> albumCovers;
  final Set<String> favorites;
  final Future<String?> Function(DriveItem item) getThumbnailUrl;
  final Future<String?> Function(DriveItem item) getDownloadUrl;
  final Future<void> Function(List<String> itemKeys, String albumName) onAddItemsToAlbum;
  final void Function(String key, bool isFavorite) onFavoriteChanged;
  final Future<void> Function(DriveItem item) onMoveToBin;
  final String? oneDriveAccessToken;
  final String? dropboxAccessToken;
  final String? boxAccessToken;
  final bool useCaching;
  // Bin tile fields
  final List<DriveItem> allItemsWithBin;
  final Set<String> binKeys;
  final Future<void> Function(DriveItem item) onRestore;
  final Future<void> Function(DriveItem item) onPermanentDelete;

  const AlbumsPage({
    super.key,
    required this.userDocRef,
    required this.allItems,
    required this.albums,
    required this.albumCovers,
    required this.favorites,
    required this.getThumbnailUrl,
    required this.getDownloadUrl,
    required this.onAddItemsToAlbum,
    required this.onFavoriteChanged,
    required this.onMoveToBin,
    required this.oneDriveAccessToken,
    required this.dropboxAccessToken,
    required this.boxAccessToken,
    required this.useCaching,
    required this.allItemsWithBin,
    required this.binKeys,
    required this.onRestore,
    required this.onPermanentDelete,
  });

  @override
  State<AlbumsPage> createState() => _AlbumsPageState();
}

class _AlbumsPageState extends State<AlbumsPage> {
  late Map<String, DriveItem> _itemMap;

  // ──── Smart album definitions (computed dynamically, never stored in Firestore) ────
  static final List<_SmartAlbumDef> _smartAlbumDefs = [
    _SmartAlbumDef(
      name: 'Favorites',
      icon: Icons.favorite_rounded,
      color: const Color(0xFFE91E63),
      filter: (items, favs) =>
          items.where((i) => favs.contains(i.getUniqueKey())).toList(),
    ),
    _SmartAlbumDef(
      name: 'Videos',
      icon: Icons.videocam_rounded,
      color: const Color(0xFFE53935),
      filter: (items, _) => items.where((i) => i.isVideo).toList(),
    ),
    _SmartAlbumDef(
      name: 'Screenshots',
      icon: Icons.screenshot_monitor_rounded,
      color: const Color(0xFF0284C7),
      filter: (items, _) =>
          items.where((i) => i.name.toLowerCase().contains('screenshot')).toList(),
    ),
    _SmartAlbumDef(
      name: 'Last 30 Days',
      icon: Icons.calendar_today_rounded,
      color: const Color(0xFF0288D1),
      filter: (items, _) {
        final cutoff = DateTime.now().subtract(const Duration(days: 30));
        return items
            .where((i) => i.created != null && i.created!.isAfter(cutoff))
            .toList();
      },
    ),
    _SmartAlbumDef(
      name: 'OneDrive',
      icon: Icons.cloud_queue_rounded,
      color: const Color(0xFF0078D4),
      filter: (items, _) =>
          items.where((i) => i.source == PhotoSource.oneDrive).toList(),
    ),
    _SmartAlbumDef(
      name: 'Dropbox',
      icon: Icons.storage_rounded,
      color: const Color(0xFF0061FF),
      filter: (items, _) =>
          items.where((i) => i.source == PhotoSource.dropbox).toList(),
    ),
    _SmartAlbumDef(
      name: 'Box',
      icon: Icons.archive_outlined,
      color: const Color(0xFF0061D5),
      filter: (items, _) =>
          items.where((i) => i.source == PhotoSource.box).toList(),
    ),
    _SmartAlbumDef(
      name: 'pCloud',
      icon: Icons.cloud_download_outlined,
      color: const Color(0xFF2ECC71),
      filter: (items, _) =>
          items.where((i) => i.source == PhotoSource.pCloud).toList(),
    ),
    _SmartAlbumDef(
      name: 'On Device',
      icon: Icons.phone_android_rounded,
      color: const Color(0xFF546E7A),
      filter: (items, _) =>
          items.where((i) => i.source == PhotoSource.local).toList(),
    ),
  ];

  late Stream<DocumentSnapshot> _userDocStream;
  DriveItem? _peopleCoverItem;
  int _peopleCount = 0;

  @override
  void initState() {
    super.initState();
    _buildItemMap();
    _userDocStream = widget.userDocRef.snapshots();
    _loadPeoplePreview();
  }

  Future<void> _loadPeoplePreview() async {
    try {
      final userId = widget.userDocRef.id;
      final people = await isar.personRecords
          .filter()
          .userIdEqualTo(userId)
          .findAll();

      people.sort((a, b) => b.photoCount.compareTo(a.photoCount));
      _peopleCount = people.length;

      DriveItem? foundCover;
      if (people.isNotEmpty) {
        for (final p in people) {
          final targetKey = p.coverFaceAssetKey ?? '';
          if (targetKey.isNotEmpty) {
            foundCover = widget.allItems.firstWhereOrNull((i) {
              final k = i.getUniqueKey();
              return targetKey == k ||
                  targetKey == '$userId::$k' ||
                  targetKey == i.id ||
                  targetKey.endsWith('::${i.id}');
            });
            if (foundCover != null) break;
          }
        }
      }
      if (mounted) {
        setState(() {
          _peopleCoverItem = foundCover;
        });
      }
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant AlbumsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(widget.allItems, oldWidget.allItems)) {
      _buildItemMap();
      _loadPeoplePreview();
    }
    if (widget.userDocRef != oldWidget.userDocRef) {
      setState(() {
        _userDocStream = widget.userDocRef.snapshots();
      });
    }
  }

  void _buildItemMap() {
    _itemMap = {for (var item in widget.allItems) item.getUniqueKey(): item};
  }

  DriveItem? _findItemByKey(String key) => _itemMap[key];

  Future<void> _createAlbum() async {
    final nameCtrl = TextEditingController();
    final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
            title: const Text('New Album'),
            content: TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                    hintText: 'Album name',
                    border: UnderlineInputBorder(),
                    focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.blue)))),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel')),
              TextButton(
                  onPressed: () {
                    final name = nameCtrl.text.trim();
                    if (name.isNotEmpty) Navigator.pop(context, true);
                  },
                  child: const Text('Create')),
            ]));
    if (ok == true && nameCtrl.text.trim().isNotEmpty) {
      final newName = nameCtrl.text.trim();
      try {
        await widget.userDocRef.update({'albums.$newName': []});
      } catch (e) {
        debugPrint('Error creating album: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not create album. Check connection.')));
        }
      }
    }
  }

  Future<void> _renameAlbum(String oldName) async {
    final nameCtrl = TextEditingController(text: oldName);
    final newName = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
            title: Text('Rename "$oldName"'),
            content: TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                    hintText: 'New album name',
                    border: UnderlineInputBorder(),
                    focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.blue)))),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel')),
              TextButton(
                  onPressed: () {
                    final name = nameCtrl.text.trim();
                    if (name.isNotEmpty && name != oldName) {
                      Navigator.pop(context, name);
                    }
                  },
                  child: const Text('Rename')),
            ]));
    if (newName != null && newName.isNotEmpty && newName != oldName) {
      final snapshot = await widget.userDocRef.get();
      if (!snapshot.exists) return;
      final data = snapshot.data() as Map<String, dynamic>;
      final albumsMap = data['albums'] as Map<String, dynamic>;
      final items = albumsMap[oldName];
      final cover = (data['albumCovers'] as Map<String, dynamic>?)?[oldName];
      final updates = <String, dynamic>{
        'albums.$oldName': FieldValue.delete(),
        'albumCovers.$oldName': FieldValue.delete(),
        'albums.$newName': items ?? [],
      };
      if (cover != null) updates['albumCovers.$newName'] = cover;
      await widget.userDocRef.update(updates);
    }
  }

  void _openSmartAlbum(_SmartAlbumDef def) {
    if (!mounted) return;
    final filteredItems = def.filter(widget.allItems, widget.favorites);
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => _SmartAlbumDetailPage(
              albumName: def.name,
              albumIcon: def.icon,
              albumColor: def.color,
              items: filteredItems,
              getThumbnailUrl: widget.getThumbnailUrl,
              getDownloadUrl: widget.getDownloadUrl,
              favorites: widget.favorites,
              onFavoriteChanged: widget.onFavoriteChanged,
              onMoveToBin: widget.onMoveToBin,
              onAddToAlbum: (item) =>
                  widget.onAddItemsToAlbum([item.getUniqueKey()], def.name),
              oneDriveAccessToken: widget.oneDriveAccessToken,
              dropboxAccessToken: widget.dropboxAccessToken,
              boxAccessToken: widget.boxAccessToken,
              useCaching: widget.useCaching,
            )));
  }

  Future<void> _openAlbum(String name, List<String> currentKeys) async {
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => AlbumDetailPage(
              albumName: name,
              userDocRef: widget.userDocRef,
              allItems: widget.allItems,
              albumItemKeys: currentKeys,
              getThumbnailUrl: widget.getThumbnailUrl,
              getDownloadUrl: widget.getDownloadUrl,
              favorites: widget.favorites,
              onAddToAlbum: (item) =>
                  widget.onAddItemsToAlbum([item.getUniqueKey()], name),
              onFavoriteChanged: widget.onFavoriteChanged,
              onMoveToBin: widget.onMoveToBin,
              oneDriveAccessToken: widget.oneDriveAccessToken,
              dropboxAccessToken: widget.dropboxAccessToken,
              boxAccessToken: widget.boxAccessToken,
              useCaching: widget.useCaching,
            )));
  }

  Widget _buildCleanCard({
    required String title,
    required String subtitle,
    required IconData icon,
    DriveItem? coverItem,
    required VoidCallback onTap,
    required bool isDark,
    required Color textPrimary,
  }) {
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade100;
    final borderColor = isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: cardBg,
          border: Border.all(color: borderColor, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Full Preview Photo if available
            if (coverItem != null) ...[
              PhotoThumbnail(
                item: coverItem,
                getThumbnailUrl: widget.getThumbnailUrl,
                isFavorite: false,
                useCaching: widget.useCaching,
                isSelected: false,
                isInSelectionMode: false,
              ),
              // Subtle dark gradient for clear white text readability
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 72,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.80),
                      ],
                    ),
                  ),
                ),
              ),
            ],

            // 2. Icon badge (Top-left)
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: coverItem != null
                      ? Colors.black.withOpacity(0.45)
                      : (isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: coverItem != null ? Colors.white : textPrimary.withOpacity(0.65),
                  size: 16,
                ),
              ),
            ),

            // 3. Title & Subtitle (Bottom)
            Positioned(
              left: 12,
              right: 12,
              bottom: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: coverItem != null ? Colors.white : textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: coverItem != null
                          ? Colors.white.withOpacity(0.75)
                          : textPrimary.withOpacity(0.55),
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Favourites tile
  Widget _buildFavTile(List<DriveItem> favItems, int count, bool isDark, Color textPrimary) {
    final preview = favItems.isNotEmpty ? favItems.first : null;
    return _buildCleanCard(
      title: 'Favourites',
      subtitle: count == 0 ? 'Empty' : '$count item${count == 1 ? '' : 's'}',
      icon: Icons.favorite_rounded,
      coverItem: preview,
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => FavoritesPage(
            allItems: widget.allItems,
            favoriteKeys: widget.favorites,
            getThumbnailUrl: widget.getThumbnailUrl,
            getDownloadUrl: widget.getDownloadUrl,
            onFavoriteChanged: widget.onFavoriteChanged,
            onMoveToBin: widget.onMoveToBin,
            onShowAddToAlbumDialog: (keys) => widget.onAddItemsToAlbum(keys, ''),
            oneDriveAccessToken: widget.oneDriveAccessToken,
            dropboxAccessToken: widget.dropboxAccessToken,
            boxAccessToken: widget.boxAccessToken,
            useCaching: widget.useCaching,
          ),
        ));
      },
      isDark: isDark,
      textPrimary: textPrimary,
    );
  }

  /// Bin tile
  Widget _buildBinTile(int count, bool isDark, Color textPrimary) {
    final binItems = widget.allItemsWithBin
        .where((i) => widget.binKeys.contains(i.getUniqueKey()))
        .toList();
    final preview = binItems.isNotEmpty ? binItems.first : null;
    return _buildCleanCard(
      title: 'Bin',
      subtitle: count == 0 ? 'Empty' : '$count item${count == 1 ? '' : 's'}',
      icon: Icons.delete_outline_rounded,
      coverItem: preview,
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => BinPage(
            allItems: widget.allItemsWithBin,
            binKeys: widget.binKeys,
            getThumbnailUrl: widget.getThumbnailUrl,
            getDownloadUrl: widget.getDownloadUrl,
            onRestore: widget.onRestore,
            onPermanentDelete: widget.onPermanentDelete,
            oneDriveAccessToken: widget.oneDriveAccessToken,
            dropboxAccessToken: widget.dropboxAccessToken,
            useCaching: widget.useCaching,
          ),
        ));
      },
      isDark: isDark,
      textPrimary: textPrimary,
    );
  }

  /// People & Faces tile
  Widget _buildPeopleTile(bool isDark, Color textPrimary) {
    final subtitle = _peopleCount > 0
        ? '$_peopleCount ${_peopleCount == 1 ? "person" : "people"}'
        : 'Auto-grouped';

    return _buildCleanCard(
      title: 'People & Faces',
      subtitle: subtitle,
      icon: Icons.face_retouching_natural,
      coverItem: _peopleCoverItem,
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PeoplePage(
            isar: isar,
            userId: widget.userDocRef.id,
            allDriveItems: widget.allItemsWithBin,
            getThumbnailUrl: widget.getThumbnailUrl,
            getDownloadUrl: widget.getDownloadUrl,
          ),
        )).then((_) => _loadPeoplePreview());
      },
      isDark: isDark,
      textPrimary: textPrimary,
    );
  }

  /// Smart album card with clean photo thumbnail and subtle gradient.
  Widget _buildSmartAlbumCard(_SmartAlbumDef def, List<DriveItem> filtered, bool isDark, Color textPrimary) {
    final count = filtered.length;
    final DriveItem? preview = count > 0 ? filtered.first : null;
    return _buildCleanCard(
      title: def.name,
      subtitle: '$count item${count == 1 ? '' : 's'}',
      icon: def.icon,
      coverItem: preview,
      onTap: () => _openSmartAlbum(def),
      isDark: isDark,
      textPrimary: textPrimary,
    );
  }

  Widget _buildManualAlbumTile(
      String name, List<String> itemKeys, String? coverKey) {
    DriveItem? coverItem = coverKey != null ? _findItemByKey(coverKey) : null;
    if (coverItem == null && itemKeys.isNotEmpty) {
      for (final key in itemKeys) {
        coverItem = _findItemByKey(key);
        if (coverItem != null) break;
      }
    }
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
              width: 54,
              height: 54,
              color: Colors.grey[200],
              child: coverItem != null
                  ? PhotoThumbnail(
                      item: coverItem,
                      getThumbnailUrl: widget.getThumbnailUrl,
                      isFavorite: false,
                      useCaching: widget.useCaching,
                      isSelected: false,
                      isInSelectionMode: false,
                    )
                  : const Icon(Icons.photo_album_outlined, color: Colors.grey))),
      title: Text(name,
          style:
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
      subtitle: Text(
        '${itemKeys.length} item${itemKeys.length == 1 ? '' : 's'}',
        style: const TextStyle(fontSize: 12),
      ),
      onTap: () => _openAlbum(name, itemKeys),
      trailing: IconButton(
        icon: const Icon(Icons.edit_outlined, size: 20),
        tooltip: 'Rename Album',
        onPressed: () => _renameAlbum(name),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA);
    final textPrimary = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final textSecondary = isDark ? Colors.white60 : Colors.black54;

    final smartData = _smartAlbumDefs
        .map((def) {
          final filtered = def.filter(widget.allItems, widget.favorites);
          return (def: def, filtered: filtered);
        })
        .where((e) => e.filtered.isNotEmpty)
        .toList();

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textPrimary),
        title: Text('Albums',
            style: TextStyle(
                color: textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 22)),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _userDocStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data =
              snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final albumsMap =
              data['albums'] as Map<String, dynamic>? ?? {};
          final coversMap =
              data['albumCovers'] as Map<String, dynamic>? ?? {};
          final sortedAlbumNames = albumsMap.keys.toList()
            ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

          final binCount = widget.binKeys.length;
          final favItems = widget.allItems
              .where((i) => widget.favorites.contains(i.getUniqueKey()))
              .toList();
          final favCount = favItems.length;

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      if (i == 0) return _buildFavTile(favItems, favCount, isDark, textPrimary);
                      if (i == 1) return _buildPeopleTile(isDark, textPrimary);
                      final si = i - 2;
                      if (si < smartData.length) {
                        return _buildSmartAlbumCard(smartData[si].def, smartData[si].filtered, isDark, textPrimary);
                      }
                      return _buildBinTile(binCount, isDark, textPrimary);
                    },
                    childCount: 1 + 1 + smartData.length + 1,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.25,
                  ),
                ),
              ),
              if (albumsMap.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 48),
                    child: Center(
                      child: Icon(Icons.photo_album_outlined,
                          size: 72, color: textSecondary.withOpacity(0.3)),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final name = sortedAlbumNames[index];
                      final rawList = albumsMap[name] as List<dynamic>? ?? [];
                      final itemKeys = rawList.map((e) => e.toString()).toList();
                      final coverKey = coversMap[name] as String?;
                      return _buildManualAlbumTile(name, itemKeys, coverKey);
                    },
                    childCount: sortedAlbumNames.length,
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 88)),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createAlbum,
        tooltip: 'Create New Album',
        child: const Icon(Icons.add),
      ),
    );
  }
}
class _SmartAlbumDetailPage extends StatefulWidget {
  final String albumName;
  final IconData albumIcon;
  final Color albumColor;
  final List<DriveItem> items;
  final Set<String> favorites;
  final Future<String?> Function(DriveItem item) getThumbnailUrl;
  final Future<String?> Function(DriveItem item) getDownloadUrl;
  final Future<void> Function(DriveItem item) onAddToAlbum;
  final void Function(String key, bool isFavorite) onFavoriteChanged;
  final Future<void> Function(DriveItem item) onMoveToBin;
  final String? oneDriveAccessToken;
  final String? dropboxAccessToken;
  final String? boxAccessToken;
  final bool useCaching;
  const _SmartAlbumDetailPage({
    required this.albumName,
    required this.albumIcon,
    required this.albumColor,
    required this.items,
    required this.favorites,
    required this.getThumbnailUrl,
    required this.getDownloadUrl,
    required this.onAddToAlbum,
    required this.onFavoriteChanged,
    required this.onMoveToBin,
    required this.oneDriveAccessToken,
    required this.dropboxAccessToken,
    required this.boxAccessToken,
    required this.useCaching,
  });
  @override
  State<_SmartAlbumDetailPage> createState() => _SmartAlbumDetailPageState();
}
class _SmartAlbumDetailPageState extends State<_SmartAlbumDetailPage> {
  late List<DriveItem> _items;
  @override
  void initState() {
    super.initState();
    _items = List.from(widget.items);
  }
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA);
    final textPrimary = isDark ? Colors.white : const Color(0xFF1A1A2E);
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textPrimary),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: widget.albumColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(widget.albumIcon, color: widget.albumColor, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.albumName,
                    style: TextStyle(
                        color: textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
                Text('${_items.length} item${_items.length == 1 ? '' : 's'}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
      body: _items.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(widget.albumIcon,
                      size: 72, color: widget.albumColor.withOpacity(0.3)),
                  const SizedBox(height: 16),
                  Text('No items in this smart album',
                      style: TextStyle(fontSize: 16, color: Colors.grey[500])),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(2),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 2,
                  mainAxisSpacing: 2),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PhotoViewerPage(
                          items: _items,
                          initialIndex: index,
                          getDownloadUrl: widget.getDownloadUrl,
                          getThumbnailUrl: widget.getThumbnailUrl,
                          favorites: widget.favorites,
                          bin: const {},
                          onFavoriteChanged: widget.onFavoriteChanged,
                          onMoveToBin: (itemToBin) async {
                            await widget.onMoveToBin(itemToBin);
                            if (mounted) {
                              setState(() {
                                _items.removeWhere((i) =>
                                    i.getUniqueKey() ==
                                    itemToBin.getUniqueKey());
                              });
                            }
                          },
                          onAddToAlbum: widget.onAddToAlbum,
                          oneDriveAccessToken: widget.oneDriveAccessToken,
                          dropboxAccessToken: widget.dropboxAccessToken,
                          boxAccessToken: widget.boxAccessToken,
                          useCaching: widget.useCaching,
                        ),
                      ),
                    );
                  },
                  child: PhotoThumbnail(
                    item: item,
                    getThumbnailUrl: widget.getThumbnailUrl,
                    isFavorite: widget.favorites.contains(item.getUniqueKey()),
                    useCaching: widget.useCaching,
                    isSelected: false,
                    isInSelectionMode: false,
                    onFavoriteTap: () {
                      final key = item.getUniqueKey();
                      widget.onFavoriteChanged(
                          key, !widget.favorites.contains(key));
                    },
                  ),
                );
              },
            ),
    );
  }
}
// --- Album Detail Page (MODIFIED) ---
class AlbumDetailPage extends StatefulWidget {
  final String albumName;
  // --- NEW: Pass userDocRef ---
  final DocumentReference userDocRef;
  final List<DriveItem> allItems; // Needs all items to find by key
  final List<String> albumItemKeys; // Initial keys passed in
  final Set<String> favorites;
  final Future<String?> Function(DriveItem item) getThumbnailUrl;
  final Future<String?> Function(DriveItem item) getDownloadUrl;
  final Future<void> Function(DriveItem item) onAddToAlbum; // Still needed for viewer
  final void Function(String key, bool isFavorite) onFavoriteChanged;
  final Future<void> Function(DriveItem item) onMoveToBin;
  final String? oneDriveAccessToken;
  final String? dropboxAccessToken;
  final String? boxAccessToken; // ✅ ADD
  final bool useCaching;
  const AlbumDetailPage({
    super.key,
    required this.albumName,
    required this.userDocRef, // Added
    required this.allItems,
    required this.albumItemKeys,
    required this.favorites,
    required this.getThumbnailUrl,
    required this.getDownloadUrl,
    required this.onAddToAlbum,
    required this.onFavoriteChanged,
    required this.onMoveToBin,
    required this.oneDriveAccessToken,
    required this.dropboxAccessToken,
    required this.boxAccessToken, // ✅ ADD
    required this.useCaching,
  });
  @override
  State<AlbumDetailPage> createState() => _AlbumDetailPageState();
}
class _AlbumDetailPageState extends State<AlbumDetailPage> {
  late List<DriveItem> _itemsInAlbum;
  late Map<String, DriveItem> _itemMap; // For faster lookups
  @override
  void initState() {
    super.initState();
    _buildItemMap();
    _filterItems();
  }
  // Rebuild map and filter if parent data changes
  @override
  void didUpdateWidget(covariant AlbumDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    bool needsRebuild = false;
    if (!listEquals(widget.allItems, oldWidget.allItems)) {
      _buildItemMap(); // Rebuild map if allItems change
      needsRebuild = true;
    }
    // Filter if keys passed from parent change OR if map was rebuilt
    if (!listEquals(widget.albumItemKeys, oldWidget.albumItemKeys) || needsRebuild) {
      _filterItems();
    }
    // Update UI if favorites change
    if (widget.favorites != oldWidget.favorites) {
      setState(() {});
    }
  }
  void _buildItemMap() {
     _itemMap = { for (var item in widget.allItems) item.getUniqueKey() : item };
  }
  void _filterItems() {
    // Filter based on the keys passed in widget.albumItemKeys
    setState(() {
      _itemsInAlbum = [];
      for (final key in widget.albumItemKeys) {
          final item = _itemMap[key]; // Use map for lookup
          if (item != null) {
            _itemsInAlbum.add(item);
          }
      }
      // Optional: Sort items within the album (e.g., by date)
       _itemsInAlbum.sort((a, b) {
          final dateA = a.created;
          final dateB = b.created;
          if (dateA == null && dateB == null) return 0;
          if (dateA == null) return 1;
          if (dateB == null) return -1;
          return dateB.compareTo(dateA); // Newest first within album
       });
    });
  }
  // --- Updated to modify Firestore directly ---
  void _removeItemFromAlbum(DriveItem item) {
     widget.userDocRef.update({
        'albums.${widget.albumName}': FieldValue.arrayRemove([item.getUniqueKey()])
     });
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Removed "${item.name}" from album')));
  }
  // --- Updated to modify Firestore directly ---
  void _setAlbumCover(DriveItem item) {
     widget.userDocRef.update({
        'albumCovers.${widget.albumName}': item.getUniqueKey()
     });
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Set "${item.name}" as album cover')));
  }
   // --- Updated to modify Firestore directly ---
   Future<void> _deleteAlbum() async {
     final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Delete Album?'),
                content: Text(
                    'Are you sure you want to delete the album "${widget.albumName}"? Photos will remain in your library.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)))
                ]));
     if (confirm == true) {
        // Update Firestore directly using FieldValue to remove keys
        widget.userDocRef.update({
           'albums.${widget.albumName}': FieldValue.delete(),
           'albumCovers.${widget.albumName}': FieldValue.delete(),
        });
        if (mounted) Navigator.pop(context); // Close detail page after deletion
     }
   }
  void _showItemOptions(BuildContext context, DriveItem item) {
    showModalBottomSheet(
        context: context,
        builder: (_) => SafeArea(
               child: Wrap(children: [
             ListTile(
                 leading: const Icon(Icons.image_outlined),
                 title: const Text('Set as album cover'),
                 onTap: () {
                   Navigator.pop(context);
                   _setAlbumCover(item);
                 }),
             ListTile(
                 leading: const Icon(Icons.remove_circle_outline),
                 title: const Text('Remove from album'),
                 onTap: () {
                   Navigator.pop(context);
                   _removeItemFromAlbum(item);
                 }),
             ListTile(
                 leading: const Icon(Icons.close),
                 title: const Text('Cancel'),
                 onTap: () => Navigator.pop(context)),
           ])));
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.albumName), actions: [
        IconButton(
           icon: const Icon(Icons.delete_outline),
           tooltip: 'Delete Album',
           onPressed: _deleteAlbum,
        )
      ]),
      body: _itemsInAlbum.isEmpty
          ? const Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.photo_library_outlined, size: 80, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('This album is empty.', style: TextStyle(fontSize: 16)),
                  ]),
             )
          : GridView.builder(
              padding: const EdgeInsets.all(2.0),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 2.0,
                  mainAxisSpacing: 2.0),
              itemCount: _itemsInAlbum.length,
              itemBuilder: (context, index) {
                final item = _itemsInAlbum[index];
                return GestureDetector(
                  onLongPress: () => _showItemOptions(context, item),
                  onTap: () {
                    final albumIndex = _itemsInAlbum.indexWhere(
                        (i) => i.getUniqueKey() == item.getUniqueKey());
                    if (albumIndex != -1) {
                      widget.getThumbnailUrl(item);
                      widget.getDownloadUrl(item);
                      if (albumIndex + 1 < _itemsInAlbum.length) {
                        widget.getDownloadUrl(_itemsInAlbum[albumIndex + 1]);
                      }
                      if (albumIndex - 1 >= 0) {
                        widget.getDownloadUrl(_itemsInAlbum[albumIndex - 1]);
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PhotoViewerPage(
                            items: _itemsInAlbum,
                            initialIndex: albumIndex,
                            getDownloadUrl: widget.getDownloadUrl,
                            getThumbnailUrl: widget.getThumbnailUrl,
                            favorites: widget.favorites,
                            bin: const {},
                            onFavoriteChanged: widget.onFavoriteChanged,
                            onMoveToBin: (itemToBin) async {
                              await widget.onMoveToBin(itemToBin);
                              setState(() {
                                _itemsInAlbum.removeWhere((i) => i.getUniqueKey() == itemToBin.getUniqueKey());
                              });
                            },
                            onAddToAlbum: widget.onAddToAlbum,
                            oneDriveAccessToken: widget.oneDriveAccessToken,
                            dropboxAccessToken: widget.dropboxAccessToken,
                            boxAccessToken: widget.boxAccessToken,
                            useCaching: widget.useCaching,
                          ),
                        ),
                      );
                    }
                  },
                  child: PhotoThumbnail(
                    item: item,
                    getThumbnailUrl: widget.getThumbnailUrl,
                    isFavorite: widget.favorites.contains(item.getUniqueKey()),
                    useCaching: widget.useCaching,
                    isSelected: false,
                    isInSelectionMode: false,
                    onFavoriteTap: () {
                      final key = item.getUniqueKey();
                      final isFavorite = widget.favorites.contains(key);
                      widget.onFavoriteChanged(key, !isFavorite);
                    },
                  ),
                );
              },
            ),
    );
  }
}
class DuplicateSet {
  final BigInt? pHash;
  final String? contentHash;
  final List<DriveItem> items;
  DuplicateSet({this.pHash, this.contentHash, required this.items});
}
class DuplicatesPage extends StatefulWidget {
  final List<DriveItem> allItems; // Initial list (non-binned)
  final Future<String?> Function(DriveItem item) getThumbnailUrl;
  final Future<String?> Function(DriveItem item) getDownloadUrl;
  final Future<void> Function(DriveItem item) onMoveToBin;
  // Need all these parameters to pass to the PhotoViewer
  final void Function(String key, bool isFavorite) onFavoriteChanged;
  final Future<void> Function(List<String> keys) onShowAddToAlbumDialog;
  final String? oneDriveAccessToken;
  final String? dropboxAccessToken;
  final String? boxAccessToken; // ✅ ADD THIS
  final bool useCaching;
  final Set<String> favorites;
  final Set<String> bin; // Need bin to filter updates
  const DuplicatesPage({
    super.key,
    required this.allItems,
    required this.getThumbnailUrl,
    required this.getDownloadUrl,
    required this.onMoveToBin,
    required this.onFavoriteChanged,
    required this.onShowAddToAlbumDialog,
    required this.oneDriveAccessToken,
    required this.dropboxAccessToken,
    required this.boxAccessToken, // ✅ ADD THIS
    required this.useCaching,
    required this.favorites,
    required this.bin,
  });
  @override
  State<DuplicatesPage> createState() => _DuplicatesPageState();
}
class _DuplicatesPageState extends State<DuplicatesPage>
    with SingleTickerProviderStateMixin {
  // --- State for the deduplication process ---
  bool _isScanning = false;
  bool _isProcessed = false;
  String _scanStatus = 'Starting scan...';
  int _processedCount = 0;
  int _totalCount = 0; // Tracked separately for animation target
  List<DuplicateSet> _duplicateSets = [];
  // Store items currently being scanned/hashed (using allItems initially)
  late List<DriveItem> _itemsToScan;
  // --- State for managing selections within the page ---
  // We track which items to *delete*, so 'selected' means 'marked for deletion'
  Set<String> _selectedForDeletion = {};
  // Store items that failed to process
  List<DriveItem> _failedItems = [];
  // --- Smooth animated progress bar ---
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;
  // --- Throttle setState calls: update UI at most 3x/sec not per-image ---
  Timer? _progressTimer;
  // Internal mutable values, flushed to state by timer
  int _pendingProcessed = 0;
  String _pendingStatus = 'Starting scan...';
  @override
  void initState() {
    super.initState();
    // Initialize the animation controller for a smooth progress bar
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _progressAnimation = Tween<double>(begin: 0.0, end: 0.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );
    // Initialize with the items passed in
    _itemsToScan = List<DriveItem>.from(widget.allItems);
    // Start the scan as soon as the page is loaded
    _startDuplicateScan();
  }
  @override
  void dispose() {
    _progressController.dispose();
    _progressTimer?.cancel();
    super.dispose();
  }
  /// Smoothly animates the progress bar from its current value to [target] (0.0–1.0).
  void _animateProgressTo(double target) {
    _progressAnimation = Tween<double>(
      begin: _progressAnimation.value,
      end: target.clamp(0.0, 1.0),
    ).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );
    _progressController
      ..reset()
      ..forward();
  }
  // --- Handle external changes (e.g., item moved to bin) ---
  @override
  void didUpdateWidget(covariant DuplicatesPage oldWidget) {
     super.didUpdateWidget(oldWidget);
     // If the bin contents change, we need to potentially remove items
     // from our current view if they were just moved to the bin.
     if (widget.bin != oldWidget.bin) {
        _removeBinnedItemsFromScan();
     }
  }
  /// --- pHash Logic --- ///
  // 1. The main function to start the scan
  Future<void> _startDuplicateScan() async {
    _CloudPhotosPageState.analytics.logEvent(name: 'scan_duplicates_start');
    if (_isScanning) return;
    setState(() {
      _isScanning = true;
      _isProcessed = false;
      _scanStatus = 'Loading duplicates...';
      _duplicateSets = [];
      _failedItems = [];
      _selectedForDeletion.clear();
      _itemsToScan = widget.allItems.where((item) => !widget.bin.contains(item.getUniqueKey())).toList();
    });
    // Load all database records for this user to pre-populate pHash and contentHash
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      try {
        final records = await assetRepository.findAll(userId);
        final recordMap = {for (var r in records) r.uniqueKey: r};
        for (final item in _itemsToScan) {
          final uniqueKey = '$userId::${item.getUniqueKey()}';
          final record = recordMap[uniqueKey];
          if (record != null) {
            if (record.pHashHex != null) {
              item.pHash = BigInt.parse(record.pHashHex!, radix: 16);
            }
            if (record.contentHash != null) {
              item.contentHash = record.contentHash;
            }
          }
        }
      } catch (e) {
        debugPrint("Error loading Isar cache in duplicate finder: $e");
      }
    }
    _itemsToScan = _itemsToScan.where((item) => item.pHash != null).toList();
    if (!mounted) return;
    _findDuplicateSets(_itemsToScan);
    setState(() {
      _isScanning = false;
      _isProcessed = true;
      _scanStatus = 'Scan complete. Found ${_duplicateSets.length} duplicate sets.';
      _autoSelectDuplicates();
    });
  }
  void _sortBestItemFirst(List<DriveItem> items) {
    items.sort((a, b) {
      // Prioritize larger file size (better resolution/quality)
      final sizeA = a.size ?? 0;
      final sizeB = b.size ?? 0;
      if (sizeA != sizeB) return sizeB.compareTo(sizeA);

      // Prioritize earlier creation date (original source photo)
      final dateA = a.created;
      final dateB = b.created;
      if (dateA != null && dateB != null) return dateA.compareTo(dateB);
      if (dateA != null) return -1;
      if (dateB != null) return 1;

      return a.name.compareTo(b.name);
    });
  }

  // 3. Find sets of duplicates with unified strict centroid clustering
  void _findDuplicateSets(List<DriveItem> itemsToAnalyze) {
    final List<DuplicateSet> duplicateSets = [];
    final Set<String> assignedKeys = {};

    // 1. Group exact byte-for-byte matches (contentHash) first if available
    final Map<String, List<DriveItem>> exactGroups = {};
    for (final item in itemsToAnalyze) {
      if (item.contentHash != null && item.contentHash!.isNotEmpty) {
        exactGroups.putIfAbsent(item.contentHash!, () => []).add(item);
      }
    }
    exactGroups.forEach((hash, items) {
      if (items.length > 1) {
        _sortBestItemFirst(items);
        duplicateSets.add(DuplicateSet(contentHash: hash, items: items));
        for (final item in items) {
          assignedKeys.add(item.getUniqueKey());
        }
      }
    });

    // 2. Group visual duplicate copies using strict centroid matching (Hamming <= 4 bits)
    const int kStrictThreshold = 4; // <= 4 bits out of 64 (~94%+ visual equivalence)
    final List<DriveItem> hashableItems = itemsToAnalyze
        .where((item) => !item.isVideo && item.pHash != null && !assignedKeys.contains(item.getUniqueKey()))
        .toList();

    _sortBestItemFirst(hashableItems);

    for (int i = 0; i < hashableItems.length; i++) {
      final leader = hashableItems[i];
      final leaderKey = leader.getUniqueKey();
      if (assignedKeys.contains(leaderKey)) continue;

      final List<DriveItem> cluster = [leader];

      for (int j = i + 1; j < hashableItems.length; j++) {
        final candidate = hashableItems[j];
        final candKey = candidate.getUniqueKey();
        if (assignedKeys.contains(candKey)) continue;

        // Strict comparison to cluster leader (centroid)
        final dist = _hammingDistance(leader.pHash!, candidate.pHash!);
        if (dist <= kStrictThreshold) {
          cluster.add(candidate);
          assignedKeys.add(candKey);
        }
      }

      if (cluster.length > 1) {
        assignedKeys.add(leaderKey);
        _sortBestItemFirst(cluster);
        duplicateSets.add(DuplicateSet(pHash: leader.pHash, items: cluster));
      }
    }

    duplicateSets.sort((a, b) => b.items.length.compareTo(a.items.length));
    setState(() {
      _duplicateSets = duplicateSets;
    });
  }

  // 4. Auto-select copies for deletion (keep index 0)
  void _autoSelectDuplicates() {
    final Set<String> toDelete = {};
    for (final set in _duplicateSets) {
      for (int i = 1; i < set.items.length; i++) {
        toDelete.add(set.items[i].getUniqueKey());
      }
    }
    setState(() {
      _selectedForDeletion = toDelete;
    });
  }

  // Toggle user selection for deletion
  void _toggleSelection(DriveItem item) {
    final key = item.getUniqueKey();
    setState(() {
      if (_selectedForDeletion.contains(key)) {
        _selectedForDeletion.remove(key);
      } else {
        _selectedForDeletion.add(key);
      }
    });
  }

  int _getKeepCount(DuplicateSet set) {
    int keepCount = 0;
    for (final item in set.items) {
      if (!_selectedForDeletion.contains(item.getUniqueKey())) {
        keepCount++;
      }
    }
    return keepCount;
  }

  int _getTotalSelectedBytes() {
    int total = 0;
    for (final set in _duplicateSets) {
      for (final item in set.items) {
        if (_selectedForDeletion.contains(item.getUniqueKey())) {
          total += (item.size ?? 1800000);
        }
      }
    }
    return total;
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = (math.log(bytes) / math.log(1024)).floor();
    return '${(bytes / math.pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }

  void _openPhotoViewer(DriveItem item, DuplicateSet set) {
    final itemsInSet = set.items;
    final itemIndexInSet = itemsInSet.indexWhere((i) => i.getUniqueKey() == item.getUniqueKey());
    if (itemIndexInSet == -1) return;

    widget.getThumbnailUrl(item);
    widget.getDownloadUrl(item);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PhotoViewerPage(
          items: itemsInSet,
          initialIndex: itemIndexInSet,
          getDownloadUrl: widget.getDownloadUrl,
          getThumbnailUrl: widget.getThumbnailUrl,
          favorites: widget.favorites,
          bin: widget.bin,
          onFavoriteChanged: widget.onFavoriteChanged,
          onMoveToBin: (itemToBin) async {
            await widget.onMoveToBin(itemToBin);
            _removeItemFromScanAndUpdateUI(itemToBin);
          },
          onAddToAlbum: (item) => widget.onShowAddToAlbumDialog([item.getUniqueKey()]),
          oneDriveAccessToken: widget.oneDriveAccessToken,
          dropboxAccessToken: widget.dropboxAccessToken,
          boxAccessToken: widget.boxAccessToken,
          useCaching: widget.useCaching,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA);
    final textPrimary = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final int totalSelectedForDeletion = _selectedForDeletion.length;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textPrimary),
        title: Text(
          'Duplicate Finder',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          if (_isProcessed && !_isScanning)
            IconButton(
              icon: Icon(Icons.refresh_rounded, color: textPrimary),
              tooltip: 'Rescan for Duplicates',
              onPressed: _startDuplicateScan,
            ),
        ],
      ),
      body: _buildContent(isDark, textPrimary),

      // Floating action bar
      floatingActionButton: (_isProcessed && totalSelectedForDeletion > 0)
          ? FloatingActionButton.extended(
              onPressed: _confirmDeleteSelected,
              backgroundColor: Colors.red.shade600,
              elevation: 4,
              icon: const Icon(Icons.delete_sweep_rounded, color: Colors.white),
              label: Text(
                'Delete $totalSelectedForDeletion ${_selectedForDeletion.length == 1 ? "Item" : "Items"} (${_formatBytes(_getTotalSelectedBytes())})',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildContent(bool isDark, Color textPrimary) {
    if (_isScanning) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFF0078D4)),
            const SizedBox(height: 16),
            Text(
              'Finding duplicates...',
              style: TextStyle(color: textPrimary.withValues(alpha: 0.7), fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (_isProcessed && _duplicateSets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.green.shade500, size: 72),
            const SizedBox(height: 16),
            Text(
              'No Duplicates Found!',
              style: TextStyle(color: textPrimary, fontSize: 19, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Your photo library is completely clean.',
              style: TextStyle(color: textPrimary.withValues(alpha: 0.6), fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 96),
      itemCount: 1 + _duplicateSets.length,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildSummaryCard(isDark, textPrimary);
        }
        final setIndex = index - 1;
        final set = _duplicateSets[setIndex];
        return _buildSetCard(setIndex, set, isDark, textPrimary);
      },
    );
  }

  Widget _buildSummaryCard(bool isDark, Color textPrimary) {
    final totalDuplicates = _duplicateSets.fold<int>(0, (prev, s) => prev + (s.items.length - 1));
    final totalBytes = _getTotalSelectedBytes();
    final totalSelected = _selectedForDeletion.length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF0078D4).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome, color: Color(0xFF0078D4), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_duplicateSets.length} Duplicate ${_duplicateSets.length == 1 ? 'Group' : 'Groups'} Found',
                  style: TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  totalSelected > 0
                      ? '$totalSelected selected (${_formatBytes(totalBytes)} recoverable)'
                      : '$totalDuplicates potential duplicates',
                  style: TextStyle(
                    color: textPrimary.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                if (_selectedForDeletion.isEmpty) {
                  _autoSelectDuplicates();
                } else {
                  _selectedForDeletion.clear();
                }
              });
            },
            child: Text(
              _selectedForDeletion.isEmpty ? 'Select All' : 'Deselect',
              style: const TextStyle(
                color: Color(0xFF0078D4),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetCard(int setIndex, DuplicateSet set, bool isDark, Color textPrimary) {
    final keepCount = _getKeepCount(set);
    final deleteCount = set.items.length - keepCount;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0078D4).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Set ${setIndex + 1}',
                        style: const TextStyle(
                          color: Color(0xFF0078D4),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${set.items.length} photos',
                      style: TextStyle(
                        color: textPrimary.withValues(alpha: 0.6),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Text(
                  deleteCount > 0 ? '$deleteCount to delete' : 'All kept',
                  style: TextStyle(
                    color: deleteCount > 0 ? Colors.redAccent : Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Photo Strip / Grid
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: GridView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: math.min(set.items.length, 3),
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.88,
              ),
              itemCount: set.items.length,
              itemBuilder: (context, itemIndex) {
                final item = set.items[itemIndex];
                final isSelected = _selectedForDeletion.contains(item.getUniqueKey());
                final isBest = itemIndex == 0;
                return _buildCleanPhotoTile(item, set, isSelected, isBest, isDark, textPrimary);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCleanPhotoTile(
    DriveItem item,
    DuplicateSet set,
    bool isSelectedForDeletion,
    bool isBestItem,
    bool isDark,
    Color textPrimary,
  ) {
    final itemSizeStr = item.size != null ? _formatBytes(item.size!) : null;

    return GestureDetector(
      onTap: () => _toggleSelection(item),
      onLongPress: () => _openPhotoViewer(item, set),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelectedForDeletion
                ? Colors.redAccent.withValues(alpha: 0.8)
                : (isBestItem
                    ? Colors.green.withValues(alpha: 0.9)
                    : (isDark ? Colors.white24 : Colors.black12)),
            width: isSelectedForDeletion || isBestItem ? 2.0 : 1.0,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Clean photo thumbnail (100% unobstructed)
              PhotoThumbnail(
                item: item,
                getThumbnailUrl: widget.getThumbnailUrl,
                useCaching: widget.useCaching,
                isFavorite: widget.favorites.contains(item.getUniqueKey()),
                isInSelectionMode: false,
                isSelected: false,
                onTap: null,
                onLongPress: null,
              ),

              // Subtle dimming only when selected for deletion
              if (isSelectedForDeletion)
                Container(
                  color: Colors.black.withValues(alpha: 0.18),
                ),

              // "Best" Badge on the Keeper
              if (isBestItem)
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.green.shade700.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 3,
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded, color: Colors.white, size: 11),
                        SizedBox(width: 3),
                        Text(
                          'Best',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Checkbox indicator on the top-right
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelectedForDeletion
                        ? Colors.redAccent
                        : Colors.black.withValues(alpha: 0.4),
                    border: Border.all(
                      color: isSelectedForDeletion ? Colors.transparent : Colors.white70,
                      width: 1.5,
                    ),
                  ),
                  child: isSelectedForDeletion
                      ? const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 13)
                      : (isBestItem
                          ? const Icon(Icons.check, color: Colors.white70, size: 13)
                          : null),
                ),
              ),

              // Bottom Info Gradient Bar (File Size)
              if (itemSizeStr != null)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.75),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Text(
                      itemSizeStr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Deletion Logic --- //
  Future<void> _confirmDeleteSelected() async {
    final int count = _selectedForDeletion.length;
    if (count == 0) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $count Duplicates?'),
        content: Text(
          'This will move $count selected duplicates to the Bin (${_formatBytes(_getTotalSelectedBytes())} will be freed). You can restore them anytime from the Bin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Move to Bin', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      _deleteSelected();
    }
  }

  Future<void> _deleteSelected() async {
    final itemsToDeleteKeys = _selectedForDeletion.toList();
    if (itemsToDeleteKeys.isEmpty) return;

    setState(() {
      _selectedForDeletion.clear();
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final snackBarController = ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Moving ${itemsToDeleteKeys.length} items to Bin...'),
      duration: const Duration(minutes: 1),
    ));

    int successCount = 0;
    for (final key in itemsToDeleteKeys) {
      if (!mounted) break;
      final item = _itemsToScan.firstWhereOrNull((i) => i.getUniqueKey() == key);
      if (item != null) {
        try {
          await widget.onMoveToBin(item);
          _removeItemFromScanAndUpdateUI(item);
          successCount++;
        } catch (e) {
          debugPrint("Error moving duplicate to bin: $e");
        }
      }
    }

    snackBarController.close();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Moved $successCount duplicates to Bin.'),
        backgroundColor: Colors.green,
      ));
    }
  }

  void _removeItemFromScanAndUpdateUI(DriveItem item) {
    final key = item.getUniqueKey();
    setState(() {
      _selectedForDeletion.remove(key);
      _itemsToScan.removeWhere((i) => i.getUniqueKey() == key);
      for (final set in _duplicateSets) {
        set.items.removeWhere((i) => i.getUniqueKey() == key);
      }
      _duplicateSets.removeWhere((set) => set.items.length < 2);
      _scanStatus = 'Scan complete. Found ${_duplicateSets.length} duplicate sets.';
    });
  }

  void _removeBinnedItemsFromScan() {
    bool itemsRemoved = false;
    setState(() {
      int initialLength = _itemsToScan.length;
      _itemsToScan.removeWhere((item) => widget.bin.contains(item.getUniqueKey()));
      if (_itemsToScan.length < initialLength) {
        itemsRemoved = true;
      }
      _selectedForDeletion.removeWhere((key) => widget.bin.contains(key));
      for (final set in _duplicateSets) {
        set.items.removeWhere((item) => widget.bin.contains(item.getUniqueKey()));
      }
      _duplicateSets.removeWhere((set) => set.items.length < 2);
      if (itemsRemoved) {
        _scanStatus = 'Scan complete. Found ${_duplicateSets.length} duplicate sets.';
      }
    });
  }
}
/// --- pHash Utilities --- ///
/// Counts the number of bits that differ between two 64-bit perceptual hashes
/// (Hamming distance). A distance of 0 means identical; ≤10 means visually similar.
int _hammingDistance(BigInt a, BigInt b) {
  BigInt xor = a ^ b;
  int distance = 0;
  while (xor > BigInt.zero) {
    // Brian Kernighan's bit-counting trick: clears the lowest set bit each iteration
    xor = xor & (xor - BigInt.one);
    distance++;
  }
  return distance;
}
// This is the function that runs in the isolate
// It takes the image bytes and returns the pHash
BigInt _computePHashIsolate(Uint8List imageBytes) {
  // Decode the image
  final img.Image? image = img.decodeImage(imageBytes);
  if (image == null) {
    throw Exception('Could not decode image');
  }
  // --- pHash Algorithm (simplified perceptual hash) ---
  // 1. Resize to a small square (e.g., 8x8 or 32x32 then 8x8)
  final smallImage = img.copyResize(image, width: 8, height: 8, interpolation: img.Interpolation.linear);
  // 2. Convert to grayscale
  final grayscale = List<int>.filled(64, 0);
  double totalLuminance = 0;
  for (int y = 0; y < 8; y++) {
    for (int x = 0; x < 8; x++) {
      final pixel = smallImage.getPixel(x, y);
      // Using luminance calculation (more accurate than simple average)
      final luminance = (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b).round();
      grayscale[y * 8 + x] = luminance;
      totalLuminance += luminance;
    }
  }
  // 3. Compute the average luminance
  final avgLuminance = totalLuminance / 64.0;
  // 4. Create the 64-bit hash: 1 if pixel >= avg, 0 if pixel < avg
  BigInt hash = BigInt.zero;
  for (int i = 0; i < 64; i++) {
    if (grayscale[i] >= avgLuminance) {
      // Set the i-th bit (using bitwise OR and left shift)
      hash = hash | (BigInt.one << i);
    }
  }
  return hash;}
class UnifiedDocsPage extends StatefulWidget {
  final String? oneDriveAccessToken;
  final String? dropboxAccessToken;
  final String? boxAccessToken;
  final String? pCloudAccessToken;
  final User firebaseUser;
  final Future<bool> Function(PhotoSource source) onRefreshTokens;
  final Future<String?> Function(DriveItem item) getThumbnailUrl;
  final Future<String?> Function(DriveItem item) getDownloadUrl;
  final Set<String> favorites;
  final Set<String> bin;
  final void Function(String key, bool isFavorite) onFavoriteChanged;
  final Future<void> Function(DriveItem item) onMoveToBin;
  final Future<void> Function(List<String> keys) onShowAddToAlbumDialog;
  final bool useCaching;
  final bool isPro; // <--- ✅ ADD THIS
  final Future<void> Function(DriveItem item, PhotoSource destination)? onTransferFile;
  final String? oneDriveRefreshToken;
  final String? dropboxRefreshToken;
  final String? boxRefreshToken;
  const UnifiedDocsPage({
    super.key,
    this.oneDriveAccessToken,
    this.dropboxAccessToken,
    this.boxAccessToken,
    this.pCloudAccessToken,
    required this.firebaseUser,
    required this.onRefreshTokens,
    required this.getThumbnailUrl,
    required this.getDownloadUrl,
    required this.favorites,
    required this.bin,
    required this.onFavoriteChanged,
    required this.onMoveToBin,
    required this.onShowAddToAlbumDialog,
    required this.useCaching,
    required this.isPro, // <--- ✅ ADD THIS
    this.onTransferFile,
    this.oneDriveRefreshToken,
    this.dropboxRefreshToken,
    this.boxRefreshToken,
  });
  @override
  State<UnifiedDocsPage> createState() => _UnifiedDocsPageState();
}
class _UnifiedDocsPageState extends State<UnifiedDocsPage> {
  List<DriveItem> _allDocs = [];
  List<DriveItem> _filteredDocs = [];
  bool _isLoading = true;
  PhotoSource? _currentFilter; // null means "All"
  // Bug Fix 6: Search state for Files tab
  String _searchQuery = '';
  final TextEditingController _filesSearchController = TextEditingController();
  @override
  void dispose() {
    _filesSearchController.dispose();
    super.dispose();
  }
  // Bug Fix 6: Public method so parent can push search queries from AppBar
  void applySearch(String query) {
    if (!mounted) return;
    setState(() {
      _searchQuery = query.toLowerCase();
      _applyFilter();
    });
  }
  bool isDocument(String filename) {
    final name = filename.toLowerCase();
    return name.endsWith('.pdf') ||
        name.endsWith('.doc') ||
        name.endsWith('.docx') ||
        name.endsWith('.xls') ||
        name.endsWith('.xlsx') ||
        name.endsWith('.ppt') ||
        name.endsWith('.pptx') ||
        name.endsWith('.txt') ||
        name.endsWith('.rtf') ||
        name.endsWith('.csv') ||
        name.endsWith('.epub') ||
        name.endsWith('.mobi') ||
        name.endsWith('.zip') ||
        name.endsWith('.rar') ||
        name.endsWith('.7z') ||
        name.endsWith('.tar');
  }
  @override
  void initState() {
    super.initState();
    _fetchAllDocs();
  }
  // Bug Fix 5: Auto-reload when tokens become available (IndexedStack builds early, before tokens are ready)
  @override
  void didUpdateWidget(covariant UnifiedDocsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool tokensBecameAvailable =
        (oldWidget.oneDriveAccessToken == null && widget.oneDriveAccessToken != null) ||
        (oldWidget.dropboxAccessToken == null && widget.dropboxAccessToken != null) ||
        (oldWidget.boxAccessToken == null && widget.boxAccessToken != null) ||
        (oldWidget.pCloudAccessToken == null && widget.pCloudAccessToken != null);
    if (tokensBecameAvailable) {
      debugPrint("📁 Files: New token available — auto-fetching docs...");
      _fetchAllDocs();
    }
  }
  Future<void> _fetchAllDocs() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    List<DriveItem> aggregated = [];
    // Parallel fetch from all providers
    await Future.wait<void>([
      if (widget.oneDriveAccessToken != null) _fetchOneDriveDocs(aggregated),
      if (widget.dropboxAccessToken != null) _fetchDropboxDocs(aggregated),
      if (widget.boxAccessToken != null) _fetchBoxDocs(aggregated),
      if (widget.pCloudAccessToken != null) _fetchPCloudDocs(aggregated),
    ]);
    // Sort by Newest First (Created Date)
    aggregated.sort((a, b) {
      final dateA = a.created ?? DateTime(1970);
      final dateB = b.created ?? DateTime(1970);
      return dateB.compareTo(dateA);
    });
    if (mounted) {
      setState(() {
        _allDocs = aggregated;
        _applyFilter();
        _isLoading = false;
      });
    }
  }
  void _applyFilter() {
    List<DriveItem> result = _currentFilter == null
        ? _allDocs
        : _allDocs.where((i) => i.source == _currentFilter).toList();
    // Bug Fix 6: Apply text search on top of source filter
    if (_searchQuery.isNotEmpty) {
      result = result.where((i) => i.name.toLowerCase().contains(_searchQuery)).toList();
    }
    _filteredDocs = result;
  }
  Future<void> _fetchOneDriveDocs(List<DriveItem> list) async {
    final Set<String> processedIds = {}; // Track IDs to avoid duplicates
    // Helper to process a list of items
    void processList(List<dynamic> items) {
      for (var entry in items) {
        if (entry['id'] != null && !processedIds.contains(entry['id'])) {
          // Check if it's a file (not folder) AND is a document
          if (entry['file'] != null && isDocument(entry['name'])) {
            processedIds.add(entry['id']);
            list.add(DriveItem(
              id: entry['id'],
              name: entry['name'],
              source: PhotoSource.oneDrive,
              created: entry['fileSystemInfo']?['createdDateTime'] != null
                  ? DateTime.parse(entry['fileSystemInfo']['createdDateTime'])
                  : (entry['createdDateTime'] != null
                      ? DateTime.parse(entry['createdDateTime'])
                      : null),
              size: entry['size'],
            ));
          }
        }
      }
    }
    try {
      // 1. Fetch Root Folder (Instant visibility for new uploads)
      final rootResponse = await http.get(
        Uri.parse("https://graph.microsoft.com/v1.0/me/drive/root/children"),
        headers: {"Authorization": "Bearer ${widget.oneDriveAccessToken}"},
      );
      if (rootResponse.statusCode == 200) {
        processList(jsonDecode(rootResponse.body)['value']);
      }
      // 2. Fetch Recent Files (Finds files in subfolders)
      final recentResponse = await http.get(
        Uri.parse("https://graph.microsoft.com/v1.0/me/drive/recent"),
        headers: {"Authorization": "Bearer ${widget.oneDriveAccessToken}"},
      );
      if (recentResponse.statusCode == 200) {
        processList(jsonDecode(recentResponse.body)['value']);
      }
    } catch (e) {
      debugPrint("OneDrive doc fetch error: $e");
    }
  }
  Future<void> _fetchBoxDocs(List<DriveItem> list) async {
    final Set<String> processedIds = {};
    void processEntries(List<dynamic> entries) {
      for (var entry in entries) {
        if (!processedIds.contains(entry['id'])) {
          if (entry['type'] == 'file' && isDocument(entry['name'])) {
            processedIds.add(entry['id']);
            list.add(DriveItem(
              id: entry['id'],
              name: entry['name'],
              source: PhotoSource.box,
              created: entry['created_at'] != null ? DateTime.parse(entry['created_at']) : null,
              size: entry['size'],
            ));
          }
        }
      }
    }
    try {
      // 1. Fetch Root Folder (Instant)
      final rootResponse = await http.get(
        Uri.parse("https://api.box.com/2.0/folders/0/items?limit=50&sort=date&direction=DESC"),
        headers: {"Authorization": "Bearer ${widget.boxAccessToken}"},
      );
      if (rootResponse.statusCode == 200) {
        processEntries(jsonDecode(rootResponse.body)['entries']);
      }
      // 2. Search Everything (Finds deep files)
      final searchResponse = await http.get(
        Uri.parse("https://api.box.com/2.0/search?query=*&type=file&limit=50"),
        headers: {"Authorization": "Bearer ${widget.boxAccessToken}"},
      );
      if (searchResponse.statusCode == 200) {
        processEntries(jsonDecode(searchResponse.body)['entries']);
      }
    } catch (e) {
      debugPrint("Box doc fetch error: $e");
    }
  }
  Future<void> _fetchDropboxDocs(List<DriveItem> list) async {
    try {
      // Robust fix: Use list_folder with recursive: true instead of indexing-dependent search
      final response = await http.post(
        Uri.parse("https://api.dropboxapi.com/2/files/list_folder"),
        headers: {
          "Authorization": "Bearer ${widget.dropboxAccessToken}",
          "Content-Type": "application/json"
        },
        body: jsonEncode({
          "path": "",
          "recursive": true,
          "limit": 500,
          "include_media_info": false
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        for (var entry in data['entries']) {
          if (entry['.tag'] == 'file' && isDocument(entry['name'])) {
            list.add(DriveItem(
              id: entry['path_lower'],
              name: entry['name'],
              source: PhotoSource.dropbox,
              created: entry['client_modified'] != null ? DateTime.parse(entry['client_modified']) : null,
              size: entry['size'],
            ));
          }
        }
      }
    } catch (e) {
      debugPrint("Dropbox doc fetch error: $e");
    }
  }
  Future<void> _fetchPCloudDocs(List<DriveItem> list) async {
    try {
      final storedLoc = await secureStorage.read(key: '${widget.firebaseUser.uid}_pcloud_location_id');
      final primaryHost = (storedLoc == '2') ? 'eapi.pcloud.com' : 'api.pcloud.com';
      final fallbackHost = (storedLoc == '2') ? 'api.pcloud.com' : 'eapi.pcloud.com';

      Future<http.Response?> fetchDocs(String host) async {
        try {
          final url = Uri.https(host, '/listfolder', {
            'folderid': '0',
            'recursive': '1',
            'showprogress': '0',
            'access_token': widget.pCloudAccessToken ?? '',
          });
          // Increased from 25s → 60s: large pCloud accounts take 30-50s recursively
          return await http.get(url).timeout(const Duration(seconds: 60));
        } catch (_) {
          return null;
        }
      }

      http.Response? response = await fetchDocs(primaryHost);
      Map<String, dynamic>? data;
      if (response != null && response.statusCode == 200) {
        data = jsonDecode(response.body);
      }
      if (data == null || data['result'] == 2000) {
        final fbResponse = await fetchDocs(fallbackHost);
        if (fbResponse != null && fbResponse.statusCode == 200) {
          final fbData = jsonDecode(fbResponse.body);
          if (fbData['result'] == 0) {
            data = fbData;
            final correctLoc = fallbackHost.contains('eapi') ? '2' : '1';
            await secureStorage.write(key: '${widget.firebaseUser.uid}_pcloud_location_id', value: correctLoc);
          }
        }
      }

      if (data != null && data['result'] == 0) {
        final List<dynamic> allRawFiles = [];
        void collectFiles(dynamic node) {
          if (node == null) return;
          if (node is Map) {
            final isFolder = node['isfolder'] == true || node['isfolder'] == 1 || node['isfolder'] == 'true';
            if (isFolder) {
              final children = node['contents'];
              if (children is List) {
                for (var child in children) {
                  collectFiles(child);
                }
              }
            } else {
              allRawFiles.add(node);
            }
          }
        }
        collectFiles(data['metadata']);

        for (var entry in allRawFiles) {
          if (entry is! Map) continue;
          final name = entry['name']?.toString() ?? '';
          if (isDocument(name)) {
            final rawSize = entry['size'];
            final int? size = rawSize is int ? rawSize : int.tryParse(rawSize?.toString() ?? '');
            list.add(DriveItem(
              id: entry['fileid'].toString(),
              name: name,
              source: PhotoSource.pCloud,
              created: _parsePCloudDate(entry['created']) ?? _parsePCloudDate(entry['modified']),
              size: size,
            ));
          }
        }
      }
    } catch (e) {
      debugPrint('pCloud doc fetch error: $e');
    }
  }
  Future<void> _openDocument(DriveItem item) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text("Downloading document..."),
              ],
            ),
          ),
        ),
      ),
    );
    try {
      final downloadUrl = await widget.getDownloadUrl(item);
      if (downloadUrl == null) throw Exception('Could not get download link');
      // FIX: Add timeout — pCloud CDN links are temporary and can expire/stall
      final response = await http.get(Uri.parse(downloadUrl))
          .timeout(const Duration(seconds: 60));
      if (response.statusCode != 200) {
        throw Exception('Download failed (HTTP ${response.statusCode}). The link may have expired.');
      }
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/${item.name}');
      await file.writeAsBytes(response.bodyBytes);
      if (mounted) Navigator.pop(context); // Close loading dialog
      await OpenFile.open(file.path);
    } catch (e) {
      if (mounted) Navigator.pop(context); // Close loading dialog
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Could not open: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }
  String _getTimeAgo(DateTime? dt) {
    if (dt == null) return "Unknown";
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return "${diff.inDays}d ago";
    if (diff.inHours > 0) return "${diff.inHours}h ago";
    if (diff.inMinutes > 0) return "${diff.inMinutes}m ago";
    return "Just now";
  }
  IconData _getFileIcon(String fileName) {
    final name = fileName.toLowerCase();
    if (name.endsWith('.pdf')) return Icons.picture_as_pdf_rounded;
    if (name.contains('.doc') || name.endsWith('.rtf')) return Icons.description_rounded;
    if (name.contains('.xls') || name.endsWith('.csv')) return Icons.table_chart_rounded;
    if (name.contains('.ppt')) return Icons.slideshow_rounded;
    if (name.endsWith('.zip') || name.endsWith('.rar') || name.endsWith('.7z') || name.endsWith('.tar')) return Icons.archive_rounded;
    if (name.endsWith('.txt')) return Icons.text_snippet_rounded;
    if (name.endsWith('.epub') || name.endsWith('.mobi')) return Icons.book_rounded;
    return Icons.insert_drive_file_rounded;
  }
  Color _getFileColor(String fileName) {
    final name = fileName.toLowerCase();
    if (name.contains('.pdf')) return Colors.red;
    if (name.contains('.doc') || name.endsWith('.rtf')) return Colors.blue;
    if (name.contains('.xls') || name.endsWith('.csv')) return Colors.green;
    if (name.contains('.ppt')) return Colors.orange;
    if (name.contains('.zip') || name.contains('.rar') || name.contains('.7z') || name.endsWith('.tar')) return Colors.amber;
    if (name.endsWith('.epub') || name.endsWith('.mobi')) return Colors.teal;
    return Colors.grey;
  }
  void _showFolderBrowserOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text("Select Cloud to Browse", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            if (widget.oneDriveAccessToken != null)
              _buildProviderOption("OneDrive", Icons.cloud_outlined, PhotoSource.oneDrive),
            if (widget.dropboxAccessToken != null)
              _buildProviderOption("Dropbox", Icons.folder_copy_outlined, PhotoSource.dropbox),
            if (widget.boxAccessToken != null)
              _buildProviderOption("Box", Icons.inventory_2_outlined, PhotoSource.box),
            if (widget.pCloudAccessToken != null)
              _buildProviderOption("pCloud", Icons.cloud_circle_outlined, PhotoSource.pCloud),
          ],
        ),
      ),
    );
  }
  Widget _buildProviderOption(String name, IconData icon, PhotoSource source) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue),
      title: Text(name),
      onTap: () {
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(builder: (context) => FolderBrowserScreen(
          source: source,
          folderId: source == PhotoSource.dropbox ? "" : "0",
          folderName: name,
          oneDriveAccessToken: widget.oneDriveAccessToken,
          dropboxAccessToken: widget.dropboxAccessToken,
          boxAccessToken: widget.boxAccessToken,
          pCloudAccessToken: widget.pCloudAccessToken,
          onRefreshTokens: widget.onRefreshTokens,
          getThumbnailUrl: widget.getThumbnailUrl,
          getDownloadUrl: widget.getDownloadUrl,
          favorites: widget.favorites,
          bin: widget.bin,
          onFavoriteChanged: widget.onFavoriteChanged,
          onMoveToBin: widget.onMoveToBin,
          onShowAddToAlbumDialog: widget.onShowAddToAlbumDialog,
          useCaching: widget.useCaching,
          firebaseUser: widget.firebaseUser,
        )));
      },
    );
  }
  // ✅ 1. ADD THE LOCK DIALOG HERE
  void _showProLockDialog({String? content}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            const Icon(Icons.lock_outline, size: 50, color: Colors.blueAccent),
            const SizedBox(height: 10),
            const Text("Pro Feature", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          content ?? "Folder Mode allows deep root access to your cloud storage.\n\nUpgrade to Pro to unlock Folder Browsing.",
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            onPressed: () {
              Navigator.pop(context);
              // You can pop back to home to show the main Pro dialog if you want
              Navigator.pop(context); 
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Go to Sidebar > Upgrade to buy Pro!"))
              );
            },
            child: const Text("Upgrade", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
        title: Text('Files',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: Theme.of(context).colorScheme.onSurface)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _fetchAllDocs,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip(null, "All"),
                _buildFilterChip(PhotoSource.oneDrive, "OneDrive"),
                _buildFilterChip(PhotoSource.dropbox, "Dropbox"),
                _buildFilterChip(PhotoSource.box, "Box"),
                _buildFilterChip(PhotoSource.pCloud, "pCloud"),
              ],
            ),
          ),
          // Docs List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredDocs.isEmpty
                    ? Center(child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.file_copy_outlined, size: 80, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          const Text("No documents found.", style: TextStyle(color: Colors.grey)),
                        ],
                      ))
                    : ListView.builder(
                        itemCount: _filteredDocs.length,
                        padding: const EdgeInsets.only(bottom: 80),
                        itemBuilder: (context, index) {
                          final item = _filteredDocs[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: Colors.grey.shade200),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: _getFileColor(item.name).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(_getFileIcon(item.name), color: _getFileColor(item.name)),
                              ),
                              title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text("${item.source.name} • ${_getTimeAgo(item.created)}"),
                              trailing: IconButton(
                                icon: const Icon(Icons.more_vert, size: 20, color: Colors.black54),
                                onPressed: () => _showInfoPanel(item),
                              ),
                              onTap: () => _openDocument(item),
                              onLongPress: () => _showInfoPanel(item),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      // ✅ 2. UPDATE THE FLOATING ACTION BUTTON
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (widget.isPro) {
            _showFolderBrowserOptions(); // Allow access if Pro
          } else {
            _showProLockDialog(); // Block access if Free
          }
        },
        label: const Text("Folder Mode"),
        // Change icon to Lock if not Pro
        icon: Icon(widget.isPro ? Icons.folder_open_rounded : Icons.lock_outline),
        // Change color to Grey if not Pro
        backgroundColor: widget.isPro ? Colors.blue.shade700 : Colors.grey.shade700,
      ),
    );
  }
  Widget _buildFilterChip(PhotoSource? source, String label) {
    bool isSelected = _currentFilter == source;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (val) {
          setState(() {
            _currentFilter = source;
            _applyFilter();
          });
        },
        backgroundColor: Colors.white,
        selectedColor: Colors.blue.shade100,
        checkmarkColor: Colors.blue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSelected ? Colors.blue : Colors.grey.shade300)),
      ),
    );
  }
  // =============================================================================
  // --- FILE MANAGEMENT PANEL METHODS ---
  // =============================================================================
  void _showInfoPanel(DriveItem item) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final itemKey = item.getUniqueKey();
        final bool isFavorited = widget.favorites.contains(itemKey);
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_getFileIcon(item.name), color: Theme.of(context).primaryColor, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          item.source.name.toUpperCase(),
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 32),
              ListTile(
                leading: const Icon(Icons.download_rounded),
                title: const Text("Download & Open"),
                onTap: () {
                  Navigator.pop(context);
                  _openDocument(item);
                },
              ),
              ListTile(
                leading: Icon(isFavorited ? Icons.favorite : Icons.favorite_border),
                title: Text(isFavorited ? "Remove from Favorites" : "Add to Favorites"),
                onTap: () {
                  Navigator.pop(context);
                  widget.onFavoriteChanged(itemKey, !isFavorited);
                },
              ),
              ListTile(
                leading: const Icon(Icons.swap_horiz_rounded),
                title: const Text("Move to Another Cloud"),
                onTap: () {
                  Navigator.pop(context);
                  _showMoveToCloudSheet(item);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text("Delete File", style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(context);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Confirm Delete'),
                      content: const Text('Are you sure you want to move this file to Bin?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Delete', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await widget.onMoveToBin(item);
                    _fetchAllDocs();
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
  void _showMoveToCloudSheet(DriveItem item) {
    if (!widget.isPro) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Cloud Transfer"),
          content: const Text("Moving files between clouds is a Pro feature. Upgrade to buy Pro!"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
          ],
        ),
      );
      return;
    }
    final List<PhotoSource> otherConnected = [];
    if (widget.oneDriveAccessToken != null && item.source != PhotoSource.oneDrive) otherConnected.add(PhotoSource.oneDrive);
    if (widget.dropboxAccessToken != null && item.source != PhotoSource.dropbox) otherConnected.add(PhotoSource.dropbox);
    if (widget.boxAccessToken != null && item.source != PhotoSource.box) otherConnected.add(PhotoSource.box);
    if (widget.pCloudAccessToken != null && item.source != PhotoSource.pCloud) otherConnected.add(PhotoSource.pCloud);
    if (otherConnected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No other cloud accounts connected.')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Move File to...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ...otherConnected.map((source) => ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getSourceColor(source).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_getSourceIcon(source), color: _getSourceColor(source), size: 20),
                ),
                title: Text(source.name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  if (widget.onTransferFile != null) {
                    widget.onTransferFile!(item, source).then((_) {
                      _fetchAllDocs();
                    });
                  }
                },
              )),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }
  IconData _getSourceIcon(PhotoSource source) {
    switch (source) {
      case PhotoSource.oneDrive: return Icons.cloud_outlined;
      case PhotoSource.dropbox: return Icons.storage_rounded;
      case PhotoSource.box: return Icons.archive_outlined;
      case PhotoSource.pCloud: return Icons.cloud_download_outlined;
      default: return Icons.cloud_queue;
    }
  }
  Color _getSourceColor(PhotoSource source) {
    switch (source) {
      case PhotoSource.oneDrive: return const Color(0xFF0078D4);
      case PhotoSource.dropbox: return const Color(0xFF0061FF);
      case PhotoSource.box: return const Color(0xFF0061D5);
      case PhotoSource.pCloud: return const Color(0xFF2ECC71);
      default: return Colors.grey;
    }
  }
}
class FolderBrowserScreen extends StatefulWidget {
  final PhotoSource source;
  final String folderId; 
  final String folderName;
  final String? oneDriveAccessToken;
  final String? dropboxAccessToken;
  final String? boxAccessToken;
  final String? pCloudAccessToken;
  final Future<bool> Function(PhotoSource source) onRefreshTokens;
  final Future<String?> Function(DriveItem item) getThumbnailUrl;
  final Future<String?> Function(DriveItem item) getDownloadUrl;
  final Set<String> favorites;
  final Set<String> bin;
  final void Function(String key, bool isFavorite) onFavoriteChanged;
  final Future<void> Function(DriveItem item) onMoveToBin;
  final Future<void> Function(List<String> keys) onShowAddToAlbumDialog;
  final bool useCaching;
  final User firebaseUser;
  const FolderBrowserScreen({
    super.key,
    required this.source,
    required this.folderId,
    required this.folderName,
    this.oneDriveAccessToken,
    this.dropboxAccessToken,
    this.boxAccessToken,
    this.pCloudAccessToken,
    required this.onRefreshTokens,
    required this.getThumbnailUrl,
    required this.getDownloadUrl,
    required this.favorites,
    required this.bin,
    required this.onFavoriteChanged,
    required this.onMoveToBin,
    required this.onShowAddToAlbumDialog,
    required this.useCaching,
    required this.firebaseUser,
  });
  @override
  State<FolderBrowserScreen> createState() => _FolderBrowserScreenState();
}
class _FolderBrowserScreenState extends State<FolderBrowserScreen> {
  List<DriveItem> _items = [];
  bool _isLoading = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _fetchContents();
  }
  Future<void> _fetchContents() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final List<DriveItem> results = await _fetchFromApi(widget.source, widget.folderId);
      if (mounted) {
        setState(() {
          _items = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Folder fetch error: $e");
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }
  Future<List<DriveItem>> _fetchFromApi(PhotoSource source, String folderId) async {
    String? token;
    Uri url;
    Map<String, String> headers = {};
    Object? body;
    String apiHost = 'api.pcloud.com';
    switch (source) {
      case PhotoSource.oneDrive:
        token = widget.oneDriveAccessToken;
        url = folderId == "0" || folderId == "root" 
            ? Uri.parse("https://graph.microsoft.com/v1.0/me/drive/root/children")
            : Uri.parse("https://graph.microsoft.com/v1.0/me/drive/items/$folderId/children");
        headers = {"Authorization": "Bearer $token"};
        break;
      case PhotoSource.dropbox:
        token = widget.dropboxAccessToken;
        url = Uri.parse("https://api.dropboxapi.com/2/files/list_folder");
        headers = {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json"
        };
        body = jsonEncode({"path": folderId, "recursive": false});
        break;
      case PhotoSource.box:
        token = widget.boxAccessToken;
        url = Uri.parse("https://api.box.com/2.0/folders/$folderId/items");
        headers = {"Authorization": "Bearer $token"};
        break;
      case PhotoSource.pCloud:
        token = widget.pCloudAccessToken;
        // Check for EU or US pCloud host
        String locationId = await secureStorage.read(key: '${widget.firebaseUser.uid}_pcloud_location_id') ?? '1';
        apiHost = (locationId == '2') ? 'eapi.pcloud.com' : 'api.pcloud.com';
        url = Uri.https(apiHost, '/listfolder', {
          'folderid': folderId,
          'showprogress': '0',
          'access_token': token ?? ''
        });
        break;
      default:
        throw Exception("Unsupported source");
    }
    http.Response response;
    // FIX: Use longer timeout for pCloud (recursive folder listing can be slow)
    final timeout = (source == PhotoSource.pCloud)
        ? const Duration(seconds: 60)
        : const Duration(seconds: 20);
    if (source == PhotoSource.dropbox) {
      response = await http.post(url, headers: headers, body: body).timeout(timeout);
    } else {
      response = await http.get(url, headers: headers).timeout(timeout);
    }
    // NOTE: pCloud does NOT return HTTP 401 for auth errors.
    // Auth errors come as result=1000/2000/2094 in a 200-body, handled in the switch above.
    if (response.statusCode == 401) {
      final refreshed = await widget.onRefreshTokens(source);
      if (refreshed) {
        return _fetchFromApi(source, folderId); // Retry once
      }
      throw Exception("Unauthorized. Please log in again.");
    }
    if (response.statusCode != 200) {
      throw Exception("Failed to load contents: ${response.statusCode}");
    }
    final data = jsonDecode(response.body);
    List<DriveItem> items = [];
    switch (source) {
      case PhotoSource.oneDrive:
        for (var entry in data['value']) {
          items.add(DriveItem(
            id: entry['id'],
            name: entry['name'],
            source: PhotoSource.oneDrive,
            isFolder: entry['folder'] != null,
            isVideo: entry['video'] != null,
            created: entry['fileSystemInfo']?['createdDateTime'] != null ? DateTime.parse(entry['fileSystemInfo']['createdDateTime']) : null,
            size: entry['size'],
          ));
        }
        break;
      case PhotoSource.dropbox:
        for (var entry in data['entries']) {
          items.add(DriveItem(
            id: entry['path_lower'], // Dropbox uses path for navigation
            name: entry['name'],
            source: PhotoSource.dropbox,
            isFolder: entry['.tag'] == 'folder',
            isVideo: entry['name'].toLowerCase().endsWith('.mp4'),
            created: entry['client_modified'] != null ? DateTime.parse(entry['client_modified']) : null,
            size: entry['size'],
          ));
        }
        break;
      case PhotoSource.box:
        for (var entry in data['entries']) {
          items.add(DriveItem(
            id: entry['id'],
            name: entry['name'],
            source: PhotoSource.box,
            isFolder: entry['type'] == 'folder',
            isVideo: entry['name'].toLowerCase().endsWith('.mp4'),
            size: entry['size'],
          ));
        }
        break;
      case PhotoSource.pCloud:
        var currentData = data;
        if (currentData['result'] == 2000) {
          // Wrong server region — auto-heal with fallback host
          final String fallbackHost = (apiHost == 'eapi.pcloud.com') ? 'api.pcloud.com' : 'eapi.pcloud.com';
          try {
            final fbUrl = Uri.https(fallbackHost, '/listfolder', {
              'folderid': folderId,
              'access_token': token ?? ''
            });
            final fbResponse = await http.get(fbUrl, headers: headers).timeout(const Duration(seconds: 20));
            if (fbResponse.statusCode == 200) {
              final fbData = jsonDecode(fbResponse.body);
              if (fbData['result'] == 0) {
                currentData = fbData;
                final correctLoc = fallbackHost.contains('eapi') ? '2' : '1';
                await secureStorage.write(key: '${widget.firebaseUser.uid}_pcloud_location_id', value: correctLoc);
              }
            }
          } catch (_) {}
        }
        final result = currentData['result'] as int? ?? -1;
        if (result == 1000 || result == 2094) {
          // Auth error — token is invalid. Throw so caller shows error UI.
          throw Exception('pCloud authentication error (result=$result). Please reconnect.');
        }
        final metadata = currentData['metadata'] as Map<String, dynamic>?;
        final contents = metadata?['contents'] as List<dynamic>?;
        if (contents != null) {
          for (var entry in contents) {
            final rawSize = entry['size'];
            final int? size = rawSize is int ? rawSize : int.tryParse(rawSize?.toString() ?? '');
            items.add(DriveItem(
              id: entry['folderid']?.toString() ?? entry['fileid']?.toString() ?? '',
              name: entry['name'] ?? 'Unnamed',
              source: PhotoSource.pCloud,
              isFolder: entry['isfolder'] == true,
              isVideo: (entry['name'] ?? '').toString().toLowerCase().endsWith('.mp4') ||
                       (entry['contenttype'] ?? '').toString().startsWith('video/'),
              created: _parsePCloudDate(entry['modified']) ?? _parsePCloudDate(entry['created']),
              size: size,
            ));
          }
        }
        break;
      default:
        break;
    }
    return items;
  }
  Future<void> _openDocument(DriveItem item) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text("Downloading file..."),
              ],
            ),
          ),
        ),
      ),
    );
    try {
      final downloadUrl = await widget.getDownloadUrl(item);
      if (downloadUrl == null) throw Exception("Could not get download URL");
      final response = await http.get(Uri.parse(downloadUrl))
          .timeout(const Duration(seconds: 60));
      if (response.statusCode != 200) throw Exception("Download failed");
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/${item.name}');
      await file.writeAsBytes(response.bodyBytes);
      if (mounted) Navigator.pop(context); // Close loading dialog
      await OpenFile.open(file.path);
    } catch (e) {
      if (mounted) Navigator.pop(context); // Close loading dialog
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error opening file: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(widget.folderName),
        elevation: 0,
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text("Error: $_error", style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: _fetchContents, child: const Text("Retry"))
                  ],
                ))
              : _items.isEmpty
                  ? Center(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.folder_open_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text("This folder is empty", style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                      ],
                    ))
                  : ListView.builder(
                      itemCount: _items.length,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return ListTile(
                          leading: Icon(
                            item.isFolder ? Icons.folder : (item.isVideo ? Icons.videocam : Icons.image),
                            color: item.isFolder ? Colors.amber : Colors.blue,
                          ),
                          title: Text(item.name),
                          trailing: const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                          onTap: () {
                            if (item.isFolder) {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => FolderBrowserScreen(
                                source: widget.source,
                                folderId: item.id,
                                folderName: item.name,
                                oneDriveAccessToken: widget.oneDriveAccessToken,
                                dropboxAccessToken: widget.dropboxAccessToken,
                                boxAccessToken: widget.boxAccessToken,
                                pCloudAccessToken: widget.pCloudAccessToken,
                                onRefreshTokens: widget.onRefreshTokens,
                                getThumbnailUrl: widget.getThumbnailUrl,
                                getDownloadUrl: widget.getDownloadUrl,
                                favorites: widget.favorites,
                                bin: widget.bin,
                                onFavoriteChanged: widget.onFavoriteChanged,
                                onMoveToBin: widget.onMoveToBin,
                                onShowAddToAlbumDialog: widget.onShowAddToAlbumDialog,
                                useCaching: widget.useCaching,
                                firebaseUser: widget.firebaseUser,
                              )));
                            } else {
                              // Check if it's an image or video
                              final name = item.name.toLowerCase();
                              bool isImage = name.endsWith('.jpg') || 
                                             name.endsWith('.jpeg') || 
                                             name.endsWith('.png') || 
                                             name.endsWith('.gif') || 
                                             name.endsWith('.webp') || 
                                             name.endsWith('.heic');
                              if (isImage || item.isVideo) {
                                // Open in PhotoViewer
                                final mediaItems = _items.where((i) {
                                  if (i.isFolder) return false;
                                  final n = i.name.toLowerCase();
                                  return n.endsWith('.jpg') || 
                                         n.endsWith('.jpeg') || 
                                         n.endsWith('.png') || 
                                         n.endsWith('.gif') || 
                                         n.endsWith('.webp') || 
                                         n.endsWith('.heic') || 
                                         i.isVideo;
                                }).toList();
                                final initialIndex = mediaItems.indexOf(item);
                                Navigator.push(context, MaterialPageRoute(builder: (context) => PhotoViewerPage(
                                  items: mediaItems,
                                  initialIndex: initialIndex,
                                  getDownloadUrl: widget.getDownloadUrl,
                                  getThumbnailUrl: widget.getThumbnailUrl,
                                  favorites: widget.favorites,
                                  bin: widget.bin,
                                  onFavoriteChanged: widget.onFavoriteChanged,
                                  onMoveToBin: widget.onMoveToBin,
                                  onAddToAlbum: (item) => widget.onShowAddToAlbumDialog([item.getUniqueKey()]),
                                  oneDriveAccessToken: widget.oneDriveAccessToken,
                                  dropboxAccessToken: widget.dropboxAccessToken,
                                  boxAccessToken: widget.boxAccessToken,
                                  useCaching: widget.useCaching,
                                )));
                              } else {
                                // Treat as Document
                                _openDocument(item);
                              }
                            }
                          },
                        );
                      },
                    ),
    );
  }
}
class DuplicateFinderPage extends StatefulWidget {
  final List<DriveItem> items;
  final Future<void> Function(DriveItem item) onDelete;
  final VoidCallback onRefresh;
  const DuplicateFinderPage({
    super.key,
    required this.items,
    required this.onDelete,
    required this.onRefresh,
  });
  @override
  State<DuplicateFinderPage> createState() => _DuplicateFinderPageState();
}
class _DuplicateFinderPageState extends State<DuplicateFinderPage> {
  Map<String, List<DriveItem>> _duplicates = {};
  @override
  void initState() {
    super.initState();
    _findDuplicates();
  }
  void _findDuplicates() {
    final groups = <String, List<DriveItem>>{};
    for (var item in widget.items) {
      if (item.isFolder) continue;
      final key = '${item.name.toLowerCase()}_${item.size ?? 0}';
      groups.putIfAbsent(key, () => []).add(item);
    }
    groups.removeWhere((key, list) => list.length < 2);
    setState(() {
      _duplicates = groups;
    });
  }
  Future<void> _cleanupGroup(List<DriveItem> group) async {
    final toDelete = group.sublist(1);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text("Deleting duplicates..."),
              ],
            ),
          ),
        ),
      ),
    );
    try {
      for (var item in toDelete) {
        await widget.onDelete(item);
      }
      if (mounted) Navigator.pop(context); // Close loading dialog
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Cleaned up ${toDelete.length} duplicate(s).")),
        );
      }
    } catch (e) {
       if (mounted) Navigator.pop(context);
       debugPrint("Cleanup error: $e");
    }
    widget.onRefresh();
    _findDuplicates(); // Refresh local groups
  }
  @override
  Widget build(BuildContext context) {
    final groupKeys = _duplicates.keys.toList();
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Duplicate Finder"),
        elevation: 0,
        centerTitle: true,
      ),
      body: _duplicates.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Icon(Icons.check_circle_outline, size: 64, color: Colors.green.shade300),
                   const SizedBox(height: 16),
                   const Text("No duplicates found!", style: TextStyle(fontSize: 18, color: Colors.black54)),
                   const SizedBox(height: 8),
                   const Text("Your cloud storage is clean.", style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: groupKeys.length,
              itemBuilder: (context, index) {
                final key = groupKeys[index];
                final group = _duplicates[key]!;
                final firstItem = group.first;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.file_copy_rounded, color: Colors.blue, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    firstItem.name, 
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    "${group.length} occurrences • ${_formatSize(firstItem.size)}", 
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Divider(height: 1),
                        ),
                        ...group.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Icon(_getSourceIcon(item.source), size: 16, color: _getSourceColor(item.source)),
                              const SizedBox(width: 8),
                              Text(item.source.name.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              const Spacer(),
                              Text("ID: ...${item.id.substring(item.id.length > 8 ? item.id.length - 8 : 0)}", style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontFamily: 'monospace')),
                            ],
                          ),
                        )),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => _cleanupGroup(group),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                            child: const Text("Keep One & Delete Rest"),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
  String _formatSize(int? bytes) {
    if (bytes == null || bytes == 0) return "Unknown size";
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
    return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
  }
  IconData _getSourceIcon(PhotoSource source) {
    switch (source) {
      case PhotoSource.oneDrive: return Icons.cloud_outlined;
      case PhotoSource.dropbox: return Icons.storage_outlined; 
      case PhotoSource.box: return Icons.archive_outlined;
      case PhotoSource.pCloud: return Icons.cloud_download_outlined;
      default: return Icons.cloud_queue;
    }
  }
  Color _getSourceColor(PhotoSource source) {
    switch (source) {
      case PhotoSource.oneDrive: return const Color(0xFF0078D4);
      case PhotoSource.dropbox: return const Color(0xFF0061FF);
      case PhotoSource.box: return const Color(0xFF0061D5);
      case PhotoSource.pCloud: return const Color(0xFF2ECC71);
      default: return Colors.grey;
    }
  }
}
// =============================================================================
// --- CloudHubPage: Cross-Cloud Insights & Management ---
// =============================================================================
/// Storage quota data fetched from each cloud provider's API.
class _StorageQuota {
  final int usedBytes;
  final int totalBytes;
  const _StorageQuota({required this.usedBytes, required this.totalBytes});
  double get usedFraction =>
      totalBytes > 0 ? (usedBytes / totalBytes).clamp(0.0, 1.0) : 0.0;
  String get usedLabel => _formatBytes(usedBytes);
  String get totalLabel => _formatBytes(totalBytes);
  static String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
class CloudHubPage extends StatefulWidget {
  final List<DriveItem> driveItems;
  final Set<String> bin;
  final Set<String> favorites;
  final Map<String, List<String>> albums;
  final bool oneDriveConnected;
  final bool dropboxConnected;
  final bool boxConnected;
  final bool pCloudConnected;
  final bool megaConnected;
  final bool isPro;
  // Access tokens for storage quota API calls
  final String? oneDriveAccessToken;
  final String? dropboxAccessToken;
  final String? boxAccessToken;
  final String? pCloudAccessToken;
  // AI scan progress — passed from parent so Cloud Hub reflects live state
  final bool isAiScanning;
  final int aiScanProgress;
  final int aiScanTotal;
  final String aiScanStatus;
  // Smart Migration callbacks
  final UploadCallback onUpload;
  final DeleteCallback onDelete;
  final DownloadUrlCallback onGetDownloadUrl;
  const CloudHubPage({
    super.key,
    required this.driveItems,
    required this.bin,
    required this.favorites,
    required this.albums,
    required this.oneDriveConnected,
    required this.dropboxConnected,
    required this.boxConnected,
    required this.pCloudConnected,
    required this.megaConnected,
    required this.isPro,
    this.oneDriveAccessToken,
    this.dropboxAccessToken,
    this.boxAccessToken,
    this.pCloudAccessToken,
    this.isAiScanning = false,
    this.aiScanProgress = 0,
    this.aiScanTotal = 0,
    this.aiScanStatus = '',
    required this.onUpload,
    required this.onDelete,
    required this.onGetDownloadUrl,
  });
  @override
  State<CloudHubPage> createState() => _CloudHubPageState();
}
class _CloudHubPageState extends State<CloudHubPage>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  // DB cache statistics state
  int _dbTotalItems = 0;
  Map<int, int> _dbSourceCounts = {};
  bool _isLoadingDbCounts = true;
  // Photo indexing statistics
  int _indexedCount = 0;
  int _pendingCount = 0;
  int _dedupCount = 0;
  // Storage quota state — keyed by service name
  final Map<String, _StorageQuota> _storageQuotas = {};
  bool _isLoadingQuotas = true;
  Future<bool> _checkDestinationSpace(PhotoSource dest, int requiredBytes) async {
    final quota = _storageQuotas[dest.name];
    if (quota == null) return true; // Assume enough space if API didn't return quota
    final freeSpace = quota.totalBytes - quota.usedBytes;
    return freeSpace >= requiredBytes;
  }
  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
    _loadDbStatistics();
    _fetchStorageQuotas();
  }
  Future<void> _loadDbStatistics() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        final total = await assetRepository.count(userId);
        final counts = await assetRepository.countBySource(userId);
        final indexed = await assetRepository.countByAiStatus(userId, AiScanStatus.done);
        final pending = await assetRepository.countByAiStatus(userId, AiScanStatus.pending);
        final dedup = await assetRepository.countByPHashNotNull(userId);
        if (mounted) {
          setState(() {
            _dbTotalItems = total;
            _dbSourceCounts = counts;
            _isLoadingDbCounts = false;
            _indexedCount = indexed;
            _pendingCount = pending;
            _dedupCount = dedup;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading db statistics in Cloud Hub: $e');
      if (mounted) setState(() => _isLoadingDbCounts = false);
    }
  }
  /// Fetches storage quota from each connected cloud provider.
  /// Uses the same access tokens that are already in memory — no new auth needed.
  Future<void> _fetchStorageQuotas() async {
    final futures = <Future<void>>[];
    // ── ── OneDrive: GET /me/drive → quota.used / quota.total ────
    if (widget.oneDriveConnected && widget.oneDriveAccessToken != null) {
      futures.add(_fetchOneDriveQuota());
    }
    // ── ── Dropbox: POST /users/get_space_usage ────
    if (widget.dropboxConnected && widget.dropboxAccessToken != null) {
      futures.add(_fetchDropboxQuota());
    }
    // ── ── Box: GET /users/me → space_used / space_amount ────
    if (widget.boxConnected && widget.boxAccessToken != null) {
      futures.add(_fetchBoxQuota());
    }
    // ── ── pCloud: GET /userinfo → usedquota / quota ────
    if (widget.pCloudConnected && widget.pCloudAccessToken != null) {
      futures.add(_fetchPCloudQuota());
    }
    await Future.wait(futures);
    if (mounted) setState(() => _isLoadingQuotas = false);
  }
  Future<void> _fetchOneDriveQuota() async {
    try {
      final response = await http.get(
        Uri.parse('https://graph.microsoft.com/v1.0/me/drive'),
        headers: {'Authorization': 'Bearer ${widget.oneDriveAccessToken}'},
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final quota = data['quota'] as Map<String, dynamic>?;
        if (quota != null) {
          final used = (quota['used'] as num?)?.toInt() ?? 0;
          final total = (quota['total'] as num?)?.toInt() ?? 0;
          if (mounted) {
            setState(() {
              _storageQuotas['OneDrive'] =
                  _StorageQuota(usedBytes: used, totalBytes: total);
            });
          }
        }
      }
    } catch (e) {
      debugPrint('OneDrive quota fetch error: $e');
    }
  }
  Future<void> _fetchDropboxQuota() async {
    try {
      final response = await http.post(
        Uri.parse('https://api.dropboxapi.com/2/users/get_space_usage'),
        headers: {
          'Authorization': 'Bearer ${widget.dropboxAccessToken}',
          'Content-Type': 'application/json',
        },
        body: 'null',
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final used = (data['used'] as num?)?.toInt() ?? 0;
        final allocation =
            data['allocation'] as Map<String, dynamic>?;
        final total = (allocation?['allocated'] as num?)?.toInt() ?? 0;
        if (mounted) {
          setState(() {
            _storageQuotas['Dropbox'] =
                _StorageQuota(usedBytes: used, totalBytes: total);
          });
        }
      }
    } catch (e) {
      debugPrint('Dropbox quota fetch error: $e');
    }
  }
  Future<void> _fetchBoxQuota() async {
    try {
      final response = await http.get(
        Uri.parse('https://api.box.com/2.0/users/me'),
        headers: {'Authorization': 'Bearer ${widget.boxAccessToken}'},
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final used = (data['space_used'] as num?)?.toInt() ?? 0;
        final total = (data['space_amount'] as num?)?.toInt() ?? 0;
        if (mounted) {
          setState(() {
            _storageQuotas['Box'] =
                _StorageQuota(usedBytes: used, totalBytes: total);
          });
        }
      }
    } catch (e) {
      debugPrint('Box quota fetch error: $e');
    }
  }
  Future<void> _fetchPCloudQuota() async {
    try {
      final token = widget.pCloudAccessToken!;
      // FIX: Respect EU/US region — EU users must hit eapi.pcloud.com
      // CloudHubPage has no firebaseUser field; use FirebaseAuth directly (same as _loadDbStatistics)
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final storedLoc = await secureStorage.read(key: '${uid}_pcloud_location_id');
      final primaryHost = (storedLoc == '2') ? 'eapi.pcloud.com' : 'api.pcloud.com';
      final fallbackHost = (storedLoc == '2') ? 'api.pcloud.com' : 'eapi.pcloud.com';

      Future<Map<String, dynamic>?> probe(String host) async {
        try {
          final resp = await http.get(
            Uri.https(host, '/userinfo', {'access_token': token}),
          ).timeout(const Duration(seconds: 10));
          if (resp.statusCode == 200) {
            final data = json.decode(resp.body) as Map<String, dynamic>;
            if ((data['result'] as int? ?? -1) == 0) return data;
          }
        } catch (_) {}
        return null;
      }

      final data = await probe(primaryHost) ?? await probe(fallbackHost);
      if (data != null && mounted) {
        final used = (data['usedquota'] as num?)?.toInt() ?? 0;
        final total = (data['quota'] as num?)?.toInt() ?? 0;
        setState(() {
          _storageQuotas['pCloud'] = _StorageQuota(usedBytes: used, totalBytes: total);
        });
      }
    } catch (e) {
      debugPrint('pCloud quota fetch error: $e');
    }
  }
  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }
  int get _totalItems {
    int sum = 0;
    if (widget.oneDriveConnected) sum += _itemsForSource(PhotoSource.oneDrive);
    if (widget.dropboxConnected) sum += _itemsForSource(PhotoSource.dropbox);
    if (widget.boxConnected) sum += _itemsForSource(PhotoSource.box);
    if (widget.pCloudConnected) sum += _itemsForSource(PhotoSource.pCloud);
    if (widget.megaConnected) sum += _itemsForSource(PhotoSource.mega);
    return sum;
  }
  int get _binCount => widget.bin.length;
  int get _favCount => widget.favorites.length;
  int get _albumCount => widget.albums.length;
  int _itemsForSource(PhotoSource src) => _isLoadingDbCounts
      ? widget.driveItems
          .where((i) =>
              i.source == src && !widget.bin.contains(i.getUniqueKey()))
          .length
      : (_dbSourceCounts[src.index] ?? 0);
  int get _connectedCount => [
        widget.oneDriveConnected,
        widget.dropboxConnected,
        widget.boxConnected,
        widget.pCloudConnected,
        widget.megaConnected,
      ].where((c) => c).length;
  /// Total bytes used across all connected services with known quotas
  int get _totalUsedBytes =>
      _storageQuotas.values.fold(0, (sum, q) => sum + q.usedBytes);
  /// Total bytes available across all connected services with known quotas
  int get _totalStorageBytes =>
      _storageQuotas.values.fold(0, (sum, q) => sum + q.totalBytes);
  List<_CloudService> get _services => [
        _CloudService(
            name: 'OneDrive',
            icon: Icons.cloud_queue,
            color: const Color(0xFF0078D4),
            isConnected: widget.oneDriveConnected,
            itemCount: _itemsForSource(PhotoSource.oneDrive)),
        _CloudService(
            name: 'Dropbox',
            icon: Icons.storage_rounded,
            color: const Color(0xFF0061FF),
            isConnected: widget.dropboxConnected,
            itemCount: _itemsForSource(PhotoSource.dropbox)),
        _CloudService(
            name: 'Box',
            icon: Icons.archive_outlined,
            color: const Color(0xFF0061D5),
            isConnected: widget.boxConnected,
            itemCount: _itemsForSource(PhotoSource.box)),
        _CloudService(
            name: 'pCloud',
            icon: Icons.cloud_download_outlined,
            color: const Color(0xFF2ECC71),
            isConnected: widget.pCloudConnected,
            itemCount: _itemsForSource(PhotoSource.pCloud)),
      ];
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF121212) : const Color(0xFFF5F7FA);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final textSecondary = isDark ? Colors.white60 : Colors.black54;
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textPrimary),
        title: Text('Cloud Hub',
            style: TextStyle(
                color: textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 22)),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            // ─── Cloud Insight ───
            _buildSectionTitle('Cloud Insight', Icons.insights_rounded, textPrimary),
            const SizedBox(height: 10),
            _buildCloudInsightGrid(cardColor, textPrimary, textSecondary),
            const SizedBox(height: 20),
            // ─── Files ───
            _buildFilesCard(cardColor, textPrimary, textSecondary),
            const SizedBox(height: 12),
            // ─── Cloud Transfer ───
            _buildMigrationLauncherCard(cardColor, textPrimary, textSecondary),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
  /// Quick-access card to open cloud Files from Cloud Hub.
  Widget _buildFilesCard(Color cardColor, Color textPrimary, Color textSecondary) {
    return Card(
      color: cardColor,
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) return;
          Navigator.push(context, MaterialPageRoute(
            builder: (context) => UnifiedDocsPage(
              oneDriveAccessToken: widget.oneDriveAccessToken,
              dropboxAccessToken: widget.dropboxAccessToken,
              boxAccessToken: widget.boxAccessToken,
              pCloudAccessToken: widget.pCloudAccessToken,
              firebaseUser: user,
              onRefreshTokens: (_) async => false,
              getThumbnailUrl: (_) async => null,
              getDownloadUrl: (_) async => null,
              favorites: widget.favorites,
              bin: widget.bin,
              onFavoriteChanged: (_, __) {},
              onMoveToBin: (_) async {},
              onShowAddToAlbumDialog: (_) async {},
              useCaching: true,
              isPro: widget.isPro,
            ),
          ));
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0288D1).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.folder_outlined, color: Color(0xFF0288D1), size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Files',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary)),
                    const SizedBox(height: 4),
                    Text('Browse cloud documents & files',
                        style: TextStyle(fontSize: 12, color: textSecondary)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildMigrationLauncherCard(Color cardColor, Color textPrimary, Color textSecondary) {
    return Card(
      color: cardColor,
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(
            builder: (context) => SmartMigrationPage(
              allItems: widget.driveItems,
              onUpload: widget.onUpload,
              onDelete: widget.onDelete,
              onGetDownloadUrl: widget.onGetDownloadUrl,
              onCheckSpace: _checkDestinationSpace,
              storageQuotas: {
                for (final e in _storageQuotas.entries)
                  e.key: CloudStorageQuota(
                    usedBytes: e.value.usedBytes,
                    totalBytes: e.value.totalBytes,
                  ),
              },
            )
          ));
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.swap_horiz_rounded, color: Colors.blue, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cloud Transfer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary)),
                    const SizedBox(height: 4),
                    Text('Batch transfer photos between clouds', style: TextStyle(fontSize: 12, color: textSecondary)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildSectionTitle(
      String title, IconData icon, Color textColor) {
    return Row(
      children: [
        Icon(icon, size: 18, color: textColor.withOpacity(0.7)),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textColor)),
      ],
    );
  }
  /// Builds the Photo Index Status card that shows how many photos have been
  /// AI-scanned and indexed in the local CloudHub database.
  Widget _buildPhotoIndexCard(
      Color cardColor, Color textPrimary, Color textSecondary) {
    final isScanning = widget.isAiScanning;
    final progress = widget.aiScanProgress;
    final total = widget.aiScanTotal;
    final status = widget.aiScanStatus;
    // Use live scan progress if scanning, otherwise use DB counts
    final displayIndexed = isScanning ? (_indexedCount + progress) : _indexedCount;
    final displayTotal = _isLoadingDbCounts
        ? (isScanning ? total : 0)
        : _dbTotalItems;
    final indexFraction = displayTotal > 0
        ? (displayIndexed / displayTotal).clamp(0.0, 1.0)
        : (_indexedCount > 0 ? 1.0 : 0.0);
    final indexColor = const Color(0xFF7C3AED); // violet
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: indexColor.withOpacity(0.10),
            blurRadius: 16,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ──
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: indexColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.image_search_rounded,
                    color: indexColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Photo Index',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: textPrimary)),
                    Text(
                      isScanning
                          ? status.isNotEmpty
                              ? status
                              : 'Scanning in background”¦'
                          : _pendingCount > 0
                              ? '$_pendingCount photos pending scan'
                              : 'All photos indexed',
                      style: TextStyle(
                          fontSize: 11,
                          color: isScanning
                              ? indexColor
                              : textSecondary),
                    ),
                  ],
                ),
              ),
              // Animated spinner when scanning
              if (isScanning)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: indexColor,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // ── Stats row ──
          Row(
            children: [
              _buildIndexStat(
                label: 'Indexed',
                value: _isLoadingDbCounts
                    ? '—'
                    : '$_indexedCount',
                icon: Icons.check_circle_rounded,
                color: const Color(0xFF059669),
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
              const SizedBox(width: 24),
              _buildIndexStat(
                label: 'Pending',
                value: _isLoadingDbCounts
                    ? '—'
                    : isScanning
                        ? '${(total - progress).clamp(0, total)}'
                        : '$_pendingCount',
                icon: Icons.schedule_rounded,
                color: const Color(0xFFF59E0B),
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
              const Spacer(),
              // Percentage badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: indexColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${(indexFraction * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: indexColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // ── Progress bar ──
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: indexFraction,
                  backgroundColor: indexColor.withOpacity(0.08),
                  valueColor:
                      AlwaysStoppedAnimation<Color>(indexColor),
                  minHeight: 8,
                ),
              ),
              // Shimmer overlay while scanning
              if (isScanning)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.white.withOpacity(0.25),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ).createShader(bounds),
                      blendMode: BlendMode.srcOver,
                      child: Container(
                        height: 8,
                        color: Colors.white.withOpacity(0.0),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _isLoadingDbCounts
                ? 'Loading index data”¦'
                : isScanning
                    ? 'Indexing $progress of $total photos”¦'
                    : '$_indexedCount of ${_dbTotalItems > 0 ? _dbTotalItems : _indexedCount + _pendingCount} photos indexed',
            style: TextStyle(fontSize: 11, color: textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            _isLoadingDbCounts
                ? 'Loading duplicates data”¦'
                : '$_dedupCount of ${_dbTotalItems > 0 ? _dbTotalItems : _indexedCount + _pendingCount} scanned for duplicates',
            style: TextStyle(fontSize: 11, color: textSecondary),
          ),
        ],
      ),
    );
  }
  Widget _buildIndexStat({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textPrimary)),
            Text(label,
                style:
                    TextStyle(fontSize: 10, color: textSecondary)),
          ],
        ),
      ],
    );
  }
  Widget _buildOverviewCard(Color textPrimary, Color textSecondary) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasQuota = _storageQuotas.isNotEmpty;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06);
    final quotaBg = isDark ? const Color(0xFF282828) : const Color(0xFFF2F4F7);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your Cloud Overview',
              style: TextStyle(
                  color: textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3)),
          const SizedBox(height: 6),
          Text('$_totalItems Files',
              style: TextStyle(
                  color: textPrimary,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  height: 1.1)),
          const SizedBox(height: 4),
          Text(
              'Across $_connectedCount connected cloud${_connectedCount == 1 ? '' : 's'}',
              style: TextStyle(color: textSecondary, fontSize: 13)),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildHeaderStat(
                  Icons.favorite_rounded, '$_favCount', 'Favorites', textPrimary, textSecondary),
              const SizedBox(width: 20),
              _buildHeaderStat(
                  Icons.photo_album_outlined, '$_albumCount', 'Albums', textPrimary, textSecondary),
              const SizedBox(width: 20),
              _buildHeaderStat(
                  Icons.delete_outline_rounded, '$_binCount', 'In Bin', textPrimary, textSecondary),
            ],
          ),
          // ──── Cloud Storage Total Bar ────
          if (hasQuota) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: quotaBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        Icon(Icons.cloud_done_outlined,
                            size: 15, color: const Color(0xFF1565C0)),
                        const SizedBox(width: 6),
                        Text('Total Cloud Storage',
                            style: TextStyle(
                                color: textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
                      ]),
                      Text(
                        _isLoadingQuotas
                            ? 'Loading...'
                            : '${_StorageQuota._formatBytes(_totalUsedBytes)} / ${_StorageQuota._formatBytes(_totalStorageBytes)}',
                        style: TextStyle(
                            color: textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _totalStorageBytes > 0
                          ? (_totalUsedBytes / _totalStorageBytes)
                              .clamp(0.0, 1.0)
                          : 0.0,
                      backgroundColor: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF1565C0)),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
  Widget _buildHeaderStat(
      IconData icon, String value, String label, Color textPrimary, Color textSecondary) {
    return Row(
      children: [
        Icon(icon, color: textSecondary, size: 16),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: TextStyle(
                    color: textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold)),
            Text(label,
                style: TextStyle(
                    color: textSecondary, fontSize: 11)),
          ],
        ),
      ],
    );
  }
  Widget _buildCloudInsightGrid(
      Color cardColor, Color textPrimary, Color textSecondary) {
    final connected =
        _services.where((s) => s.isConnected).toList();
    if (connected.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Icon(Icons.cloud_off_outlined,
                color: Colors.grey[400], size: 32),
            const SizedBox(width: 12),
            Expanded(
                child: Text(
                    'No cloud services connected yet. Connect one from the drawer.',
                    style: TextStyle(
                        color: textSecondary, fontSize: 13))),
          ],
        ),
      );
    }
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.35,
      children: connected
          .map((s) => _buildServiceCard(
              s, cardColor, textPrimary, textSecondary))
          .toList(),
    );
  }
  Widget _buildServiceCard(_CloudService service, Color cardColor,
      Color textPrimary, Color textSecondary) {
    final totalConnected = _services
        .where((s) => s.isConnected)
        .map((s) => s.itemCount)
        .fold(0, (a, b) => a + b);
    final filePct = totalConnected > 0
        ? (service.itemCount / totalConnected).clamp(0.0, 1.0)
        : 0.0;
    final quota = _storageQuotas[service.name];
    final hasQuota = quota != null && quota.totalBytes > 0;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: service.color.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // ── ── header row ────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: service.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(service.icon,
                    color: service.color, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(service.name,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textPrimary),
                      overflow: TextOverflow.ellipsis)),
            ],
          ),
          // ── ── file count + share bar ────
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${service.itemCount} files',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: textPrimary)),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: filePct,
                  backgroundColor:
                      service.color.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(
                      service.color),
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                  '${(filePct * 100).toStringAsFixed(0)}% of cloud library',
                  style: TextStyle(
                      fontSize: 10, color: textSecondary)),
            ],
          ),
          // ── ── storage quota section ────
          if (_isLoadingQuotas && service.name != 'Mega')
            Row(
              children: [
                SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: service.color,
                  ),
                ),
                const SizedBox(width: 6),
                Text('Fetching storage...',
                    style: TextStyle(
                        fontSize: 9,
                        color: textSecondary.withOpacity(0.7))),
              ],
            )
          else if (hasQuota) ...[
            const SizedBox(height: 2),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: quota.usedFraction,
                backgroundColor: service.color.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(
                    service.color.withOpacity(0.7)),
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${quota.usedLabel} used',
                  style: TextStyle(fontSize: 9, color: textSecondary),
                ),
                Text(
                  quota.totalLabel,
                  style: TextStyle(
                      fontSize: 9,
                      color: textPrimary.withOpacity(0.6),
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
class _CloudService {
  final String name;
  final IconData icon;
  final Color color;
  final bool isConnected;
  final int itemCount;
  const _CloudService(
      {required this.name,
      required this.icon,
      required this.color,
      required this.isConnected,
      required this.itemCount});
}
