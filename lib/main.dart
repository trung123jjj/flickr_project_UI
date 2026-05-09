import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'screens/intro_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/home_screen.dart';
import 'screens/details_screen.dart';
import 'screens/comments_screen.dart';
import 'screens/genre_movies_screen.dart';
import 'models/movie.dart';
import 'services/tmdb_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    print("Warning: .env file not found");
  }

  await TmdbService.initGenres();

  final authProvider = AuthProvider();
  await authProvider.loadSession();

  runApp(MyApp(authProvider: authProvider));
}

class MyApp extends StatelessWidget {
  final AuthProvider authProvider;

  const MyApp({super.key, required this.authProvider});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: authProvider,
      child: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          return MaterialApp(
            title: 'Flickr App',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              brightness: Brightness.dark,
              scaffoldBackgroundColor: const Color(0xFF0D1B2A),
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF0D1B2A),
                brightness: Brightness.dark,
              ),
            ),
            initialRoute: auth.isLoggedIn ? '/home' : '/',
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

              return PageRouteBuilder(
                settings: settings,
                pageBuilder: (context, animation, secondaryAnimation) => page,
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                  const begin = Offset(1.0, 0.0);
                  const end = Offset.zero;
                  const curve = Curves.easeInOutQuart;
                  var tween =
                      Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: animation.drive(tween),
                      child: child,
                    ),
                  );
                },
                transitionDuration: const Duration(milliseconds: 400),
              );
            },
          );
        },
      ),
    );
  }
}
