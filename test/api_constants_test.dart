import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_project_structure/core/constants/api_constants.dart';
import 'package:flutter_project_structure/core/storage/token_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await TokenStorage.init();
  });

  test('API endpoint defaults to production in debug and release builds', () {
    expect(ApiConstants.defaultIsProduction, isTrue);
    expect(ApiConstants.isProduction, ApiConstants.defaultIsProduction);
    expect(ApiConstants.baseUrl, ApiConstants.productionUrl);
  });

  test('saved environment preference overrides the build default', () async {
    await TokenStorage.saveUseProduction(true);
    expect(ApiConstants.baseUrl, ApiConstants.productionUrl);

    await TokenStorage.saveUseProduction(false);
    expect(ApiConstants.isProduction, isFalse);
  });
}
