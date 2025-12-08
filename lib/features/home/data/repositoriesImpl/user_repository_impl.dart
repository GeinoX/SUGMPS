import '../../domain/repositories/user_repository.dart';
import '../datasources/abstract_classes.dart';
import '../../domain/entities/user.dart';

class UserRepositoryImpl implements UserRepository {
  final UserRemoteDataSource remoteDataSource;

  UserRepositoryImpl({required this.remoteDataSource});
  @override
  Future<List<UserInfo>> getUserInfo() async {
    final data = await remoteDataSource.getUserInfo();
    return data;
  }
}
