// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_track_stat_entity.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetDailyTrackStatEntityCollection on Isar {
  IsarCollection<DailyTrackStatEntity> get dailyTrackStatEntitys =>
      this.collection();
}

const DailyTrackStatEntitySchema = CollectionSchema(
  name: r'DailyTrackStatEntity',
  id: -8362740062442503678,
  properties: {
    r'day': PropertySchema(id: 0, name: r'day', type: IsarType.string),
    r'listenMs': PropertySchema(id: 1, name: r'listenMs', type: IsarType.long),
    r'pathKey': PropertySchema(id: 2, name: r'pathKey', type: IsarType.string),
    r'playCount': PropertySchema(
      id: 3,
      name: r'playCount',
      type: IsarType.long,
    ),
    r'title': PropertySchema(id: 4, name: r'title', type: IsarType.string),
    r'trackId': PropertySchema(id: 5, name: r'trackId', type: IsarType.string),
  },

  estimateSize: _dailyTrackStatEntityEstimateSize,
  serialize: _dailyTrackStatEntitySerialize,
  deserialize: _dailyTrackStatEntityDeserialize,
  deserializeProp: _dailyTrackStatEntityDeserializeProp,
  idName: r'id',
  indexes: {
    r'day_pathKey': IndexSchema(
      id: -4537947968384376528,
      name: r'day_pathKey',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'day',
          type: IndexType.hash,
          caseSensitive: true,
        ),
        IndexPropertySchema(
          name: r'pathKey',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _dailyTrackStatEntityGetId,
  getLinks: _dailyTrackStatEntityGetLinks,
  attach: _dailyTrackStatEntityAttach,
  version: '3.3.2',
);

int _dailyTrackStatEntityEstimateSize(
  DailyTrackStatEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.day.length * 3;
  bytesCount += 3 + object.pathKey.length * 3;
  bytesCount += 3 + object.title.length * 3;
  {
    final value = object.trackId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _dailyTrackStatEntitySerialize(
  DailyTrackStatEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.day);
  writer.writeLong(offsets[1], object.listenMs);
  writer.writeString(offsets[2], object.pathKey);
  writer.writeLong(offsets[3], object.playCount);
  writer.writeString(offsets[4], object.title);
  writer.writeString(offsets[5], object.trackId);
}

DailyTrackStatEntity _dailyTrackStatEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = DailyTrackStatEntity();
  object.day = reader.readString(offsets[0]);
  object.id = id;
  object.listenMs = reader.readLong(offsets[1]);
  object.pathKey = reader.readString(offsets[2]);
  object.playCount = reader.readLong(offsets[3]);
  object.title = reader.readString(offsets[4]);
  object.trackId = reader.readStringOrNull(offsets[5]);
  return object;
}

P _dailyTrackStatEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readLong(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readLong(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readStringOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _dailyTrackStatEntityGetId(DailyTrackStatEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _dailyTrackStatEntityGetLinks(
  DailyTrackStatEntity object,
) {
  return [];
}

void _dailyTrackStatEntityAttach(
  IsarCollection<dynamic> col,
  Id id,
  DailyTrackStatEntity object,
) {
  object.id = id;
}

extension DailyTrackStatEntityQueryWhereSort
    on QueryBuilder<DailyTrackStatEntity, DailyTrackStatEntity, QWhere> {
  QueryBuilder<DailyTrackStatEntity, DailyTrackStatEntity, QAfterWhere>
  anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension DailyTrackStatEntityQueryWhere
    on QueryBuilder<DailyTrackStatEntity, DailyTrackStatEntity, QWhereClause> {
  QueryBuilder<DailyTrackStatEntity, DailyTrackStatEntity, QAfterWhereClause>
  idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<DailyTrackStatEntity, DailyTrackStatEntity, QAfterWhereClause>
  idNotEqualTo(Id id) {
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

  QueryBuilder<DailyTrackStatEntity, DailyTrackStatEntity, QAfterWhereClause>
  idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<DailyTrackStatEntity, DailyTrackStatEntity, QAfterWhereClause>
  idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<DailyTrackStatEntity, DailyTrackStatEntity, QAfterWhereClause>
  idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerId,
          includeLower: includeLower,
          upper: upperId,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<DailyTrackStatEntity, DailyTrackStatEntity, QAfterWhereClause>
  dayEqualToAnyPathKey(String day) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'day_pathKey', value: [day]),
      );
    });
  }

  QueryBuilder<DailyTrackStatEntity, DailyTrackStatEntity, QAfterWhereClause>
  dayNotEqualToAnyPathKey(String day) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'day_pathKey',
                lower: [],
                upper: [day],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'day_pathKey',
                lower: [day],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'day_pathKey',
                lower: [day],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'day_pathKey',
                lower: [],
                upper: [day],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<DailyTrackStatEntity, DailyTrackStatEntity, QAfterWhereClause>
  dayPathKeyEqualTo(String day, String pathKey) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'day_pathKey',
          value: [day, pathKey],
        ),
      );
    });
  }

  QueryBuilder<DailyTrackStatEntity, DailyTrackStatEntity, QAfterWhereClause>
  dayEqualToPathKeyNotEqualTo(String day, String pathKey) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'day_pathKey',
                lower: [day],
                upper: [day, pathKey],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'day_pathKey',
                lower: [day, pathKey],
                includeLower: false,
                upper: [day],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'day_pathKey',
                lower: [day, pathKey],
                includeLower: false,
                upper: [day],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'day_pathKey',
                lower: [day],
                upper: [day, pathKey],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension DailyTrackStatEntityQueryFilter
    on
        QueryBuilder<
          DailyTrackStatEntity,
          DailyTrackStatEntity,
          QFilterCondition
        > {
  QueryBuilder<
    DailyTrackStatEntity,
    DailyTrackStatEntity,
    QAfterFilterCondition
  >
  dayEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'day',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DailyTrackStatEntity,
    DailyTrackStatEntity,
    QAfterFilterCondition
  >
  dayGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'day',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DailyTrackStatEntity,
    DailyTrackStatEntity,
    QAfterFilterCondition
  >
  dayLessThan(String value, {bool include = false, bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'day',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DailyTrackStatEntity,
    DailyTrackStatEntity,
    QAfterFilterCondition
  >
  dayBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'day',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DailyTrackStatEntity,
    DailyTrackStatEntity,
    QAfterFilterCondition
  >
  dayStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'day',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DailyTrackStatEntity,
    DailyTrackStatEntity,
    QAfterFilterCondition
  >
  dayEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'day',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DailyTrackStatEntity,
    DailyTrackStatEntity,
    QAfterFilterCondition
  >
  dayContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'day',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DailyTrackStatEntity,
    DailyTrackStatEntity,
    QAfterFilterCondition
  >
  dayMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'day',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DailyTrackStatEntity,
    DailyTrackStatEntity,
    QAfterFilterCondition
  >
  dayIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'day', value: ''),
      );
    });
  }

  QueryBuilder<
    DailyTrackStatEntity,
    DailyTrackStatEntity,
    QAfterFilterCondition
  >
  dayIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'day', value: ''),
      );
    });
  }

  QueryBuilder<
    DailyTrackStatEntity,
    DailyTrackStatEntity,
    QAfterFilterCondition
  >
  idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<
    DailyTrackStatEntity,
    DailyTrackStatEntity,
    QAfterFilterCondition
  >
  idGreaterThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    DailyTrackStatEntity,
    DailyTrackStatEntity,
    QAfterFilterCondition
  >
  idLessThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    DailyTrackStatEntity,
    DailyTrackStatEntity,
    QAfterFilterCondition
  >
  idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    DailyTrackStatEntity,
    DailyTrackStatEntity,
    QAfterFilterCondition
  >
  listenMsEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'listenMs', value: value),
      );
    });
  }

  QueryBuilder<
    DailyTrackStatEntity,
    DailyTrackStatEntity,
    QAfterFilterCondition
  >
  listenMsGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'listenMs',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    DailyTrackStatEntity,
    DailyTrackStatEntity,
    QAfterFilterCondition
  >
  listenMsLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'listenMs',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    DailyTrackStatEntity,
    DailyTrackStatEntity,
    QAfterFilterCondition
  >
  listenMsBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'listenMs',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    DailyTrackStatEntity,
    DailyTrackStatEntity,
    QAfterFilterCondition
  >
  pathKeyEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'pathKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DailyTrackStatEntity,
    DailyTrackStatEntity,
    QAfterFilterCondition
  >
  pathKeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'pathKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DailyTrackStatEntity,
    DailyTrackStatEntity,
    QAfterFilterCondition
  >
  pathKeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'pathKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DailyTrackStatEntity,
    DailyTrackStatEntity,
    QAfterFilterCondition
  >
  pathKeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'pathKey',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DailyTrackStatEntity,
    DailyTrackStatEntity,
    QAfterFilterCondition
  >
  pathKeyStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'pathKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DailyTrackStatEntity,
    DailyTrackStatEntity,
    QAfterFilterCondition
  >
  pathKeyEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'pathKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DailyTrackStatEntity,
    DailyTrackStatEntity,
    QAfterFilterCondition
  >
  pathKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'pathKey',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DailyTrackStatEntity,
    DailyTrackStatEntity,
    QAfterFilterCondition
  >
  pathKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'pathKey',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DailyTrackStatEntity,
    DailyTrackStatEntity,
    QAfterFilterCondition
  >
  pathKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'pathKey', value: ''),
      );
    });
  }

  QueryBuilder<
    DailyTrackStatEntity,
    DailyTrackStatEntity,
    QAfterFilterCondition
  >
  pathKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'pathKey', value: ''),
      );
    });
  }

  QueryBuilder<
    DailyTrackStatEntity,
    DailyTrackStatEntity,
    QAfterFilterCondition
  >
  playCountEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'playCount', value: value),
      );
    });
  }

  QueryBuilder<
    DailyTrackStatEntity,
    DailyTrackStatEntity,
    QAfterFilterCondition
  >
  playCountGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'playCount',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    DailyTrackStatEntity,
    DailyTrackStatEntity,
    QAfterFilterCondition
  >
  playCountLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'playCount',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    DailyTrackStatEntity,
    DailyTrackStatEntity,
    QAfterFilterCondition
  >
  playCountBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'playCount',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    DailyTrackStatEntity,
    DailyTrackStatEntity,
    QAfterFilterCondition
  >
  titleEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DailyTrackStatEntity,
    DailyTrackStatEntity,
    QAfterFilterCondition
  >
  titleGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DailyTrackStatEntity,
    DailyTrackStatEntity,
    QAfterFilterCondition
  >
  titleLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DailyTrackStatEntity,
    DailyTrackStatEntity,
    QAfterFilterCondition
  >
  titleBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'title',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DailyTrackStatEntity,
    DailyTrackStatEntity,
    QAfterFilterCondition
  >
  titleStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DailyTrackStatEntity,
    DailyTrackStatEntity,
    QAfterFilterCondition
  >
  titleEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DailyTrackStatEntity,
    DailyTrackStatEntity,
    QAfterFilterCondition
  >
  titleContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DailyTrackStatEntity,
    DailyTrackStatEntity,
    QAfterFilterCondition
  >
  titleMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'title',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DailyTrackStatEntity,
    DailyTrackStatEntity,
    QAfterFilterCondition
  >
  titleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'title', value: ''),
      );
    });
  }

  QueryBuilder<
    DailyTrackStatEntity,
    DailyTrackStatEntity,
    QAfterFilterCondition
  >
  titleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'title', value: ''),
      );
    });
  }

  QueryBuilder<
    DailyTrackStatEntity,
    DailyTrackStatEntity,
    QAfterFilterCondition
  >
  trackIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'trackId'),
      );
    });
  }

  QueryBuilder<
    DailyTrackStatEntity,
    DailyTrackStatEntity,
    QAfterFilterCondition
  >
  trackIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'trackId'),
      );
    });
  }

  QueryBuilder<
    DailyTrackStatEntity,
    DailyTrackStatEntity,
    QAfterFilterCondition
  >
  trackIdEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'trackId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DailyTrackStatEntity,
    DailyTrackStatEntity,
    QAfterFilterCondition
  >
  trackIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'trackId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DailyTrackStatEntity,
    DailyTrackStatEntity,
    QAfterFilterCondition
  >
  trackIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'trackId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DailyTrackStatEntity,
    DailyTrackStatEntity,
    QAfterFilterCondition
  >
  trackIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'trackId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DailyTrackStatEntity,
    DailyTrackStatEntity,
    QAfterFilterCondition
  >
  trackIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'trackId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DailyTrackStatEntity,
    DailyTrackStatEntity,
    QAfterFilterCondition
  >
  trackIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'trackId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DailyTrackStatEntity,
    DailyTrackStatEntity,
    QAfterFilterCondition
  >
  trackIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'trackId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DailyTrackStatEntity,
    DailyTrackStatEntity,
    QAfterFilterCondition
  >
  trackIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'trackId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<
    DailyTrackStatEntity,
    DailyTrackStatEntity,
    QAfterFilterCondition
  >
  trackIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'trackId', value: ''),
      );
    });
  }

  QueryBuilder<
    DailyTrackStatEntity,
    DailyTrackStatEntity,
    QAfterFilterCondition
  >
  trackIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'trackId', value: ''),
      );
    });
  }
}

extension DailyTrackStatEntityQueryObject
    on
        QueryBuilder<
          DailyTrackStatEntity,
          DailyTrackStatEntity,
          QFilterCondition
        > {}

extension DailyTrackStatEntityQueryLinks
    on
        QueryBuilder<
          DailyTrackStatEntity,
          DailyTrackStatEntity,
          QFilterCondition
        > {}

extension DailyTrackStatEntityQuerySortBy
    on QueryBuilder<DailyTrackStatEntity, DailyTrackStatEntity, QSortBy> {
  QueryBuilder<DailyTrackStatEntity, DailyTrackStatEntity, QAfterSortBy>
  sortByDay() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'day', Sort.asc);
    });
  }

  QueryBuilder<DailyTrackStatEntity, DailyTrackStatEntity, QAfterSortBy>
  sortByDayDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'day', Sort.desc);
    });
  }

  QueryBuilder<DailyTrackStatEntity, DailyTrackStatEntity, QAfterSortBy>
  sortByListenMs() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'listenMs', Sort.asc);
    });
  }

  QueryBuilder<DailyTrackStatEntity, DailyTrackStatEntity, QAfterSortBy>
  sortByListenMsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'listenMs', Sort.desc);
    });
  }

  QueryBuilder<DailyTrackStatEntity, DailyTrackStatEntity, QAfterSortBy>
  sortByPathKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pathKey', Sort.asc);
    });
  }

  QueryBuilder<DailyTrackStatEntity, DailyTrackStatEntity, QAfterSortBy>
  sortByPathKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pathKey', Sort.desc);
    });
  }

  QueryBuilder<DailyTrackStatEntity, DailyTrackStatEntity, QAfterSortBy>
  sortByPlayCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'playCount', Sort.asc);
    });
  }

  QueryBuilder<DailyTrackStatEntity, DailyTrackStatEntity, QAfterSortBy>
  sortByPlayCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'playCount', Sort.desc);
    });
  }

  QueryBuilder<DailyTrackStatEntity, DailyTrackStatEntity, QAfterSortBy>
  sortByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<DailyTrackStatEntity, DailyTrackStatEntity, QAfterSortBy>
  sortByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }

  QueryBuilder<DailyTrackStatEntity, DailyTrackStatEntity, QAfterSortBy>
  sortByTrackId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'trackId', Sort.asc);
    });
  }

  QueryBuilder<DailyTrackStatEntity, DailyTrackStatEntity, QAfterSortBy>
  sortByTrackIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'trackId', Sort.desc);
    });
  }
}

extension DailyTrackStatEntityQuerySortThenBy
    on QueryBuilder<DailyTrackStatEntity, DailyTrackStatEntity, QSortThenBy> {
  QueryBuilder<DailyTrackStatEntity, DailyTrackStatEntity, QAfterSortBy>
  thenByDay() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'day', Sort.asc);
    });
  }

  QueryBuilder<DailyTrackStatEntity, DailyTrackStatEntity, QAfterSortBy>
  thenByDayDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'day', Sort.desc);
    });
  }

  QueryBuilder<DailyTrackStatEntity, DailyTrackStatEntity, QAfterSortBy>
  thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<DailyTrackStatEntity, DailyTrackStatEntity, QAfterSortBy>
  thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<DailyTrackStatEntity, DailyTrackStatEntity, QAfterSortBy>
  thenByListenMs() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'listenMs', Sort.asc);
    });
  }

  QueryBuilder<DailyTrackStatEntity, DailyTrackStatEntity, QAfterSortBy>
  thenByListenMsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'listenMs', Sort.desc);
    });
  }

  QueryBuilder<DailyTrackStatEntity, DailyTrackStatEntity, QAfterSortBy>
  thenByPathKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pathKey', Sort.asc);
    });
  }

  QueryBuilder<DailyTrackStatEntity, DailyTrackStatEntity, QAfterSortBy>
  thenByPathKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pathKey', Sort.desc);
    });
  }

  QueryBuilder<DailyTrackStatEntity, DailyTrackStatEntity, QAfterSortBy>
  thenByPlayCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'playCount', Sort.asc);
    });
  }

  QueryBuilder<DailyTrackStatEntity, DailyTrackStatEntity, QAfterSortBy>
  thenByPlayCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'playCount', Sort.desc);
    });
  }

  QueryBuilder<DailyTrackStatEntity, DailyTrackStatEntity, QAfterSortBy>
  thenByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<DailyTrackStatEntity, DailyTrackStatEntity, QAfterSortBy>
  thenByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }

  QueryBuilder<DailyTrackStatEntity, DailyTrackStatEntity, QAfterSortBy>
  thenByTrackId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'trackId', Sort.asc);
    });
  }

  QueryBuilder<DailyTrackStatEntity, DailyTrackStatEntity, QAfterSortBy>
  thenByTrackIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'trackId', Sort.desc);
    });
  }
}

extension DailyTrackStatEntityQueryWhereDistinct
    on QueryBuilder<DailyTrackStatEntity, DailyTrackStatEntity, QDistinct> {
  QueryBuilder<DailyTrackStatEntity, DailyTrackStatEntity, QDistinct>
  distinctByDay({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'day', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DailyTrackStatEntity, DailyTrackStatEntity, QDistinct>
  distinctByListenMs() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'listenMs');
    });
  }

  QueryBuilder<DailyTrackStatEntity, DailyTrackStatEntity, QDistinct>
  distinctByPathKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'pathKey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DailyTrackStatEntity, DailyTrackStatEntity, QDistinct>
  distinctByPlayCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'playCount');
    });
  }

  QueryBuilder<DailyTrackStatEntity, DailyTrackStatEntity, QDistinct>
  distinctByTitle({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'title', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<DailyTrackStatEntity, DailyTrackStatEntity, QDistinct>
  distinctByTrackId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'trackId', caseSensitive: caseSensitive);
    });
  }
}

extension DailyTrackStatEntityQueryProperty
    on
        QueryBuilder<
          DailyTrackStatEntity,
          DailyTrackStatEntity,
          QQueryProperty
        > {
  QueryBuilder<DailyTrackStatEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<DailyTrackStatEntity, String, QQueryOperations> dayProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'day');
    });
  }

  QueryBuilder<DailyTrackStatEntity, int, QQueryOperations> listenMsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'listenMs');
    });
  }

  QueryBuilder<DailyTrackStatEntity, String, QQueryOperations>
  pathKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'pathKey');
    });
  }

  QueryBuilder<DailyTrackStatEntity, int, QQueryOperations>
  playCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'playCount');
    });
  }

  QueryBuilder<DailyTrackStatEntity, String, QQueryOperations> titleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'title');
    });
  }

  QueryBuilder<DailyTrackStatEntity, String?, QQueryOperations>
  trackIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'trackId');
    });
  }
}
