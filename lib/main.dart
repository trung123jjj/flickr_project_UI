import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
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
import 'models/movie.dart';
import 'services/tmdb_service.dart';

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
                final movie = settings.arguments as Movie;
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
