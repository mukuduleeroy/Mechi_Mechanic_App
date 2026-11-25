import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mechi/main.dart' as app;
import 'package:shared_preferences/shared_preferences.dart';
import '../test/support/journey.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('roadside request to paid receipt and review', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await app.main();
    await tester.pumpAndSettle();
    await bookRepair(tester);
    await payAndReview(tester);
  });
}
