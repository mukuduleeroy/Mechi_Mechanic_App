import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mechi/core/design_system/design_system.dart';
import 'package:mechi/features/assistance/demo_map.dart';

void main() {
  testWidgets(
    'map interpolates projected positions and wraps headings at north',
    (tester) async {
      Widget map(Offset position, double heading) => MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox.square(
            dimension: 200,
            child: DemoMap(trackingFix: (position: position, heading: heading)),
          ),
        ),
      );
      final car = find.byWidgetPredicate(
        (widget) =>
            widget is Image && widget.semanticLabel == 'Mechanic vehicle',
      );
      Transform rotation() =>
          tester.element(car).findAncestorWidgetOfExactType<Transform>()!;

      await tester.pumpWidget(map(const Offset(.2, .3), 350));
      expect(tester.getCenter(car), const Offset(40, 60));

      await tester.pumpWidget(map(const Offset(.7, .6), 10));
      await tester.pump(Mechi.motion ~/ 2);
      expect(tester.getCenter(car).dx, inExclusiveRange(40, 140));
      expect(rotation().transform.storage[0], greaterThan(.98));

      await tester.pumpAndSettle();
      expect(tester.getCenter(car).dx, closeTo(140, .01));
      expect(tester.getCenter(car).dy, closeTo(120, .01));
    },
  );
}
