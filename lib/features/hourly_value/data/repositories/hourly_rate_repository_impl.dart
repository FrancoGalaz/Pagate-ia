import '../../domain/entities/hourly_rate_entity.dart';
import '../../domain/repositories/hourly_rate_repository.dart';
import '../datasources/hourly_rate_local_datasource.dart';
import '../models/hourly_rate_model.dart';

class HourlyRateRepositoryImpl implements HourlyRateRepository {
  final HourlyRateLocalDataSource localDataSource;

  HourlyRateRepositoryImpl({required this.localDataSource});

  @override
  Stream<HourlyRateEntity?> watchHourlyRate() =>
      localDataSource.watchHourlyRate().map((model) => model?.toEntity());

  @override
  Future<HourlyRateEntity?> getHourlyRate() async =>
      (await localDataSource.getHourlyRate())?.toEntity();

  @override
  Future<void> saveHourlyRate(final HourlyRateEntity hourlyRate) =>
      localDataSource.saveHourlyRate(HourlyRateModel.fromEntity(hourlyRate));

  @override
  Future<bool> hasConfiguration() => localDataSource.hasConfiguration();
}
