import '../repositories/user_repository.dart';
import '../entities/user.dart';

class GetUserinfoUsecase {
  final UserRepository repository;

  GetUserinfoUsecase({required this.repository});

  Future<List<UserInfo>> getUserInfo() async {
    final data = await repository.getUserInfo();
    return data;
  }
}
