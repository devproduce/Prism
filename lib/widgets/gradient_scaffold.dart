import 'package:flutter/material.dart';
import 'package:prism/widgets/gradient_background.dart';

class GradientScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final bool extendBodyBehindAppBar;
  final bool extendBody;

  const GradientScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.extendBodyBehindAppBar = false,
    this.extendBody = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. Full screen gradient background
        const Positioned.fill(
          child: GradientBackground(child: SizedBox.shrink()),
        ),
        // 2. Transparent Scaffold for structure
        Scaffold(
          extendBodyBehindAppBar: extendBodyBehindAppBar,
          extendBody: extendBody,
          appBar: appBar,
          bottomNavigationBar: bottomNavigationBar,
          floatingActionButton: floatingActionButton,
          floatingActionButtonLocation: floatingActionButtonLocation,
          backgroundColor: Colors.transparent,
          body: body,
        ),
      ],
    );
  }
}
