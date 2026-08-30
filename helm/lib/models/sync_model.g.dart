// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SyncActionAdapter extends TypeAdapter<SyncAction> {
  @override
  final int typeId = 6;

  @override
  SyncAction read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SyncAction(
      id: fields[0] as String,
      action: fields[1] as SyncActionType,
      table: fields[2] as String,
      payload: (fields[3] as Map).cast<dynamic, dynamic>(),
      timestamp: fields[4] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, SyncAction obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.action)
      ..writeByte(2)
      ..write(obj.table)
      ..writeByte(3)
      ..write(obj.payload)
      ..writeByte(4)
      ..write(obj.timestamp);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncActionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SyncActionTypeAdapter extends TypeAdapter<SyncActionType> {
  @override
  final int typeId = 5;

  @override
  SyncActionType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return SyncActionType.create;
      case 1:
        return SyncActionType.update;
      case 2:
        return SyncActionType.delete;
      default:
        return SyncActionType.create;
    }
  }

  @override
  void write(BinaryWriter writer, SyncActionType obj) {
    switch (obj) {
      case SyncActionType.create:
        writer.writeByte(0);
        break;
      case SyncActionType.update:
        writer.writeByte(1);
        break;
      case SyncActionType.delete:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyncActionTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
