import 'package:flutter/material.dart';

class SessionLoadingScreen extends StatelessWidget {
  const SessionLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
