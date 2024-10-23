// main.dart
import 'package:busticket_mobile/home.dart';
import 'package:busticket_mobile/login.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

void main() async {
  // Initialize Hive
  await Hive.initFlutter();
  await Hive.openBox('authBox');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bus Ticket App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const AuthCheckScreen(),
    );
  }
}

// Auth Check Screen
class AuthCheckScreen extends StatefulWidget {
  const AuthCheckScreen({Key? key}) : super(key: key);

  @override
  State<AuthCheckScreen> createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends State<AuthCheckScreen> {
  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback to ensure navigation happens after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      checkAuth();
    });
  }

  void checkAuth() async {
    final authBox = Hive.box('authBox');
    final token = authBox.get('passenger_id');
    final hasSeenOnboarding = authBox.get('hasSeenOnboarding') ?? false;

    if (!mounted) return;

    if (token != null) {
      // User is logged in

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const Home()),
      );
    } else if (!hasSeenOnboarding) {
      // Show onboarding
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const OnboardingScreen()),
      );
    } else {
      // Show login
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

// Onboarding Screen (Modified)
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  bool isLastPage = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: const EdgeInsets.only(bottom: 80),
        child: PageView(
          controller: _controller,
          onPageChanged: (index) {
            setState(() {
              isLastPage = index == 2;
            });
          },
          children: [
            buildOnboardingPage(
              icon: Icons.search,
              title: 'Easy Bus Search',
              description:
                  'Find and book bus tickets for your journey with just a few taps',
              color: Colors.blue[50]!,
            ),
            buildOnboardingPage(
              icon: Icons.event_seat,
              title: 'Select Your Seat',
              description:
                  'Choose your preferred seat from our interactive seat layout',
              color: Colors.orange[50]!,
            ),
            buildOnboardingPage(
              icon: Icons.location_on,
              title: 'Track Your Bus',
              description:
                  'Real-time tracking to know exactly when your bus will arrive',
              color: Colors.green[50]!,
            ),
          ],
        ),
      ),
      bottomSheet: isLastPage
          ? TextButton(
              style: TextButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(0),
                ),
                foregroundColor: Colors.white,
                backgroundColor: Colors.blue.shade400,
                minimumSize: const Size.fromHeight(80),
              ),
              onPressed: () async {
                // Mark onboarding as seen
                final authBox = Hive.box('authBox');
                await authBox.put('hasSeenOnboarding', true);

                if (mounted) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                        builder: (context) => const LoginScreen()),
                  );
                }
              },
              child: const Text(
                'Get Started',
                style: TextStyle(fontSize: 24),
              ),
            )
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              height: 80,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => _controller.jumpToPage(2),
                    child: const Text('SKIP'),
                  ),
                  Center(
                    child: SmoothPageIndicator(
                      controller: _controller,
                      count: 3,
                      effect: WormEffect(
                        spacing: 16,
                        dotColor: Colors.black26,
                        activeDotColor: Colors.blue.shade400,
                      ),
                      onDotClicked: (index) => _controller.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeIn,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _controller.nextPage(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                    ),
                    child: const Text('NEXT'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget buildOnboardingPage({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      color: color,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 100,
            color: Colors.blue,
          ),
          const SizedBox(height: 64),
          Text(
            title,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}

// Modified HomePage with Logout

