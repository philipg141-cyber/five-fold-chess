import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'domain/models/variant.dart';
import 'presentation/screens/account_screen.dart';
import 'presentation/screens/game_screen.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/onboarding_screen.dart';
import 'presentation/screens/online_lobby_screen.dart';
import 'presentation/screens/settings_screen.dart';
import 'presentation/screens/variant_picker_screen.dart';

/// Root widget for the Fivefold Chess app.
///
/// Wires up Material 3 theming (light + dark) and the named route table.
class FivefoldChessApp extends ConsumerWidget {
  const FivefoldChessApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // First-launch users see the variant walkthrough; subsequent launches
    // go straight home.
    final initialRoute = OnboardingScreen.shouldShow()
        ? OnboardingScreen.route
        : HomeScreen.route;

    return MaterialApp(
      title: 'Fivefold Chess',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: _lightTheme,
      darkTheme: _darkTheme,
      initialRoute: initialRoute,
      onGenerateRoute: _onGenerateRoute,
    );
  }

  Route<Object?>? _onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case OnboardingScreen.route:
        return MaterialPageRoute<void>(
          builder: (_) => const OnboardingScreen(),
        );
      case HomeScreen.route:
        return MaterialPageRoute<void>(builder: (_) => const HomeScreen());
      case VariantPickerScreen.route:
        final args = settings.arguments as VariantPickerArgs?;
        return MaterialPageRoute<void>(
          builder: (_) => VariantPickerScreen(
            args: args ?? const VariantPickerArgs(mode: PlayMode.passAndPlay),
          ),
        );
      case SettingsScreen.route:
        return MaterialPageRoute<void>(builder: (_) => const SettingsScreen());
      case AccountScreen.route:
        final mode = settings.arguments is AccountScreenMode
            ? settings.arguments as AccountScreenMode
            : AccountScreenMode.signIn;
        return MaterialPageRoute<void>(
          builder: (_) => AccountScreen(initialMode: mode),
        );
      case OnlineLobbyScreen.route:
        return MaterialPageRoute<MatchedGameRouteResult>(
          builder: (_) => const OnlineLobbyScreen(),
        );
      case GameScreen.route:
        final args = settings.arguments as GameScreenArgs?;
        if (args == null) {
          return MaterialPageRoute<void>(
            builder: (_) => const GameScreen(args: GameScreenArgs(variant: Variant.classic)),
          );
        }
        return MaterialPageRoute<void>(builder: (_) => GameScreen(args: args));
      default:
        return null;
    }
  }
}

/// Type alias used by the route table; the lobby pops a [MatchedGame] back to
/// its caller, but we don't import MatchedGame here to keep the route table
/// dependency-light. Dynamic type is fine since the home screen explicitly
/// awaits the result.
typedef MatchedGameRouteResult = Object;

// ---------------------------------------------------------------------
// Theming
//
// Cinzel — a classical Roman serif — is used for display, headline,
// and title styles, giving the app the feel of a Staunton-set chess
// piece engraved on a wooden board. Inter handles body, label, and
// monospace-adjacent text where readability matters most.
//
// Fonts are fetched from Google's CDN by `google_fonts` on first use
// and cached on disk for subsequent launches. First cold-launch on a
// new device needs network access to render Cinzel; until it arrives,
// Flutter falls back to the platform default (Roboto on Android, San
// Francisco on iOS).
// ---------------------------------------------------------------------

TextTheme _buildTextTheme(TextTheme base) {
  // Cinzel for everything that wants weight and personality.
  final headline = GoogleFonts.cinzelTextTheme(base);
  // Inter for the dense functional text.
  final body = GoogleFonts.interTextTheme(base);

  return base.copyWith(
    displayLarge:    headline.displayLarge,
    displayMedium:   headline.displayMedium,
    displaySmall:    headline.displaySmall,
    headlineLarge:   headline.headlineLarge,
    headlineMedium:  headline.headlineMedium,
    headlineSmall:   headline.headlineSmall,
    titleLarge:      headline.titleLarge,
    titleMedium:     body.titleMedium,
    titleSmall:      body.titleSmall,
    bodyLarge:       body.bodyLarge,
    bodyMedium:      body.bodyMedium,
    bodySmall:       body.bodySmall,
    labelLarge:      body.labelLarge,
    labelMedium:     body.labelMedium,
    labelSmall:      body.labelSmall,
  );
}

final ThemeData _lightTheme = () {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF1F3864),
      brightness: Brightness.light,
    ),
  );
  return base.copyWith(textTheme: _buildTextTheme(base.textTheme));
}();

final ThemeData _darkTheme = () {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF1F3864),
      brightness: Brightness.dark,
    ),
  );
  return base.copyWith(textTheme: _buildTextTheme(base.textTheme));
}();
