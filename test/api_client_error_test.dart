import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_project_structure/core/network/api_client.dart';
import 'package:flutter_project_structure/core/storage/token_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await TokenStorage.init();
  });

  setUp(() async {
    await TokenStorage.saveLanguage('en');
  });

  test(
    'connection failures share one message without claiming internet is down',
    () {
      final requestOptions = RequestOptions(path: '/health');
      final connectionError = DioException(
        requestOptions: requestOptions,
        type: DioExceptionType.connectionError,
      );
      final timeoutError = DioException(
        requestOptions: requestOptions,
        type: DioExceptionType.connectionTimeout,
      );

      final message = ApiClient.handleError(connectionError);

      expect(message, ApiClient.handleError(timeoutError));
      expect(message, contains('ShopSilo'));
      expect(message.toLowerCase(), isNot(contains('internet connection')));
      expect(ApiClient.isNetworkErrorMessage(message), isTrue);
    },
  );

  test('network failure messages follow the selected language', () async {
    await TokenStorage.saveLanguage('hi');

    final message = ApiClient.handleError(
      DioException(
        requestOptions: RequestOptions(path: '/health'),
        type: DioExceptionType.connectionError,
      ),
    );

    expect(message, contains('ShopSilo'));
    expect(message, contains('सर्वर या नेटवर्क'));
    expect(ApiClient.isNetworkErrorMessage(message), isTrue);
  });

  test('unmapped HTTP failures are not mislabeled as network failures', () {
    final requestOptions = RequestOptions(path: '/health');
    final error = DioException(
      requestOptions: requestOptions,
      response: Response(requestOptions: requestOptions, statusCode: 418),
      type: DioExceptionType.badResponse,
    );

    final message = ApiClient.handleError(error);

    expect(message, contains('request could not be completed'));
    expect(ApiClient.isNetworkErrorMessage(message), isFalse);
  });

  test('technical Dart exceptions are replaced with a safe message', () {
    expect(
      ApiClient.handleError(const FormatException('bad payload')),
      'Something went wrong. Please try again.',
    );
  });
}
