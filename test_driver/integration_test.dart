// Copy to test_driver/integration_test.dart in your app.
//
// Required so store-kit can run the screenshot script in PROFILE mode via
// `flutter drive`. `flutter test` only supports debug mode, and a debug build
// paints "BOTTOM OVERFLOWED BY N PIXELS" banners into screenshots — profile
// strips that (it lives inside asserts) while looking identical to release.
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver();
