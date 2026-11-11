import 'package:flutter/material.dart';

/// Shown instead of the app when a STORE_BUILD points at a test backend
/// (see storeBuildProblem in api_client.dart). Deliberately not localized and
/// not pretty: no end user should ever see it, the person who made the build
/// should, immediately.
class MisconfiguredBuildApp extends StatelessWidget {
  final String problem;
  const MisconfiguredBuildApp({super.key, required this.problem});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFB71C1C),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Misconfigured build',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                Text(problem,
                    style: const TextStyle(color: Colors.white, fontSize: 16)),
                const SizedBox(height: 16),
                const Text(
                  'This STORE_BUILD points at a test backend. Rebuild with '
                  '--dart-define=API_HOST=<production host>. See RELEASE_SETUP.md.',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
