import '../../domain/repositories/user_repository.dart';
import '../datasources/user_remote_datasource.dart';
import '../../domain/entities/user.dart';

class UserRepositoryImpl extends UserRepository {
  final UserRemoteDataSource remoteDataSource;

  UserRepositoryImpl({required this.remoteDataSource});
  @override
  Future<List<UserInfo>> getUserInfo() async {
    final data = await remoteDataSource.getUserInfo();
    return data;
  }
}
