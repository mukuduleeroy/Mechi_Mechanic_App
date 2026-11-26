import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _rules = RegExp(
  r'\b(?:Colors|CupertinoColors|Icons|CupertinoIcons)\.\w+'
  r'|\b(?:Color(?:\.from\w+)?|IconData)\([^()]*\)'
  r'|\b(?:TextStyle|BoxDecoration|BoxShadow)\(\s*(?:[a-zA-Z]+:\s*[^,()]+)?'
  r'|\b(?:BorderRadius|Radius)\.\w+\(\s*-?(?:\d+(?:\.\d+)?|\.\d+)'
  r'|\bEdgeInsets\.(?:all|fromLTRB|only|symmetric)\([^()]*\d[^()]*\)'
  r'|\bSizedBox\((?:\s*(?:height|width):\s*-?\d[^,)]*,?)+\s*\)',
);

Map<String, int> screenStyles() {
  final counts = <String, int>{};
  final screens = Directory('lib/features')
      .listSync(recursive: true)
      .whereType<File>()
      .where(
        (file) =>
            file.path.endsWith('_screen.dart') ||
            file.path.endsWith('_screens.dart'),
      );
  for (final file in screens) {
    for (final match in _rules.allMatches(file.readAsStringSync())) {
      final signature = match[0]!.replaceAll(RegExp(r'\s+'), '');
      final key = '${file.path.replaceAll('\\', '/')} $signature';
      counts.update(key, (count) => count + 1, ifAbsent: () => 1);
    }
  }
  return counts;
}

void main() {
  test('feature screens use approved design system styles', () {
    final allowed =
        jsonDecode(
              File(
                'test/design_system_style_allowances.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final violations = [
      for (final entry in screenStyles().entries)
        if (entry.value > ((allowed[entry.key] as int?) ?? 0))
          '${entry.key} (found ${entry.value}, allowed ${allowed[entry.key] ?? 0})',
    ];
    expect(
      violations,
      isEmpty,
      reason:
          'Compose the approved components or use existing tokens. '
          'See docs/design-system/README.md for documented exceptions.',
    );
  });
}
