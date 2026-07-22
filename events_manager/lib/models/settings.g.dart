// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetSettingsCollection on Isar {
  IsarCollection<Settings> get settings => this.collection();
}

const SettingsSchema = CollectionSchema(
  name: r'Settings',
  id: -8656046621518759136,
  properties: {
    r'communityMentionsEnabled': PropertySchema(
      id: 0,
      name: r'communityMentionsEnabled',
      type: IsarType.bool,
    ),
    r'customThemeJson': PropertySchema(
      id: 1,
      name: r'customThemeJson',
      type: IsarType.string,
    ),
    r'dailyBriefingEnabled': PropertySchema(
      id: 2,
      name: r'dailyBriefingEnabled',
      type: IsarType.bool,
    ),
    r'dueDateRemindersEnabled': PropertySchema(
      id: 3,
      name: r'dueDateRemindersEnabled',
      type: IsarType.bool,
    ),
    r'fontSizeIndex': PropertySchema(
      id: 4,
      name: r'fontSizeIndex',
      type: IsarType.long,
    ),
    r'newsAndOffersEnabled': PropertySchema(
      id: 5,
      name: r'newsAndOffersEnabled',
      type: IsarType.bool,
    ),
    r'remindersEnabled': PropertySchema(
      id: 6,
      name: r'remindersEnabled',
      type: IsarType.bool,
    ),
    r'taskAssignmentsEnabled': PropertySchema(
      id: 7,
      name: r'taskAssignmentsEnabled',
      type: IsarType.bool,
    ),
    r'themeMode': PropertySchema(
      id: 8,
      name: r'themeMode',
      type: IsarType.long,
    )
  },
  estimateSize: _settingsEstimateSize,
  serialize: _settingsSerialize,
  deserialize: _settingsDeserialize,
  deserializeProp: _settingsDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _settingsGetId,
  getLinks: _settingsGetLinks,
  attach: _settingsAttach,
  version: '3.1.0+1',
);

int _settingsEstimateSize(
  Settings object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.customThemeJson;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _settingsSerialize(
  Settings object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeBool(offsets[0], object.communityMentionsEnabled);
  writer.writeString(offsets[1], object.customThemeJson);
  writer.writeBool(offsets[2], object.dailyBriefingEnabled);
  writer.writeBool(offsets[3], object.dueDateRemindersEnabled);
  writer.writeLong(offsets[4], object.fontSizeIndex);
  writer.writeBool(offsets[5], object.newsAndOffersEnabled);
  writer.writeBool(offsets[6], object.remindersEnabled);
  writer.writeBool(offsets[7], object.taskAssignmentsEnabled);
  writer.writeLong(offsets[8], object.themeMode);
}

Settings _settingsDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Settings();
  object.communityMentionsEnabled = reader.readBool(offsets[0]);
  object.customThemeJson = reader.readStringOrNull(offsets[1]);
  object.dailyBriefingEnabled = reader.readBool(offsets[2]);
  object.dueDateRemindersEnabled = reader.readBool(offsets[3]);
  object.fontSizeIndex = reader.readLong(offsets[4]);
  object.id = id;
  object.newsAndOffersEnabled = reader.readBool(offsets[5]);
  object.remindersEnabled = reader.readBool(offsets[6]);
  object.taskAssignmentsEnabled = reader.readBool(offsets[7]);
  object.themeMode = reader.readLong(offsets[8]);
  return object;
}

P _settingsDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readBool(offset)) as P;
    case 1:
      return (reader.readStringOrNull(offset)) as P;
    case 2:
      return (reader.readBool(offset)) as P;
    case 3:
      return (reader.readBool(offset)) as P;
    case 4:
      return (reader.readLong(offset)) as P;
    case 5:
      return (reader.readBool(offset)) as P;
    case 6:
      return (reader.readBool(offset)) as P;
    case 7:
      return (reader.readBool(offset)) as P;
    case 8:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _settingsGetId(Settings object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _settingsGetLinks(Settings object) {
  return [];
}

void _settingsAttach(IsarCollection<dynamic> col, Id id, Settings object) {
  object.id = id;
}

extension SettingsQueryWhereSort on QueryBuilder<Settings, Settings, QWhere> {
  QueryBuilder<Settings, Settings, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension SettingsQueryWhere on QueryBuilder<Settings, Settings, QWhereClause> {
  QueryBuilder<Settings, Settings, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<Settings, Settings, QAfterWhereClause> idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<Settings, Settings, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<Settings, Settings, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<Settings, Settings, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension SettingsQueryFilter
    on QueryBuilder<Settings, Settings, QFilterCondition> {
  QueryBuilder<Settings, Settings, QAfterFilterCondition>
      communityMentionsEnabledEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'communityMentionsEnabled',
        value: value,
      ));
    });
  }

  QueryBuilder<Settings, Settings, QAfterFilterCondition>
      customThemeJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'customThemeJson',
      ));
    });
  }

  QueryBuilder<Settings, Settings, QAfterFilterCondition>
      customThemeJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'customThemeJson',
      ));
    });
  }

  QueryBuilder<Settings, Settings, QAfterFilterCondition>
      customThemeJsonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'customThemeJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Settings, Settings, QAfterFilterCondition>
      customThemeJsonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'customThemeJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Settings, Settings, QAfterFilterCondition>
      customThemeJsonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'customThemeJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Settings, Settings, QAfterFilterCondition>
      customThemeJsonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'customThemeJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Settings, Settings, QAfterFilterCondition>
      customThemeJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'customThemeJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Settings, Settings, QAfterFilterCondition>
      customThemeJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'customThemeJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Settings, Settings, QAfterFilterCondition>
      customThemeJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'customThemeJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Settings, Settings, QAfterFilterCondition>
      customThemeJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'customThemeJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Settings, Settings, QAfterFilterCondition>
      customThemeJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'customThemeJson',
        value: '',
      ));
    });
  }

  QueryBuilder<Settings, Settings, QAfterFilterCondition>
      customThemeJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'customThemeJson',
        value: '',
      ));
    });
  }

  QueryBuilder<Settings, Settings, QAfterFilterCondition>
      dailyBriefingEnabledEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'dailyBriefingEnabled',
        value: value,
      ));
    });
  }

  QueryBuilder<Settings, Settings, QAfterFilterCondition>
      dueDateRemindersEnabledEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'dueDateRemindersEnabled',
        value: value,
      ));
    });
  }

  QueryBuilder<Settings, Settings, QAfterFilterCondition> fontSizeIndexEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'fontSizeIndex',
        value: value,
      ));
    });
  }

  QueryBuilder<Settings, Settings, QAfterFilterCondition>
      fontSizeIndexGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'fontSizeIndex',
        value: value,
      ));
    });
  }

  QueryBuilder<Settings, Settings, QAfterFilterCondition> fontSizeIndexLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'fontSizeIndex',
        value: value,
      ));
    });
  }

  QueryBuilder<Settings, Settings, QAfterFilterCondition> fontSizeIndexBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'fontSizeIndex',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Settings, Settings, QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<Settings, Settings, QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<Settings, Settings, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<Settings, Settings, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Settings, Settings, QAfterFilterCondition>
      newsAndOffersEnabledEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'newsAndOffersEnabled',
        value: value,
      ));
    });
  }

  QueryBuilder<Settings, Settings, QAfterFilterCondition>
      remindersEnabledEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'remindersEnabled',
        value: value,
      ));
    });
  }

  QueryBuilder<Settings, Settings, QAfterFilterCondition>
      taskAssignmentsEnabledEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'taskAssignmentsEnabled',
        value: value,
      ));
    });
  }

  QueryBuilder<Settings, Settings, QAfterFilterCondition> themeModeEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'themeMode',
        value: value,
      ));
    });
  }

  QueryBuilder<Settings, Settings, QAfterFilterCondition> themeModeGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'themeMode',
        value: value,
      ));
    });
  }

  QueryBuilder<Settings, Settings, QAfterFilterCondition> themeModeLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'themeMode',
        value: value,
      ));
    });
  }

  QueryBuilder<Settings, Settings, QAfterFilterCondition> themeModeBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'themeMode',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension SettingsQueryObject
    on QueryBuilder<Settings, Settings, QFilterCondition> {}

extension SettingsQueryLinks
    on QueryBuilder<Settings, Settings, QFilterCondition> {}

extension SettingsQuerySortBy on QueryBuilder<Settings, Settings, QSortBy> {
  QueryBuilder<Settings, Settings, QAfterSortBy>
      sortByCommunityMentionsEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'communityMentionsEnabled', Sort.asc);
    });
  }

  QueryBuilder<Settings, Settings, QAfterSortBy>
      sortByCommunityMentionsEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'communityMentionsEnabled', Sort.desc);
    });
  }

  QueryBuilder<Settings, Settings, QAfterSortBy> sortByCustomThemeJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'customThemeJson', Sort.asc);
    });
  }

  QueryBuilder<Settings, Settings, QAfterSortBy> sortByCustomThemeJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'customThemeJson', Sort.desc);
    });
  }

  QueryBuilder<Settings, Settings, QAfterSortBy> sortByDailyBriefingEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dailyBriefingEnabled', Sort.asc);
    });
  }

  QueryBuilder<Settings, Settings, QAfterSortBy>
      sortByDailyBriefingEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dailyBriefingEnabled', Sort.desc);
    });
  }

  QueryBuilder<Settings, Settings, QAfterSortBy>
      sortByDueDateRemindersEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dueDateRemindersEnabled', Sort.asc);
    });
  }

  QueryBuilder<Settings, Settings, QAfterSortBy>
      sortByDueDateRemindersEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dueDateRemindersEnabled', Sort.desc);
    });
  }

  QueryBuilder<Settings, Settings, QAfterSortBy> sortByFontSizeIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fontSizeIndex', Sort.asc);
    });
  }

  QueryBuilder<Settings, Settings, QAfterSortBy> sortByFontSizeIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fontSizeIndex', Sort.desc);
    });
  }

  QueryBuilder<Settings, Settings, QAfterSortBy> sortByNewsAndOffersEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'newsAndOffersEnabled', Sort.asc);
    });
  }

  QueryBuilder<Settings, Settings, QAfterSortBy>
      sortByNewsAndOffersEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'newsAndOffersEnabled', Sort.desc);
    });
  }

  QueryBuilder<Settings, Settings, QAfterSortBy> sortByRemindersEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'remindersEnabled', Sort.asc);
    });
  }

  QueryBuilder<Settings, Settings, QAfterSortBy> sortByRemindersEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'remindersEnabled', Sort.desc);
    });
  }

  QueryBuilder<Settings, Settings, QAfterSortBy>
      sortByTaskAssignmentsEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'taskAssignmentsEnabled', Sort.asc);
    });
  }

  QueryBuilder<Settings, Settings, QAfterSortBy>
      sortByTaskAssignmentsEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'taskAssignmentsEnabled', Sort.desc);
    });
  }

  QueryBuilder<Settings, Settings, QAfterSortBy> sortByThemeMode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'themeMode', Sort.asc);
    });
  }

  QueryBuilder<Settings, Settings, QAfterSortBy> sortByThemeModeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'themeMode', Sort.desc);
    });
  }
}

extension SettingsQuerySortThenBy
    on QueryBuilder<Settings, Settings, QSortThenBy> {
  QueryBuilder<Settings, Settings, QAfterSortBy>
      thenByCommunityMentionsEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'communityMentionsEnabled', Sort.asc);
    });
  }

  QueryBuilder<Settings, Settings, QAfterSortBy>
      thenByCommunityMentionsEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'communityMentionsEnabled', Sort.desc);
    });
  }

  QueryBuilder<Settings, Settings, QAfterSortBy> thenByCustomThemeJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'customThemeJson', Sort.asc);
    });
  }

  QueryBuilder<Settings, Settings, QAfterSortBy> thenByCustomThemeJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'customThemeJson', Sort.desc);
    });
  }

  QueryBuilder<Settings, Settings, QAfterSortBy> thenByDailyBriefingEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dailyBriefingEnabled', Sort.asc);
    });
  }

  QueryBuilder<Settings, Settings, QAfterSortBy>
      thenByDailyBriefingEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dailyBriefingEnabled', Sort.desc);
    });
  }

  QueryBuilder<Settings, Settings, QAfterSortBy>
      thenByDueDateRemindersEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dueDateRemindersEnabled', Sort.asc);
    });
  }

  QueryBuilder<Settings, Settings, QAfterSortBy>
      thenByDueDateRemindersEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dueDateRemindersEnabled', Sort.desc);
    });
  }

  QueryBuilder<Settings, Settings, QAfterSortBy> thenByFontSizeIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fontSizeIndex', Sort.asc);
    });
  }

  QueryBuilder<Settings, Settings, QAfterSortBy> thenByFontSizeIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fontSizeIndex', Sort.desc);
    });
  }

  QueryBuilder<Settings, Settings, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<Settings, Settings, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<Settings, Settings, QAfterSortBy> thenByNewsAndOffersEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'newsAndOffersEnabled', Sort.asc);
    });
  }

  QueryBuilder<Settings, Settings, QAfterSortBy>
      thenByNewsAndOffersEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'newsAndOffersEnabled', Sort.desc);
    });
  }

  QueryBuilder<Settings, Settings, QAfterSortBy> thenByRemindersEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'remindersEnabled', Sort.asc);
    });
  }

  QueryBuilder<Settings, Settings, QAfterSortBy> thenByRemindersEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'remindersEnabled', Sort.desc);
    });
  }

  QueryBuilder<Settings, Settings, QAfterSortBy>
      thenByTaskAssignmentsEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'taskAssignmentsEnabled', Sort.asc);
    });
  }

  QueryBuilder<Settings, Settings, QAfterSortBy>
      thenByTaskAssignmentsEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'taskAssignmentsEnabled', Sort.desc);
    });
  }

  QueryBuilder<Settings, Settings, QAfterSortBy> thenByThemeMode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'themeMode', Sort.asc);
    });
  }

  QueryBuilder<Settings, Settings, QAfterSortBy> thenByThemeModeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'themeMode', Sort.desc);
    });
  }
}

extension SettingsQueryWhereDistinct
    on QueryBuilder<Settings, Settings, QDistinct> {
  QueryBuilder<Settings, Settings, QDistinct>
      distinctByCommunityMentionsEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'communityMentionsEnabled');
    });
  }

  QueryBuilder<Settings, Settings, QDistinct> distinctByCustomThemeJson(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'customThemeJson',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Settings, Settings, QDistinct> distinctByDailyBriefingEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'dailyBriefingEnabled');
    });
  }

  QueryBuilder<Settings, Settings, QDistinct>
      distinctByDueDateRemindersEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'dueDateRemindersEnabled');
    });
  }

  QueryBuilder<Settings, Settings, QDistinct> distinctByFontSizeIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'fontSizeIndex');
    });
  }

  QueryBuilder<Settings, Settings, QDistinct> distinctByNewsAndOffersEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'newsAndOffersEnabled');
    });
  }

  QueryBuilder<Settings, Settings, QDistinct> distinctByRemindersEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'remindersEnabled');
    });
  }

  QueryBuilder<Settings, Settings, QDistinct>
      distinctByTaskAssignmentsEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'taskAssignmentsEnabled');
    });
  }

  QueryBuilder<Settings, Settings, QDistinct> distinctByThemeMode() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'themeMode');
    });
  }
}

extension SettingsQueryProperty
    on QueryBuilder<Settings, Settings, QQueryProperty> {
  QueryBuilder<Settings, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<Settings, bool, QQueryOperations>
      communityMentionsEnabledProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'communityMentionsEnabled');
    });
  }

  QueryBuilder<Settings, String?, QQueryOperations> customThemeJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'customThemeJson');
    });
  }

  QueryBuilder<Settings, bool, QQueryOperations>
      dailyBriefingEnabledProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'dailyBriefingEnabled');
    });
  }

  QueryBuilder<Settings, bool, QQueryOperations>
      dueDateRemindersEnabledProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'dueDateRemindersEnabled');
    });
  }

  QueryBuilder<Settings, int, QQueryOperations> fontSizeIndexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'fontSizeIndex');
    });
  }

  QueryBuilder<Settings, bool, QQueryOperations>
      newsAndOffersEnabledProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'newsAndOffersEnabled');
    });
  }

  QueryBuilder<Settings, bool, QQueryOperations> remindersEnabledProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'remindersEnabled');
    });
  }

  QueryBuilder<Settings, bool, QQueryOperations>
      taskAssignmentsEnabledProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'taskAssignmentsEnabled');
    });
  }

  QueryBuilder<Settings, int, QQueryOperations> themeModeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'themeMode');
    });
  }
}
