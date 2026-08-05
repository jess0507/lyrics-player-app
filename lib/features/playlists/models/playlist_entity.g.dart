// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'playlist_entity.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetPlaylistEntityCollection on Isar {
  IsarCollection<PlaylistEntity> get playlistEntitys => this.collection();
}

const PlaylistEntitySchema = CollectionSchema(
  name: r'PlaylistEntity',
  id: -2458012604133279019,
  properties: {
    r'createdAt': PropertySchema(
      id: 0,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'isFavorites': PropertySchema(
      id: 1,
      name: r'isFavorites',
      type: IsarType.bool,
    ),
    r'isRecentlyPlayed': PropertySchema(
      id: 2,
      name: r'isRecentlyPlayed',
      type: IsarType.bool,
    ),
    r'name': PropertySchema(id: 3, name: r'name', type: IsarType.string),
    r'recentlyPlayed': PropertySchema(
      id: 4,
      name: r'recentlyPlayed',
      type: IsarType.objectList,

      target: r'RecentlyPlayedEntry',
    ),
    r'trackIds': PropertySchema(
      id: 5,
      name: r'trackIds',
      type: IsarType.stringList,
    ),
  },

  estimateSize: _playlistEntityEstimateSize,
  serialize: _playlistEntitySerialize,
  deserialize: _playlistEntityDeserialize,
  deserializeProp: _playlistEntityDeserializeProp,
  idName: r'id',
  indexes: {
    r'isFavorites': IndexSchema(
      id: 2795527544278818265,
      name: r'isFavorites',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'isFavorites',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
    r'isRecentlyPlayed': IndexSchema(
      id: -810739811937279791,
      name: r'isRecentlyPlayed',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'isRecentlyPlayed',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {r'RecentlyPlayedEntry': RecentlyPlayedEntrySchema},

  getId: _playlistEntityGetId,
  getLinks: _playlistEntityGetLinks,
  attach: _playlistEntityAttach,
  version: '3.3.2',
);

int _playlistEntityEstimateSize(
  PlaylistEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.name.length * 3;
  bytesCount += 3 + object.recentlyPlayed.length * 3;
  {
    final offsets = allOffsets[RecentlyPlayedEntry]!;
    for (var i = 0; i < object.recentlyPlayed.length; i++) {
      final value = object.recentlyPlayed[i];
      bytesCount += RecentlyPlayedEntrySchema.estimateSize(
        value,
        offsets,
        allOffsets,
      );
    }
  }
  bytesCount += 3 + object.trackIds.length * 3;
  {
    for (var i = 0; i < object.trackIds.length; i++) {
      final value = object.trackIds[i];
      bytesCount += value.length * 3;
    }
  }
  return bytesCount;
}

void _playlistEntitySerialize(
  PlaylistEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.createdAt);
  writer.writeBool(offsets[1], object.isFavorites);
  writer.writeBool(offsets[2], object.isRecentlyPlayed);
  writer.writeString(offsets[3], object.name);
  writer.writeObjectList<RecentlyPlayedEntry>(
    offsets[4],
    allOffsets,
    RecentlyPlayedEntrySchema.serialize,
    object.recentlyPlayed,
  );
  writer.writeStringList(offsets[5], object.trackIds);
}

PlaylistEntity _playlistEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = PlaylistEntity();
  object.createdAt = reader.readDateTime(offsets[0]);
  object.id = id;
  object.isFavorites = reader.readBool(offsets[1]);
  object.isRecentlyPlayed = reader.readBool(offsets[2]);
  object.name = reader.readString(offsets[3]);
  object.recentlyPlayed =
      reader.readObjectList<RecentlyPlayedEntry>(
        offsets[4],
        RecentlyPlayedEntrySchema.deserialize,
        allOffsets,
        RecentlyPlayedEntry(),
      ) ??
      [];
  object.trackIds = reader.readStringList(offsets[5]) ?? [];
  return object;
}

P _playlistEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDateTime(offset)) as P;
    case 1:
      return (reader.readBool(offset)) as P;
    case 2:
      return (reader.readBool(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readObjectList<RecentlyPlayedEntry>(
                offset,
                RecentlyPlayedEntrySchema.deserialize,
                allOffsets,
                RecentlyPlayedEntry(),
              ) ??
              [])
          as P;
    case 5:
      return (reader.readStringList(offset) ?? []) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _playlistEntityGetId(PlaylistEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _playlistEntityGetLinks(PlaylistEntity object) {
  return [];
}

void _playlistEntityAttach(
  IsarCollection<dynamic> col,
  Id id,
  PlaylistEntity object,
) {
  object.id = id;
}

extension PlaylistEntityQueryWhereSort
    on QueryBuilder<PlaylistEntity, PlaylistEntity, QWhere> {
  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterWhere> anyIsFavorites() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'isFavorites'),
      );
    });
  }

  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterWhere>
  anyIsRecentlyPlayed() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'isRecentlyPlayed'),
      );
    });
  }
}

extension PlaylistEntityQueryWhere
    on QueryBuilder<PlaylistEntity, PlaylistEntity, QWhereClause> {
  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterWhereClause> idEqualTo(
    Id id,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterWhereClause> idNotEqualTo(
    Id id,
  ) {
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

  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterWhereClause> idGreaterThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterWhereClause> idBetween(
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

  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterWhereClause>
  isFavoritesEqualTo(bool isFavorites) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'isFavorites',
          value: [isFavorites],
        ),
      );
    });
  }

  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterWhereClause>
  isFavoritesNotEqualTo(bool isFavorites) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'isFavorites',
                lower: [],
                upper: [isFavorites],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'isFavorites',
                lower: [isFavorites],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'isFavorites',
                lower: [isFavorites],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'isFavorites',
                lower: [],
                upper: [isFavorites],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterWhereClause>
  isRecentlyPlayedEqualTo(bool isRecentlyPlayed) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'isRecentlyPlayed',
          value: [isRecentlyPlayed],
        ),
      );
    });
  }

  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterWhereClause>
  isRecentlyPlayedNotEqualTo(bool isRecentlyPlayed) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'isRecentlyPlayed',
                lower: [],
                upper: [isRecentlyPlayed],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'isRecentlyPlayed',
                lower: [isRecentlyPlayed],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'isRecentlyPlayed',
                lower: [isRecentlyPlayed],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'isRecentlyPlayed',
                lower: [],
                upper: [isRecentlyPlayed],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension PlaylistEntityQueryFilter
    on QueryBuilder<PlaylistEntity, PlaylistEntity, QFilterCondition> {
  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterFilterCondition>
  createdAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'createdAt', value: value),
      );
    });
  }

  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterFilterCondition>
  createdAtGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'createdAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterFilterCondition>
  createdAtLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'createdAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterFilterCondition>
  createdAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'createdAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterFilterCondition> idEqualTo(
    Id value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterFilterCondition>
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

  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterFilterCondition>
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

  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterFilterCondition> idBetween(
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

  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterFilterCondition>
  isFavoritesEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isFavorites', value: value),
      );
    });
  }

  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterFilterCondition>
  isRecentlyPlayedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'isRecentlyPlayed', value: value),
      );
    });
  }

  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterFilterCondition>
  nameEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterFilterCondition>
  nameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterFilterCondition>
  nameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterFilterCondition>
  nameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'name',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterFilterCondition>
  nameStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterFilterCondition>
  nameEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterFilterCondition>
  nameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'name',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterFilterCondition>
  nameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'name',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterFilterCondition>
  nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'name', value: ''),
      );
    });
  }

  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterFilterCondition>
  nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'name', value: ''),
      );
    });
  }

  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterFilterCondition>
  recentlyPlayedLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'recentlyPlayed', length, true, length, true);
    });
  }

  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterFilterCondition>
  recentlyPlayedIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'recentlyPlayed', 0, true, 0, true);
    });
  }

  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterFilterCondition>
  recentlyPlayedIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'recentlyPlayed', 0, false, 999999, true);
    });
  }

  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterFilterCondition>
  recentlyPlayedLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'recentlyPlayed', 0, true, length, include);
    });
  }

  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterFilterCondition>
  recentlyPlayedLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'recentlyPlayed', length, include, 999999, true);
    });
  }

  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterFilterCondition>
  recentlyPlayedLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'recentlyPlayed',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterFilterCondition>
  trackIdsElementEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'trackIds',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterFilterCondition>
  trackIdsElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'trackIds',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterFilterCondition>
  trackIdsElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'trackIds',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterFilterCondition>
  trackIdsElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'trackIds',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterFilterCondition>
  trackIdsElementStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'trackIds',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterFilterCondition>
  trackIdsElementEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'trackIds',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterFilterCondition>
  trackIdsElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'trackIds',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterFilterCondition>
  trackIdsElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'trackIds',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterFilterCondition>
  trackIdsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'trackIds', value: ''),
      );
    });
  }

  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterFilterCondition>
  trackIdsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'trackIds', value: ''),
      );
    });
  }

  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterFilterCondition>
  trackIdsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'trackIds', length, true, length, true);
    });
  }

  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterFilterCondition>
  trackIdsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'trackIds', 0, true, 0, true);
    });
  }

  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterFilterCondition>
  trackIdsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'trackIds', 0, false, 999999, true);
    });
  }

  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterFilterCondition>
  trackIdsLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'trackIds', 0, true, length, include);
    });
  }

  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterFilterCondition>
  trackIdsLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'trackIds', length, include, 999999, true);
    });
  }

  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterFilterCondition>
  trackIdsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'trackIds',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }
}

extension PlaylistEntityQueryObject
    on QueryBuilder<PlaylistEntity, PlaylistEntity, QFilterCondition> {
  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterFilterCondition>
  recentlyPlayedElement(FilterQuery<RecentlyPlayedEntry> q) {
    return QueryBuilder.apply(this, (query) {
      return query.object(q, r'recentlyPlayed');
    });
  }
}

extension PlaylistEntityQueryLinks
    on QueryBuilder<PlaylistEntity, PlaylistEntity, QFilterCondition> {}

extension PlaylistEntityQuerySortBy
    on QueryBuilder<PlaylistEntity, PlaylistEntity, QSortBy> {
  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterSortBy>
  sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterSortBy>
  sortByIsFavorites() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isFavorites', Sort.asc);
    });
  }

  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterSortBy>
  sortByIsFavoritesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isFavorites', Sort.desc);
    });
  }

  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterSortBy>
  sortByIsRecentlyPlayed() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isRecentlyPlayed', Sort.asc);
    });
  }

  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterSortBy>
  sortByIsRecentlyPlayedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isRecentlyPlayed', Sort.desc);
    });
  }

  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterSortBy> sortByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterSortBy> sortByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }
}

extension PlaylistEntityQuerySortThenBy
    on QueryBuilder<PlaylistEntity, PlaylistEntity, QSortThenBy> {
  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterSortBy>
  thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterSortBy>
  thenByIsFavorites() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isFavorites', Sort.asc);
    });
  }

  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterSortBy>
  thenByIsFavoritesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isFavorites', Sort.desc);
    });
  }

  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterSortBy>
  thenByIsRecentlyPlayed() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isRecentlyPlayed', Sort.asc);
    });
  }

  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterSortBy>
  thenByIsRecentlyPlayedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isRecentlyPlayed', Sort.desc);
    });
  }

  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterSortBy> thenByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<PlaylistEntity, PlaylistEntity, QAfterSortBy> thenByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }
}

extension PlaylistEntityQueryWhereDistinct
    on QueryBuilder<PlaylistEntity, PlaylistEntity, QDistinct> {
  QueryBuilder<PlaylistEntity, PlaylistEntity, QDistinct>
  distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<PlaylistEntity, PlaylistEntity, QDistinct>
  distinctByIsFavorites() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isFavorites');
    });
  }

  QueryBuilder<PlaylistEntity, PlaylistEntity, QDistinct>
  distinctByIsRecentlyPlayed() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isRecentlyPlayed');
    });
  }

  QueryBuilder<PlaylistEntity, PlaylistEntity, QDistinct> distinctByName({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'name', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<PlaylistEntity, PlaylistEntity, QDistinct> distinctByTrackIds() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'trackIds');
    });
  }
}

extension PlaylistEntityQueryProperty
    on QueryBuilder<PlaylistEntity, PlaylistEntity, QQueryProperty> {
  QueryBuilder<PlaylistEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<PlaylistEntity, DateTime, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<PlaylistEntity, bool, QQueryOperations> isFavoritesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isFavorites');
    });
  }

  QueryBuilder<PlaylistEntity, bool, QQueryOperations>
  isRecentlyPlayedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isRecentlyPlayed');
    });
  }

  QueryBuilder<PlaylistEntity, String, QQueryOperations> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'name');
    });
  }

  QueryBuilder<PlaylistEntity, List<RecentlyPlayedEntry>, QQueryOperations>
  recentlyPlayedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'recentlyPlayed');
    });
  }

  QueryBuilder<PlaylistEntity, List<String>, QQueryOperations>
  trackIdsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'trackIds');
    });
  }
}

// **************************************************************************
// IsarEmbeddedGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

const RecentlyPlayedEntrySchema = Schema(
  name: r'RecentlyPlayedEntry',
  id: -5037548687610361551,
  properties: {
    r'playedAt': PropertySchema(
      id: 0,
      name: r'playedAt',
      type: IsarType.dateTime,
    ),
    r'trackId': PropertySchema(id: 1, name: r'trackId', type: IsarType.string),
  },

  estimateSize: _recentlyPlayedEntryEstimateSize,
  serialize: _recentlyPlayedEntrySerialize,
  deserialize: _recentlyPlayedEntryDeserialize,
  deserializeProp: _recentlyPlayedEntryDeserializeProp,
);

int _recentlyPlayedEntryEstimateSize(
  RecentlyPlayedEntry object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.trackId.length * 3;
  return bytesCount;
}

void _recentlyPlayedEntrySerialize(
  RecentlyPlayedEntry object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.playedAt);
  writer.writeString(offsets[1], object.trackId);
}

RecentlyPlayedEntry _recentlyPlayedEntryDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = RecentlyPlayedEntry();
  object.playedAt = reader.readDateTime(offsets[0]);
  object.trackId = reader.readString(offsets[1]);
  return object;
}

P _recentlyPlayedEntryDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDateTime(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

extension RecentlyPlayedEntryQueryFilter
    on
        QueryBuilder<
          RecentlyPlayedEntry,
          RecentlyPlayedEntry,
          QFilterCondition
        > {
  QueryBuilder<RecentlyPlayedEntry, RecentlyPlayedEntry, QAfterFilterCondition>
  playedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'playedAt', value: value),
      );
    });
  }

  QueryBuilder<RecentlyPlayedEntry, RecentlyPlayedEntry, QAfterFilterCondition>
  playedAtGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'playedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<RecentlyPlayedEntry, RecentlyPlayedEntry, QAfterFilterCondition>
  playedAtLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'playedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<RecentlyPlayedEntry, RecentlyPlayedEntry, QAfterFilterCondition>
  playedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'playedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<RecentlyPlayedEntry, RecentlyPlayedEntry, QAfterFilterCondition>
  trackIdEqualTo(String value, {bool caseSensitive = true}) {
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

  QueryBuilder<RecentlyPlayedEntry, RecentlyPlayedEntry, QAfterFilterCondition>
  trackIdGreaterThan(
    String value, {
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

  QueryBuilder<RecentlyPlayedEntry, RecentlyPlayedEntry, QAfterFilterCondition>
  trackIdLessThan(
    String value, {
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

  QueryBuilder<RecentlyPlayedEntry, RecentlyPlayedEntry, QAfterFilterCondition>
  trackIdBetween(
    String lower,
    String upper, {
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

  QueryBuilder<RecentlyPlayedEntry, RecentlyPlayedEntry, QAfterFilterCondition>
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

  QueryBuilder<RecentlyPlayedEntry, RecentlyPlayedEntry, QAfterFilterCondition>
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

  QueryBuilder<RecentlyPlayedEntry, RecentlyPlayedEntry, QAfterFilterCondition>
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

  QueryBuilder<RecentlyPlayedEntry, RecentlyPlayedEntry, QAfterFilterCondition>
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

  QueryBuilder<RecentlyPlayedEntry, RecentlyPlayedEntry, QAfterFilterCondition>
  trackIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'trackId', value: ''),
      );
    });
  }

  QueryBuilder<RecentlyPlayedEntry, RecentlyPlayedEntry, QAfterFilterCondition>
  trackIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'trackId', value: ''),
      );
    });
  }
}

extension RecentlyPlayedEntryQueryObject
    on
        QueryBuilder<
          RecentlyPlayedEntry,
          RecentlyPlayedEntry,
          QFilterCondition
        > {}
