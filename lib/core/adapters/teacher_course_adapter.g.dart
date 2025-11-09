// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'teacher_course_adapter.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TeacherCourseAdapter extends TypeAdapter<TeacherCourse> {
  @override
  final int typeId = 10;

  @override
  TeacherCourse read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TeacherCourse(
      id: fields[0] as String,
      teacherId: fields[1] as String,
      teacherName: fields[2] as String,
      courseId: fields[3] as String,
      courseName: fields[4] as String,
      semester: fields[5] as String,
      year: fields[6] as String,
      timestamp: fields[7] as String,
    );
  }

  @override
  void write(BinaryWriter writer, TeacherCourse obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.teacherId)
      ..writeByte(2)
      ..write(obj.teacherName)
      ..writeByte(3)
      ..write(obj.courseId)
      ..writeByte(4)
      ..write(obj.courseName)
      ..writeByte(5)
      ..write(obj.semester)
      ..writeByte(6)
      ..write(obj.year)
      ..writeByte(7)
      ..write(obj.timestamp);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TeacherCourseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
