import 'package:material_ui/material_ui.dart';
import '../foundations/mechi.dart';
import 'package:flutter/services.dart';
import '../components/page_chrome.dart';

class Screen extends StatelessWidget {
  const Screen({
    super.key,
    required this.title,
    required this.children,
    this.footer,
    this.onBack,
    this.backgroundColor,
  });
  final String title;
  final List<Widget> children;
  final Widget? footer;
  final VoidCallback? onBack;
  final Color? backgroundColor;
  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.dark,
    child: Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            PageHeader(title: title, onBack: onBack),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  Mechi.pad,
                  Mechi.gap,
                  Mechi.pad,
                  Mechi.pad,
                ),
                children: [
                  for (final child in children)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Mechi.pageItemGap),
                      child: child,
                    ),
                ],
              ),
            ),
            if (footer != null) BottomActionBar(child: footer!),
          ],
        ),
      ),
    ),
  );
}
