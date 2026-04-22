import '../../domain/entities/finances_summary_entity.dart';
import '../../../../core/constants/app_mock_data.dart';

class MockFinancesRepository {
  Future<List<FinancesSummaryEntity>> getAllMonths() async =>
      AppMockData.monthsSummary;

  Future<FinancesSummaryEntity> getMonth(final String month) async =>
      AppMockData.monthsSummary.firstWhere(
        (final s) => s.month == month,
        orElse: () => AppMockData.monthsSummary.first,
      );
}
