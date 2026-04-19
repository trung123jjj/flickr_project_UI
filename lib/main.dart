import 'package:flutter/material.dart';
import 'screens/intro_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/home_screen.dart';
import 'screens/details_screen.dart';
import 'models/movie.dart';
import 'services/tmdb_service.dart';

void main() async {
  // Đảm bảo Flutter binding được khởi tạo
  WidgetsFlutterBinding.ensureInitialized();
  
  // Khởi tạo danh sách thể loại từ TMDB ngay khi mở app
  await TmdbService.initGenres();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
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
      // Đặt lại trang chủ là IntroScreen
      home: const IntroScreen(),
      onGenerateRoute: (settings) {
        Widget page;
        
        if (settings.name == '/details') {
          final movie = settings.arguments as Movie;
          page = DetailsScreen(movie: movie);
        } else {
          switch (settings.name) {
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
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeInOutQuart;
            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
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
  }
}
