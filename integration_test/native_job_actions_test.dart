import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mechi/features/job_execution/native_job_actions.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('iOS accepts the native directions request', (tester) async {
    final opened = await tester.runAsync(
      () => openJobDirections(
        Uri.https('www.google.com', '/maps/dir/', {
          'api': '1',
          'destination': '10,51',
          'travelmode': 'driving',
        }),
      ),
    );
    expect(opened, isTrue);
  });
}
