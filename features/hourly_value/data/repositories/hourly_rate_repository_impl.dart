import '../../domain/entities/hourly_rate_entity.dart';
import '../../domain/repositories/hourly_rate_repository.dart';
import '../datasources/hourly_rate_local_datasource.dart';
import '../models/hourly_rate_model.dart';

/// Implementation of HourlyRateRepository.
/// Connects the domain layer with the data source layer.
class HourlyRateRepositoryImpl implements HourlyRateRepository {
  final HourlyRateLocalDataSource localDataSource;

  HourlyRateRepositoryImpl({required this.localDataSource});

  @override
  Future<HourlyRateEntity?> getHourlyRate() async {
    final model = await localDataSource.getHourlyRate();
    return model?.toEntity();
  }

  @override
  Future<void> saveHourlyRate(final HourlyRateEntity hourlyRate) async {
    final model = HourlyRateModel.fromEntity(hourlyRate);
    await localDataSource.saveHourlyRate(model);
  }

  @override
  Future<bool> hasConfiguration() async => localDataSource.hasConfiguration();
}
