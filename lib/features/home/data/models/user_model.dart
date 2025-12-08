import 'package:flutter/widgets.dart';

import '../../domain/entities/user.dart';

class UserModel extends UserInfo {
  UserModel({required super.name, super.program, super.image});

  factory UserModel.fromjson(Map<String, dynamic> json) {
    return UserModel(
      name: json['name'] as String,
      program: json['program'] as String,
      image: json['image'] as Image,
    );
  }
}
