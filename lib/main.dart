import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async';
import 'dart:math';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/intro_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/home_screen.dart';
import 'screens/details_screen.dart';
import 'screens/comments_screen.dart';
import 'screens/genre_movies_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/report_screen.dart';
import 'screens/notification_screen.dart';
import 'models/movie.dart';
import 'services/tmdb_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    print("Warning: .env file not found");
  }

  // Load genres trong background, không block UI
  TmdbService.initGenres();

  final authProvider = AuthProvider();
  await authProvider.loadSession();

  final themeProvider = ThemeProvider();
  await themeProvider.loadTheme();

  runApp(MyApp(authProvider: authProvider, themeProvider: themeProvider));
}

class MyApp extends StatelessWidget {
  final AuthProvider authProvider;
  final ThemeProvider themeProvider;

  const MyApp({super.key, required this.authProvider, required this.themeProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider.value(value: themeProvider),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          const pageTransitions = PageTransitionsTheme(
            builders: {
              TargetPlatform.android: CupertinoPageTransitionsBuilder(),
              TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
              TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
            },
          );

          final darkTheme = ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: Colors.black,
            pageTransitionsTheme: pageTransitions,
            useMaterial3: true,
            cardColor: const Color(0xFF1A1A1A),
            dividerColor: Colors.white12,
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF1A1A1A),
              iconTheme: IconThemeData(color: Colors.white),
              titleTextStyle: TextStyle(color: Colors.white, fontSize: 20),
            ),
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF87CEEB),
              brightness: Brightness.dark,
              secondary: const Color(0xFFFF6B00),
            ),
          );

          final lightTheme = ThemeData(
            brightness: Brightness.light,
            scaffoldBackgroundColor: const Color(0xFFF5F5F5),
            pageTransitionsTheme: pageTransitions,
            cardColor: Colors.white,
            dividerColor: Colors.black12,
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF1B263B),
              iconTheme: IconThemeData(color: Colors.white),
              titleTextStyle: TextStyle(color: Colors.white, fontSize: 20),
            ),
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF1976D2),
              brightness: Brightness.light,
              secondary: const Color(0xFFFF6B00),
            ),
          );

          SystemChrome.setSystemUIOverlayStyle(
            themeProvider.isDarkMode
                ? const SystemUiOverlayStyle(
                    statusBarColor: Colors.transparent,
                    statusBarIconBrightness: Brightness.light,
                  )
                : const SystemUiOverlayStyle(
                    statusBarColor: Colors.transparent,
                    statusBarIconBrightness: Brightness.dark,
                  ),
          );

          return MaterialApp(
            navigatorKey: navigatorKey,
            builder: (context, child) => GlobalShakeHandler(navigatorKey: navigatorKey, child: child!),
            title: 'Flickr App',
            debugShowCheckedModeBanner: false,
            theme: lightTheme,
            darkTheme: darkTheme,
            themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            initialRoute: authProvider.isLoggedIn ? '/home' : '/',
            onGenerateRoute: (settings) {
              Widget page;

              if (settings.name == '/details') {
                final movie = settings.arguments as Movie;
                page = DetailsScreen(movie: movie);
              } else if (settings.name == '/comments') {
                final Movie movie;
                if (settings.arguments is Movie) {
                  movie = settings.arguments as Movie;
                } else if (settings.arguments is Map<String, dynamic>) {
                  final args = settings.arguments as Map<String, dynamic>;
                  movie = Movie(
                    id: args['movieId'] as int,
                    title: args['movieTitle'] as String? ?? '',
                    overview: '',
                    posterPath: args['posterPath'] as String? ?? '',
                    backdropPath: '',
                    voteAverage: 0,
                    releaseDate: '',
                    genreIds: [],
                  );
                } else {
                  return null;
                }
                page = CommentsScreen(movie: movie);
              } else if (settings.name == '/genreMovies') {
                final args = settings.arguments as Map<String, dynamic>;
                page = GenreMoviesScreen(
                  genreId: args['genreId'] as int,
                  genreName: args['genreName'] as String,
                );
              } else if (settings.name == '/settings') {
                page = const SettingsScreen();
              } else if (settings.name == '/reports') {
                page = const ReportScreen();
              } else if (settings.name == '/notifications') {
                page = const NotificationScreen();
              } else {
                switch (settings.name) {
                  case '/':
                    page = const IntroScreen();
                    break;
                  case '/login':
                    page = const LoginScreen();
                    break;
                  case '/signup':
                    page = const SignupScreen();
                    break;
                  case '/home':
                    page = const HomeScreen();
                    break;
                  default:
                    return null;
                }
              }

              return MaterialPageRoute(
                settings: settings,
                builder: (_) => page,
              );
            },
          );
        },
      ),
    );
  }
}

class GlobalShakeHandler extends StatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;
  const GlobalShakeHandler({super.key, required this.navigatorKey, required this.child});

  @override
  State<GlobalShakeHandler> createState() => _GlobalShakeHandlerState();
}

class _GlobalShakeHandlerState extends State<GlobalShakeHandler>
    with WidgetsBindingObserver {
  StreamSubscription? _accelerometerSubscription;
  int _shakeCount = 0;
  DateTime _shakeWindowStart = DateTime.now();
  bool _showOverlay = false;

  @override
  void initState() {
    super.initState();
    _initShakeDetection();
  }

  void _initShakeDetection() {
    _accelerometerSubscription = accelerometerEventStream().listen((event) {
      final magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      if (magnitude > 25) {
        final now = DateTime.now();
        if (now.difference(_shakeWindowStart).inMilliseconds > 2000) {
          _shakeCount = 1;
          _shakeWindowStart = now;
        } else {
          _shakeCount++;
          if (_shakeCount >= 3) {
            _shakeCount = 0;
            _onShakeDetected();
          }
        }
      }
    });
  }

  Future<void> _onShakeDetected() async {
    if (_showOverlay) return;
    setState(() => _showOverlay = true);

    await Future.delayed(const Duration(seconds: 2));

    try {
      final movie = await TmdbService.getRandomMovie();
      if (!mounted) return;

      setState(() => _showOverlay = false);

      if (movie != null) {
        await widget.navigatorKey.currentState?.pushNamed('/details', arguments: movie);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not find a movie. Try shaking again!'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _showOverlay = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to fetch random movie. Check your connection.'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _accelerometerSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_showOverlay)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.85),
              child: Center(
                child: Image.asset(
                  'assets/images/processed (1).gif',
                  width: 320,
                  height: 320,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
