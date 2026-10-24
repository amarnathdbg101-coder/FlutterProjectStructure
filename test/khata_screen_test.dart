
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_project_structure/core/storage/local_cache_service.dart';
import 'package:flutter_project_structure/core/localization/language_controller.dart';
import 'package:flutter_project_structure/features/khata/controllers/khata_controller.dart';
import 'package:flutter_project_structure/features/khata/models/khata_model.dart';
import 'package:flutter_project_structure/features/khata/screens/khata_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('KhataScreen displays customers with zero overflow and zero assertions', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    SharedPreferences.setMockInitialValues({});
    await LocalCacheService.init();

    final fakeCustomers = [
      KhataCustomerModel(
        id: 'cust-1',
        name: 'Ramesh Kumar',
        mobile: '9876543210',
        balance: 1500.0,
        creditLimit: 5000.0,
        trustScore: 85,
        overdueDays: 5,
        promiseDate: DateTime.now().add(const Duration(days: 2)),
      ),
      KhataCustomerModel(
        id: 'cust-2',
        name: 'Suresh Singh',
        mobile: '9123456780',
        balance: -200.0,
        creditLimit: 10000.0,
      ),
      KhataCustomerModel(
        id: 'cust-3',
        name: 'Amit Verma',
        mobile: '9988776655',
        balance: 0.0,
        creditLimit: 2000.0,
      ),
    ];
    await LocalCacheService.saveKhataCustomers(fakeCustomers);

    final languageCtrl = LanguageController();
    final khataCtrl = KhataController();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LanguageController>.value(value: languageCtrl),
          ChangeNotifierProvider<KhataController>.value(value: khataCtrl),
        ],
        child: const MaterialApp(
          home: KhataScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verify customers rendered
    expect(find.text('Ramesh Kumar'), findsOneWidget);
    expect(find.text('₹1500'), findsWidgets);
    expect(find.text('Suresh Singh'), findsOneWidget);

    // Search query
    await tester.enterText(find.byType(TextField).first, '9876543210');
    await tester.pumpAndSettle();
    expect(find.text('Ramesh Kumar'), findsOneWidget);
    expect(find.text('Suresh Singh'), findsNothing);
  });
}
