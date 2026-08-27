// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hive_models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CategoryAdapter extends TypeAdapter<Category> {
  @override
  final int typeId = 0;

  @override
  Category read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Category(
      id: fields[0] as String?,
      name: fields[1] as String?,
      userId: fields[2] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Category obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.userId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CommunityAdapter extends TypeAdapter<Community> {
  @override
  final int typeId = 1;

  @override
  Community read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Community(
      id: fields[0] as String?,
      name: fields[1] as String?,
      creatorId: fields[2] as String?,
      createdAt: fields[3] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Community obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.creatorId)
      ..writeByte(3)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CommunityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CommunityMemberAdapter extends TypeAdapter<CommunityMember> {
  @override
  final int typeId = 2;

  @override
  CommunityMember read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CommunityMember(
      communityId: fields[0] as String?,
      userId: fields[1] as String?,
      role: fields[2] as String?,
      fullName: fields[3] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, CommunityMember obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.communityId)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.role)
      ..writeByte(3)
      ..write(obj.fullName);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CommunityMemberAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TaskAdapter extends TypeAdapter<Task> {
  @override
  final int typeId = 3;

  @override
  Task read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Task(
      id: fields[0] as String?,
      title: fields[1] as String?,
      description: fields[2] as String?,
      isCompleted: fields[3] as bool?,
      userId: fields[4] as String?,
      communityId: fields[5] as String?,
      categoryId: fields[6] as String?,
      createdAt: fields[7] as DateTime?,
      dueAt: fields[8] as DateTime?,
      priority: fields[9] as String?,
      assignees: (fields[10] as List?)?.cast<String>(),
      status: fields[11] as String?,
      order: fields[12] as int?,
      categoryIds: (fields[13] as List?)?.cast<String>(),
      subtasks: (fields[14] as List?)
          ?.map((dynamic e) => (e as Map).cast<dynamic, dynamic>())
          ?.toList(),
      updatedAt: fields[15] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Task obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.isCompleted)
      ..writeByte(4)
      ..write(obj.userId)
      ..writeByte(5)
      ..write(obj.communityId)
      ..writeByte(6)
      ..write(obj.categoryId)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.dueAt)
      ..writeByte(9)
      ..write(obj.priority)
      ..writeByte(10)
      ..write(obj.assignees)
      ..writeByte(11)
      ..write(obj.status)
      ..writeByte(12)
      ..write(obj.order)
      ..writeByte(13)
      ..write(obj.categoryIds)
      ..writeByte(14)
      ..write(obj.subtasks)
      ..writeByte(15)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SettingsAdapter extends TypeAdapter<Settings> {
  @override
  final int typeId = 4;

  @override
  Settings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Settings(
      themeMode: fields[0] as int?,
      fontSizeIndex: fields[1] as int?,
      dailyBriefingEnabled: fields[2] as bool?,
      taskAssignmentsEnabled: fields[3] as bool?,
      dueDateRemindersEnabled: fields[4] as bool?,
      communityMentionsEnabled: fields[5] as bool?,
      newsAndOffersEnabled: fields[6] as bool?,
      legalAccepted: fields[7] as bool?,
      onboardingComplete: fields[8] as bool?,
    );
  }

  @override
  void write(BinaryWriter writer, Settings obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.themeMode)
      ..writeByte(1)
      ..write(obj.fontSizeIndex)
      ..writeByte(2)
      ..write(obj.dailyBriefingEnabled)
      ..writeByte(3)
      ..write(obj.taskAssignmentsEnabled)
      ..writeByte(4)
      ..write(obj.dueDateRemindersEnabled)
      ..writeByte(5)
      ..write(obj.communityMentionsEnabled)
      ..writeByte(6)
      ..write(obj.newsAndOffersEnabled)
      ..writeByte(7)
      ..write(obj.legalAccepted)
      ..writeByte(8)
      ..write(obj.onboardingComplete);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
