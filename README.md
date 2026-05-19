# Flickr Project — Frontend

A Flutter mobile app for browsing movies, rating them, and discussing them in real-time chat rooms. Powered by [TMDb](https://www.themoviedb.org/) for movie data and a custom [Node.js backend](https://github.com/anomalyco/flickr_project_Backend) for social features.

---

## Tech Stack

| Technology | Purpose |
|-----------|---------|
| **Flutter** (Dart) | Cross-platform UI framework |
| **Provider** | State management |
| **Socket.IO** (socket_io_client) | Real-time chat |
| **http** | REST API client |
| **shared_preferences** | Persistent local storage (auth, theme) |
| **cached_network_image** | Image caching & loading |
| **image_picker** | Gallery access (avatars, comment images) |
| **flutter_dotenv** | Environment variables |
| **sensors_plus** | Accelerometer (shake to discover) |

---

## Project Structure

```
flickr_project/
├── lib/
│   ├── main.dart                    # App entry, theme, routing, shake handler
│   ├── config/
│   │   └── api_config.dart          # Backend URL & TMDb token from .env
│   ├── models/
│   │   ├── movie.dart               # Movie model with TMDb image helpers
│   │   ├── genre.dart               # Genre model
│   │   ├── comment.dart             # Comment model (likes, replies, avatar)
│   │   └── cast.dart                # Cast model
│   ├── providers/
│   │   ├── auth_provider.dart       # Auth state (login, signup, logout, session)
│   │   └── theme_provider.dart      # Dark/light mode toggle
│   ├── screens/
│   │   ├── intro_screen.dart        # Splash / welcome screen
│   │   ├── login_screen.dart        # Login form
│   │   ├── signup_screen.dart       # Registration form
│   │   ├── home_screen.dart         # Main dashboard (carousel, genres, search)
│   │   ├── details_screen.dart      # Movie details, rating, cast
│   │   ├── comments_screen.dart     # Real-time chat room per movie
│   │   ├── genre_movies_screen.dart # Movies filtered by genre
│   │   ├── settings_screen.dart     # Profile, avatar, password, dark mode, logout
│   │   ├── report_screen.dart       # Admin moderation panel
│   │   └── notification_screen.dart # Notifications list
│   └── services/
│       ├── backend_service.dart     # All REST API calls to the backend
│       ├── tmdb_service.dart        # All TMDb API calls
│       └── auth_service.dart        # Local session helpers
├── assets/
│   └── images/                      # Static images
├── .env                             # Environment variables (gitignored)
├── .env.example                     # Environment template
├── pubspec.yaml
└── test/
    └── widget_test.dart

```

---

## Features

### Screens

| Screen | Description |
|--------|-------------|
| **Intro** | Splash screen with branding and "Get Started" button |
| **Login / Signup** | Auth forms connecting to the backend API |
| **Home** | Movie carousel ("Now Playing"), horizontal lists (Popular, Genres), search with debounce, unread notification badge |
| **Details** | Backdrop, title, release date, star rating (1-5 tap), expandable overview, genre chips, cast list with actor bio bottom sheet, "Join Chat" button |
| **Comments** | Real-time chat room per movie with text/image messages, threaded replies, like/unlike, delete own comments, report comments |
| **Genre Movies** | Movies filtered by selected genre with ratings |
| **Settings** | Profile info, avatar upload, username/password change, dark mode toggle, logout, admin reports entry |
| **Reports** | Admin-only panel: list reported comments, delete user, delete report, send notice |
| **Notifications** | List of notifications (reply alerts, admin notices), tap to navigate to comment room |

### Bonus Features

- **Shake to discover** — shake device to get a random movie suggestion (via accelerometer)
- **Dark mode** — toggle between light and dark themes (persisted)
- **Real-time chat** — Socket.IO-based comment rooms with live updates

---

## Screenshots

*(Add screenshots here)*

---

## Local Setup

### Prerequisites
- Flutter SDK >= 3.11
- Dart >= 3.11
- A running instance of the [backend server](https://github.com/anomalyco/flickr_project_Backend)
- A TMDb API key (free registration at [themoviedb.org](https://www.themoviedb.org/))

### Steps

```bash
# 1. Clone the repository
git clone <repo-url>
cd flickr_project

# 2. Install dependencies
flutter pub get

# 3. Create .env from template
cp .env.example .env
# Edit .env with your TMDb token and backend URL

# 4. Run the app
flutter run
```

### Environment Variables (.env)

| Variable | Description | Default |
|----------|-------------|---------|
| `TMDB_ACCESS_TOKEN` | TMDb API access token (v4 auth) | — |
| `BACKEND_URL` | Backend API base URL | `https://flickr-project-backend-6.onrender.com` |

---

## Architecture

The app follows a **Provider + Service** pattern:

- **Screens** are self-contained widgets that consume providers via `context.watch<T>()` / `context.read<T>()`
- **Providers** (`AuthProvider`, `ThemeProvider`) extend `ChangeNotifier` and manage global state
- **Services** (`BackendService`, `TMDbService`, `AuthService`) handle all API communication and are stateless
- **Models** are plain Dart classes with `fromJson` / `toJson` serialization

### Authentication Flow

1. User logs in → backend returns `accessToken` (JWT, 5 min) + `refreshToken` (cookie + response)
2. Tokens are stored in `SharedPreferences`
3. `BackendService._getHeaders()` attaches the access token to every request
4. On 403 response, the app automatically calls `/auth/refresh` to get a new access token
5. Logout clears tokens and deletes the session on the server

---

## Real-time (Socket.IO)

The comments screen connects to the backend via Socket.IO:

| Event | Direction | Description |
|-------|-----------|-------------|
| `joinMovie` | client → server | Join a movie's chat room |
| `leaveMovie` | client → server | Leave a chat room |
| `newComment` | server → client | New comment received |
| `commentUpdated` | server → client | Comment edited |
| `commentDeleted` | server → client | Comment removed |

---

## Testing

```bash
flutter test
```

---

## Notes

- This project uses **Provider** for state management (no Bloc/Riverpod yet)
- TMDb images are served via their CDN using constructed URLs (`https://image.tmdb.org/t/p/...`)
- The app targets **Android** and **iOS** (web and desktop also supported via Flutter's multi-platform)
- See [ISSUES.md](../flickr_project_Backend/ISSUES.md) for known issues across both frontend and backend
