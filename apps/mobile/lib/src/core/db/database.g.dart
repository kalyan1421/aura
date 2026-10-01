// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $CheckInsTable extends CheckIns
    with TableInfo<$CheckInsTable, CheckInRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CheckInsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _moodIdMeta = const VerificationMeta('moodId');
  @override
  late final GeneratedColumn<String> moodId = GeneratedColumn<String>(
    'mood_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quadrantMeta = const VerificationMeta(
    'quadrant',
  );
  @override
  late final GeneratedColumn<String> quadrant = GeneratedColumn<String>(
    'quadrant',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String> tags =
      GeneratedColumn<String>(
        'tags',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      ).withConverter<List<String>>($CheckInsTable.$convertertags);
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localDayMeta = const VerificationMeta(
    'localDay',
  );
  @override
  late final GeneratedColumn<String> localDay = GeneratedColumn<String>(
    'local_day',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceTsMeta = const VerificationMeta(
    'deviceTs',
  );
  @override
  late final GeneratedColumn<DateTime> deviceTs = GeneratedColumn<DateTime>(
    'device_ts',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tzOffsetMinutesMeta = const VerificationMeta(
    'tzOffsetMinutes',
  );
  @override
  late final GeneratedColumn<int> tzOffsetMinutes = GeneratedColumn<int>(
    'tz_offset_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tzMeta = const VerificationMeta('tz');
  @override
  late final GeneratedColumn<String> tz = GeneratedColumn<String>(
    'tz',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('app'),
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncedMeta = const VerificationMeta('synced');
  @override
  late final GeneratedColumn<bool> synced = GeneratedColumn<bool>(
    'synced',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("synced" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _noteLockedMeta = const VerificationMeta(
    'noteLocked',
  );
  @override
  late final GeneratedColumn<bool> noteLocked = GeneratedColumn<bool>(
    'note_locked',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("note_locked" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _voiceFileMeta = const VerificationMeta(
    'voiceFile',
  );
  @override
  late final GeneratedColumn<String> voiceFile = GeneratedColumn<String>(
    'voice_file',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _voiceMsMeta = const VerificationMeta(
    'voiceMs',
  );
  @override
  late final GeneratedColumn<int> voiceMs = GeneratedColumn<int>(
    'voice_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _voicePathMeta = const VerificationMeta(
    'voicePath',
  );
  @override
  late final GeneratedColumn<String> voicePath = GeneratedColumn<String>(
    'voice_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    moodId,
    quadrant,
    tags,
    note,
    localDay,
    deviceTs,
    tzOffsetMinutes,
    tz,
    source,
    deletedAt,
    synced,
    noteLocked,
    voiceFile,
    voiceMs,
    voicePath,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'check_ins';
  @override
  VerificationContext validateIntegrity(
    Insertable<CheckInRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('mood_id')) {
      context.handle(
        _moodIdMeta,
        moodId.isAcceptableOrUnknown(data['mood_id']!, _moodIdMeta),
      );
    } else if (isInserting) {
      context.missing(_moodIdMeta);
    }
    if (data.containsKey('quadrant')) {
      context.handle(
        _quadrantMeta,
        quadrant.isAcceptableOrUnknown(data['quadrant']!, _quadrantMeta),
      );
    } else if (isInserting) {
      context.missing(_quadrantMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('local_day')) {
      context.handle(
        _localDayMeta,
        localDay.isAcceptableOrUnknown(data['local_day']!, _localDayMeta),
      );
    } else if (isInserting) {
      context.missing(_localDayMeta);
    }
    if (data.containsKey('device_ts')) {
      context.handle(
        _deviceTsMeta,
        deviceTs.isAcceptableOrUnknown(data['device_ts']!, _deviceTsMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceTsMeta);
    }
    if (data.containsKey('tz_offset_minutes')) {
      context.handle(
        _tzOffsetMinutesMeta,
        tzOffsetMinutes.isAcceptableOrUnknown(
          data['tz_offset_minutes']!,
          _tzOffsetMinutesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_tzOffsetMinutesMeta);
    }
    if (data.containsKey('tz')) {
      context.handle(_tzMeta, tz.isAcceptableOrUnknown(data['tz']!, _tzMeta));
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('synced')) {
      context.handle(
        _syncedMeta,
        synced.isAcceptableOrUnknown(data['synced']!, _syncedMeta),
      );
    }
    if (data.containsKey('note_locked')) {
      context.handle(
        _noteLockedMeta,
        noteLocked.isAcceptableOrUnknown(data['note_locked']!, _noteLockedMeta),
      );
    }
    if (data.containsKey('voice_file')) {
      context.handle(
        _voiceFileMeta,
        voiceFile.isAcceptableOrUnknown(data['voice_file']!, _voiceFileMeta),
      );
    }
    if (data.containsKey('voice_ms')) {
      context.handle(
        _voiceMsMeta,
        voiceMs.isAcceptableOrUnknown(data['voice_ms']!, _voiceMsMeta),
      );
    }
    if (data.containsKey('voice_path')) {
      context.handle(
        _voicePathMeta,
        voicePath.isAcceptableOrUnknown(data['voice_path']!, _voicePathMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CheckInRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CheckInRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      moodId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mood_id'],
      )!,
      quadrant: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}quadrant'],
      )!,
      tags: $CheckInsTable.$convertertags.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}tags'],
        )!,
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      localDay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_day'],
      )!,
      deviceTs: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}device_ts'],
      )!,
      tzOffsetMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tz_offset_minutes'],
      )!,
      tz: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tz'],
      ),
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      synced: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}synced'],
      )!,
      noteLocked: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}note_locked'],
      )!,
      voiceFile: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}voice_file'],
      ),
      voiceMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}voice_ms'],
      ),
      voicePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}voice_path'],
      ),
    );
  }

  @override
  $CheckInsTable createAlias(String alias) {
    return $CheckInsTable(attachedDatabase, alias);
  }

  static TypeConverter<List<String>, String> $convertertags =
      const StringListConverter();
}

class CheckInRow extends DataClass implements Insertable<CheckInRow> {
  final String id;
  final String moodId;
  final String quadrant;
  final List<String> tags;
  final String? note;

  /// Aura day (`YYYY-MM-DD`, 04:00 rollover), set on device, never recomputed.
  final String localDay;
  final DateTime deviceTs;
  final int tzOffsetMinutes;

  /// IANA zone the day was stamped in (schema v2). `null` for rows pulled
  /// from the server.
  final String? tz;
  final String source;

  /// Tombstone; deleting keeps Starlight and glow days.
  final DateTime? deletedAt;

  /// True once the server acknowledged it (or it came from a pull).
  final bool synced;

  /// The server holds an encrypted note this phone can't read yet (pulled
  /// before the data key arrived, or undecryptable). An edit rewrites the
  /// server's note, so editing waits until the note is readable here
  /// (schema v3).
  final bool noteLocked;

  /// This phone's copy of the voice note: a file name inside the app's
  /// private, backup-excluded voice directory (`VoiceStore`). `<rec>.enc` is
  /// sealed with the per-user data key (DS-1); `<rec>.m4a` is raw and only
  /// exists until a data key is on this phone. `null` when there is no local
  /// copy (none, or pulled from the server: played by downloading).
  final String? voiceFile;

  /// Recorded length in milliseconds, for display (`null` when unknown, e.g.
  /// a pulled voice note that hasn't been played here).
  final int? voiceMs;

  /// The server object holding the current recording
  /// (`<user_id>/voice/<id>`, the upload's `path` verbatim): set once the
  /// upload succeeded, or by a pull. `null` while the current local
  /// recording is not uploaded yet (or there is no voice note).
  final String? voicePath;
  const CheckInRow({
    required this.id,
    required this.moodId,
    required this.quadrant,
    required this.tags,
    this.note,
    required this.localDay,
    required this.deviceTs,
    required this.tzOffsetMinutes,
    this.tz,
    required this.source,
    this.deletedAt,
    required this.synced,
    required this.noteLocked,
    this.voiceFile,
    this.voiceMs,
    this.voicePath,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['mood_id'] = Variable<String>(moodId);
    map['quadrant'] = Variable<String>(quadrant);
    {
      map['tags'] = Variable<String>($CheckInsTable.$convertertags.toSql(tags));
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['local_day'] = Variable<String>(localDay);
    map['device_ts'] = Variable<DateTime>(deviceTs);
    map['tz_offset_minutes'] = Variable<int>(tzOffsetMinutes);
    if (!nullToAbsent || tz != null) {
      map['tz'] = Variable<String>(tz);
    }
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['synced'] = Variable<bool>(synced);
    map['note_locked'] = Variable<bool>(noteLocked);
    if (!nullToAbsent || voiceFile != null) {
      map['voice_file'] = Variable<String>(voiceFile);
    }
    if (!nullToAbsent || voiceMs != null) {
      map['voice_ms'] = Variable<int>(voiceMs);
    }
    if (!nullToAbsent || voicePath != null) {
      map['voice_path'] = Variable<String>(voicePath);
    }
    return map;
  }

  CheckInsCompanion toCompanion(bool nullToAbsent) {
    return CheckInsCompanion(
      id: Value(id),
      moodId: Value(moodId),
      quadrant: Value(quadrant),
      tags: Value(tags),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      localDay: Value(localDay),
      deviceTs: Value(deviceTs),
      tzOffsetMinutes: Value(tzOffsetMinutes),
      tz: tz == null && nullToAbsent ? const Value.absent() : Value(tz),
      source: Value(source),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      synced: Value(synced),
      noteLocked: Value(noteLocked),
      voiceFile: voiceFile == null && nullToAbsent
          ? const Value.absent()
          : Value(voiceFile),
      voiceMs: voiceMs == null && nullToAbsent
          ? const Value.absent()
          : Value(voiceMs),
      voicePath: voicePath == null && nullToAbsent
          ? const Value.absent()
          : Value(voicePath),
    );
  }

  factory CheckInRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CheckInRow(
      id: serializer.fromJson<String>(json['id']),
      moodId: serializer.fromJson<String>(json['moodId']),
      quadrant: serializer.fromJson<String>(json['quadrant']),
      tags: serializer.fromJson<List<String>>(json['tags']),
      note: serializer.fromJson<String?>(json['note']),
      localDay: serializer.fromJson<String>(json['localDay']),
      deviceTs: serializer.fromJson<DateTime>(json['deviceTs']),
      tzOffsetMinutes: serializer.fromJson<int>(json['tzOffsetMinutes']),
      tz: serializer.fromJson<String?>(json['tz']),
      source: serializer.fromJson<String>(json['source']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      synced: serializer.fromJson<bool>(json['synced']),
      noteLocked: serializer.fromJson<bool>(json['noteLocked']),
      voiceFile: serializer.fromJson<String?>(json['voiceFile']),
      voiceMs: serializer.fromJson<int?>(json['voiceMs']),
      voicePath: serializer.fromJson<String?>(json['voicePath']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'moodId': serializer.toJson<String>(moodId),
      'quadrant': serializer.toJson<String>(quadrant),
      'tags': serializer.toJson<List<String>>(tags),
      'note': serializer.toJson<String?>(note),
      'localDay': serializer.toJson<String>(localDay),
      'deviceTs': serializer.toJson<DateTime>(deviceTs),
      'tzOffsetMinutes': serializer.toJson<int>(tzOffsetMinutes),
      'tz': serializer.toJson<String?>(tz),
      'source': serializer.toJson<String>(source),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'synced': serializer.toJson<bool>(synced),
      'noteLocked': serializer.toJson<bool>(noteLocked),
      'voiceFile': serializer.toJson<String?>(voiceFile),
      'voiceMs': serializer.toJson<int?>(voiceMs),
      'voicePath': serializer.toJson<String?>(voicePath),
    };
  }

  CheckInRow copyWith({
    String? id,
    String? moodId,
    String? quadrant,
    List<String>? tags,
    Value<String?> note = const Value.absent(),
    String? localDay,
    DateTime? deviceTs,
    int? tzOffsetMinutes,
    Value<String?> tz = const Value.absent(),
    String? source,
    Value<DateTime?> deletedAt = const Value.absent(),
    bool? synced,
    bool? noteLocked,
    Value<String?> voiceFile = const Value.absent(),
    Value<int?> voiceMs = const Value.absent(),
    Value<String?> voicePath = const Value.absent(),
  }) => CheckInRow(
    id: id ?? this.id,
    moodId: moodId ?? this.moodId,
    quadrant: quadrant ?? this.quadrant,
    tags: tags ?? this.tags,
    note: note.present ? note.value : this.note,
    localDay: localDay ?? this.localDay,
    deviceTs: deviceTs ?? this.deviceTs,
    tzOffsetMinutes: tzOffsetMinutes ?? this.tzOffsetMinutes,
    tz: tz.present ? tz.value : this.tz,
    source: source ?? this.source,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    synced: synced ?? this.synced,
    noteLocked: noteLocked ?? this.noteLocked,
    voiceFile: voiceFile.present ? voiceFile.value : this.voiceFile,
    voiceMs: voiceMs.present ? voiceMs.value : this.voiceMs,
    voicePath: voicePath.present ? voicePath.value : this.voicePath,
  );
  CheckInRow copyWithCompanion(CheckInsCompanion data) {
    return CheckInRow(
      id: data.id.present ? data.id.value : this.id,
      moodId: data.moodId.present ? data.moodId.value : this.moodId,
      quadrant: data.quadrant.present ? data.quadrant.value : this.quadrant,
      tags: data.tags.present ? data.tags.value : this.tags,
      note: data.note.present ? data.note.value : this.note,
      localDay: data.localDay.present ? data.localDay.value : this.localDay,
      deviceTs: data.deviceTs.present ? data.deviceTs.value : this.deviceTs,
      tzOffsetMinutes: data.tzOffsetMinutes.present
          ? data.tzOffsetMinutes.value
          : this.tzOffsetMinutes,
      tz: data.tz.present ? data.tz.value : this.tz,
      source: data.source.present ? data.source.value : this.source,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      synced: data.synced.present ? data.synced.value : this.synced,
      noteLocked: data.noteLocked.present
          ? data.noteLocked.value
          : this.noteLocked,
      voiceFile: data.voiceFile.present ? data.voiceFile.value : this.voiceFile,
      voiceMs: data.voiceMs.present ? data.voiceMs.value : this.voiceMs,
      voicePath: data.voicePath.present ? data.voicePath.value : this.voicePath,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CheckInRow(')
          ..write('id: $id, ')
          ..write('moodId: $moodId, ')
          ..write('quadrant: $quadrant, ')
          ..write('tags: $tags, ')
          ..write('note: $note, ')
          ..write('localDay: $localDay, ')
          ..write('deviceTs: $deviceTs, ')
          ..write('tzOffsetMinutes: $tzOffsetMinutes, ')
          ..write('tz: $tz, ')
          ..write('source: $source, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('synced: $synced, ')
          ..write('noteLocked: $noteLocked, ')
          ..write('voiceFile: $voiceFile, ')
          ..write('voiceMs: $voiceMs, ')
          ..write('voicePath: $voicePath')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    moodId,
    quadrant,
    tags,
    note,
    localDay,
    deviceTs,
    tzOffsetMinutes,
    tz,
    source,
    deletedAt,
    synced,
    noteLocked,
    voiceFile,
    voiceMs,
    voicePath,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CheckInRow &&
          other.id == this.id &&
          other.moodId == this.moodId &&
          other.quadrant == this.quadrant &&
          other.tags == this.tags &&
          other.note == this.note &&
          other.localDay == this.localDay &&
          other.deviceTs == this.deviceTs &&
          other.tzOffsetMinutes == this.tzOffsetMinutes &&
          other.tz == this.tz &&
          other.source == this.source &&
          other.deletedAt == this.deletedAt &&
          other.synced == this.synced &&
          other.noteLocked == this.noteLocked &&
          other.voiceFile == this.voiceFile &&
          other.voiceMs == this.voiceMs &&
          other.voicePath == this.voicePath);
}

class CheckInsCompanion extends UpdateCompanion<CheckInRow> {
  final Value<String> id;
  final Value<String> moodId;
  final Value<String> quadrant;
  final Value<List<String>> tags;
  final Value<String?> note;
  final Value<String> localDay;
  final Value<DateTime> deviceTs;
  final Value<int> tzOffsetMinutes;
  final Value<String?> tz;
  final Value<String> source;
  final Value<DateTime?> deletedAt;
  final Value<bool> synced;
  final Value<bool> noteLocked;
  final Value<String?> voiceFile;
  final Value<int?> voiceMs;
  final Value<String?> voicePath;
  final Value<int> rowid;
  const CheckInsCompanion({
    this.id = const Value.absent(),
    this.moodId = const Value.absent(),
    this.quadrant = const Value.absent(),
    this.tags = const Value.absent(),
    this.note = const Value.absent(),
    this.localDay = const Value.absent(),
    this.deviceTs = const Value.absent(),
    this.tzOffsetMinutes = const Value.absent(),
    this.tz = const Value.absent(),
    this.source = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.synced = const Value.absent(),
    this.noteLocked = const Value.absent(),
    this.voiceFile = const Value.absent(),
    this.voiceMs = const Value.absent(),
    this.voicePath = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CheckInsCompanion.insert({
    required String id,
    required String moodId,
    required String quadrant,
    this.tags = const Value.absent(),
    this.note = const Value.absent(),
    required String localDay,
    required DateTime deviceTs,
    required int tzOffsetMinutes,
    this.tz = const Value.absent(),
    this.source = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.synced = const Value.absent(),
    this.noteLocked = const Value.absent(),
    this.voiceFile = const Value.absent(),
    this.voiceMs = const Value.absent(),
    this.voicePath = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       moodId = Value(moodId),
       quadrant = Value(quadrant),
       localDay = Value(localDay),
       deviceTs = Value(deviceTs),
       tzOffsetMinutes = Value(tzOffsetMinutes);
  static Insertable<CheckInRow> custom({
    Expression<String>? id,
    Expression<String>? moodId,
    Expression<String>? quadrant,
    Expression<String>? tags,
    Expression<String>? note,
    Expression<String>? localDay,
    Expression<DateTime>? deviceTs,
    Expression<int>? tzOffsetMinutes,
    Expression<String>? tz,
    Expression<String>? source,
    Expression<DateTime>? deletedAt,
    Expression<bool>? synced,
    Expression<bool>? noteLocked,
    Expression<String>? voiceFile,
    Expression<int>? voiceMs,
    Expression<String>? voicePath,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (moodId != null) 'mood_id': moodId,
      if (quadrant != null) 'quadrant': quadrant,
      if (tags != null) 'tags': tags,
      if (note != null) 'note': note,
      if (localDay != null) 'local_day': localDay,
      if (deviceTs != null) 'device_ts': deviceTs,
      if (tzOffsetMinutes != null) 'tz_offset_minutes': tzOffsetMinutes,
      if (tz != null) 'tz': tz,
      if (source != null) 'source': source,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (synced != null) 'synced': synced,
      if (noteLocked != null) 'note_locked': noteLocked,
      if (voiceFile != null) 'voice_file': voiceFile,
      if (voiceMs != null) 'voice_ms': voiceMs,
      if (voicePath != null) 'voice_path': voicePath,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CheckInsCompanion copyWith({
    Value<String>? id,
    Value<String>? moodId,
    Value<String>? quadrant,
    Value<List<String>>? tags,
    Value<String?>? note,
    Value<String>? localDay,
    Value<DateTime>? deviceTs,
    Value<int>? tzOffsetMinutes,
    Value<String?>? tz,
    Value<String>? source,
    Value<DateTime?>? deletedAt,
    Value<bool>? synced,
    Value<bool>? noteLocked,
    Value<String?>? voiceFile,
    Value<int?>? voiceMs,
    Value<String?>? voicePath,
    Value<int>? rowid,
  }) {
    return CheckInsCompanion(
      id: id ?? this.id,
      moodId: moodId ?? this.moodId,
      quadrant: quadrant ?? this.quadrant,
      tags: tags ?? this.tags,
      note: note ?? this.note,
      localDay: localDay ?? this.localDay,
      deviceTs: deviceTs ?? this.deviceTs,
      tzOffsetMinutes: tzOffsetMinutes ?? this.tzOffsetMinutes,
      tz: tz ?? this.tz,
      source: source ?? this.source,
      deletedAt: deletedAt ?? this.deletedAt,
      synced: synced ?? this.synced,
      noteLocked: noteLocked ?? this.noteLocked,
      voiceFile: voiceFile ?? this.voiceFile,
      voiceMs: voiceMs ?? this.voiceMs,
      voicePath: voicePath ?? this.voicePath,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (moodId.present) {
      map['mood_id'] = Variable<String>(moodId.value);
    }
    if (quadrant.present) {
      map['quadrant'] = Variable<String>(quadrant.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(
        $CheckInsTable.$convertertags.toSql(tags.value),
      );
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (localDay.present) {
      map['local_day'] = Variable<String>(localDay.value);
    }
    if (deviceTs.present) {
      map['device_ts'] = Variable<DateTime>(deviceTs.value);
    }
    if (tzOffsetMinutes.present) {
      map['tz_offset_minutes'] = Variable<int>(tzOffsetMinutes.value);
    }
    if (tz.present) {
      map['tz'] = Variable<String>(tz.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (synced.present) {
      map['synced'] = Variable<bool>(synced.value);
    }
    if (noteLocked.present) {
      map['note_locked'] = Variable<bool>(noteLocked.value);
    }
    if (voiceFile.present) {
      map['voice_file'] = Variable<String>(voiceFile.value);
    }
    if (voiceMs.present) {
      map['voice_ms'] = Variable<int>(voiceMs.value);
    }
    if (voicePath.present) {
      map['voice_path'] = Variable<String>(voicePath.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CheckInsCompanion(')
          ..write('id: $id, ')
          ..write('moodId: $moodId, ')
          ..write('quadrant: $quadrant, ')
          ..write('tags: $tags, ')
          ..write('note: $note, ')
          ..write('localDay: $localDay, ')
          ..write('deviceTs: $deviceTs, ')
          ..write('tzOffsetMinutes: $tzOffsetMinutes, ')
          ..write('tz: $tz, ')
          ..write('source: $source, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('synced: $synced, ')
          ..write('noteLocked: $noteLocked, ')
          ..write('voiceFile: $voiceFile, ')
          ..write('voiceMs: $voiceMs, ')
          ..write('voicePath: $voicePath, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HabitsTable extends Habits with TableInfo<$HabitsTable, HabitRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HabitsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _presetKeyMeta = const VerificationMeta(
    'presetKey',
  );
  @override
  late final GeneratedColumn<String> presetKey = GeneratedColumn<String>(
    'preset_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _activeMeta = const VerificationMeta('active');
  @override
  late final GeneratedColumn<bool> active = GeneratedColumn<bool>(
    'active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncedMeta = const VerificationMeta('synced');
  @override
  late final GeneratedColumn<bool> synced = GeneratedColumn<bool>(
    'synced',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("synced" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _committedFromMeta = const VerificationMeta(
    'committedFrom',
  );
  @override
  late final GeneratedColumn<String> committedFrom = GeneratedColumn<String>(
    'committed_from',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pausedThroughMeta = const VerificationMeta(
    'pausedThrough',
  );
  @override
  late final GeneratedColumn<String> pausedThrough = GeneratedColumn<String>(
    'paused_through',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    presetKey,
    name,
    active,
    createdAt,
    updatedAt,
    synced,
    committedFrom,
    pausedThrough,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'habits';
  @override
  VerificationContext validateIntegrity(
    Insertable<HabitRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('preset_key')) {
      context.handle(
        _presetKeyMeta,
        presetKey.isAcceptableOrUnknown(data['preset_key']!, _presetKeyMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('active')) {
      context.handle(
        _activeMeta,
        active.isAcceptableOrUnknown(data['active']!, _activeMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('synced')) {
      context.handle(
        _syncedMeta,
        synced.isAcceptableOrUnknown(data['synced']!, _syncedMeta),
      );
    }
    if (data.containsKey('committed_from')) {
      context.handle(
        _committedFromMeta,
        committedFrom.isAcceptableOrUnknown(
          data['committed_from']!,
          _committedFromMeta,
        ),
      );
    }
    if (data.containsKey('paused_through')) {
      context.handle(
        _pausedThroughMeta,
        pausedThrough.isAcceptableOrUnknown(
          data['paused_through']!,
          _pausedThroughMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HabitRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HabitRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      presetKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preset_key'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      active: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}active'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      synced: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}synced'],
      )!,
      committedFrom: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}committed_from'],
      ),
      pausedThrough: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}paused_through'],
      ),
    );
  }

  @override
  $HabitsTable createAlias(String alias) {
    return $HabitsTable(attachedDatabase, alias);
  }
}

class HabitRow extends DataClass implements Insertable<HabitRow> {
  final String id;
  final String kind;
  final String? presetKey;
  final String? name;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool synced;

  /// W02 (RULES.md section 13): the Aura day (`YYYY-MM-DD`) the person chose
  /// "treat this as a commitment"; `null` = not a commitment, never decays.
  /// Schema v6.
  final String? committedFrom;

  /// W02: a person-chosen pause; needs [committedFrom]. Schema v6.
  final String? pausedThrough;
  const HabitRow({
    required this.id,
    required this.kind,
    this.presetKey,
    this.name,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
    required this.synced,
    this.committedFrom,
    this.pausedThrough,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || presetKey != null) {
      map['preset_key'] = Variable<String>(presetKey);
    }
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    map['active'] = Variable<bool>(active);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['synced'] = Variable<bool>(synced);
    if (!nullToAbsent || committedFrom != null) {
      map['committed_from'] = Variable<String>(committedFrom);
    }
    if (!nullToAbsent || pausedThrough != null) {
      map['paused_through'] = Variable<String>(pausedThrough);
    }
    return map;
  }

  HabitsCompanion toCompanion(bool nullToAbsent) {
    return HabitsCompanion(
      id: Value(id),
      kind: Value(kind),
      presetKey: presetKey == null && nullToAbsent
          ? const Value.absent()
          : Value(presetKey),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      active: Value(active),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      synced: Value(synced),
      committedFrom: committedFrom == null && nullToAbsent
          ? const Value.absent()
          : Value(committedFrom),
      pausedThrough: pausedThrough == null && nullToAbsent
          ? const Value.absent()
          : Value(pausedThrough),
    );
  }

  factory HabitRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HabitRow(
      id: serializer.fromJson<String>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      presetKey: serializer.fromJson<String?>(json['presetKey']),
      name: serializer.fromJson<String?>(json['name']),
      active: serializer.fromJson<bool>(json['active']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      synced: serializer.fromJson<bool>(json['synced']),
      committedFrom: serializer.fromJson<String?>(json['committedFrom']),
      pausedThrough: serializer.fromJson<String?>(json['pausedThrough']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(kind),
      'presetKey': serializer.toJson<String?>(presetKey),
      'name': serializer.toJson<String?>(name),
      'active': serializer.toJson<bool>(active),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'synced': serializer.toJson<bool>(synced),
      'committedFrom': serializer.toJson<String?>(committedFrom),
      'pausedThrough': serializer.toJson<String?>(pausedThrough),
    };
  }

  HabitRow copyWith({
    String? id,
    String? kind,
    Value<String?> presetKey = const Value.absent(),
    Value<String?> name = const Value.absent(),
    bool? active,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? synced,
    Value<String?> committedFrom = const Value.absent(),
    Value<String?> pausedThrough = const Value.absent(),
  }) => HabitRow(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    presetKey: presetKey.present ? presetKey.value : this.presetKey,
    name: name.present ? name.value : this.name,
    active: active ?? this.active,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    synced: synced ?? this.synced,
    committedFrom: committedFrom.present
        ? committedFrom.value
        : this.committedFrom,
    pausedThrough: pausedThrough.present
        ? pausedThrough.value
        : this.pausedThrough,
  );
  HabitRow copyWithCompanion(HabitsCompanion data) {
    return HabitRow(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      presetKey: data.presetKey.present ? data.presetKey.value : this.presetKey,
      name: data.name.present ? data.name.value : this.name,
      active: data.active.present ? data.active.value : this.active,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      synced: data.synced.present ? data.synced.value : this.synced,
      committedFrom: data.committedFrom.present
          ? data.committedFrom.value
          : this.committedFrom,
      pausedThrough: data.pausedThrough.present
          ? data.pausedThrough.value
          : this.pausedThrough,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HabitRow(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('presetKey: $presetKey, ')
          ..write('name: $name, ')
          ..write('active: $active, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('synced: $synced, ')
          ..write('committedFrom: $committedFrom, ')
          ..write('pausedThrough: $pausedThrough')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    presetKey,
    name,
    active,
    createdAt,
    updatedAt,
    synced,
    committedFrom,
    pausedThrough,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HabitRow &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.presetKey == this.presetKey &&
          other.name == this.name &&
          other.active == this.active &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.synced == this.synced &&
          other.committedFrom == this.committedFrom &&
          other.pausedThrough == this.pausedThrough);
}

class HabitsCompanion extends UpdateCompanion<HabitRow> {
  final Value<String> id;
  final Value<String> kind;
  final Value<String?> presetKey;
  final Value<String?> name;
  final Value<bool> active;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<bool> synced;
  final Value<String?> committedFrom;
  final Value<String?> pausedThrough;
  final Value<int> rowid;
  const HabitsCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.presetKey = const Value.absent(),
    this.name = const Value.absent(),
    this.active = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.synced = const Value.absent(),
    this.committedFrom = const Value.absent(),
    this.pausedThrough = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HabitsCompanion.insert({
    required String id,
    required String kind,
    this.presetKey = const Value.absent(),
    this.name = const Value.absent(),
    this.active = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.synced = const Value.absent(),
    this.committedFrom = const Value.absent(),
    this.pausedThrough = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<HabitRow> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? presetKey,
    Expression<String>? name,
    Expression<bool>? active,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<bool>? synced,
    Expression<String>? committedFrom,
    Expression<String>? pausedThrough,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (presetKey != null) 'preset_key': presetKey,
      if (name != null) 'name': name,
      if (active != null) 'active': active,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (synced != null) 'synced': synced,
      if (committedFrom != null) 'committed_from': committedFrom,
      if (pausedThrough != null) 'paused_through': pausedThrough,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HabitsCompanion copyWith({
    Value<String>? id,
    Value<String>? kind,
    Value<String?>? presetKey,
    Value<String?>? name,
    Value<bool>? active,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<bool>? synced,
    Value<String?>? committedFrom,
    Value<String?>? pausedThrough,
    Value<int>? rowid,
  }) {
    return HabitsCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      presetKey: presetKey ?? this.presetKey,
      name: name ?? this.name,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      synced: synced ?? this.synced,
      committedFrom: committedFrom ?? this.committedFrom,
      pausedThrough: pausedThrough ?? this.pausedThrough,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (presetKey.present) {
      map['preset_key'] = Variable<String>(presetKey.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (active.present) {
      map['active'] = Variable<bool>(active.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (synced.present) {
      map['synced'] = Variable<bool>(synced.value);
    }
    if (committedFrom.present) {
      map['committed_from'] = Variable<String>(committedFrom.value);
    }
    if (pausedThrough.present) {
      map['paused_through'] = Variable<String>(pausedThrough.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HabitsCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('presetKey: $presetKey, ')
          ..write('name: $name, ')
          ..write('active: $active, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('synced: $synced, ')
          ..write('committedFrom: $committedFrom, ')
          ..write('pausedThrough: $pausedThrough, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HabitLogsTable extends HabitLogs
    with TableInfo<$HabitLogsTable, HabitLogRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HabitLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _habitIdMeta = const VerificationMeta(
    'habitId',
  );
  @override
  late final GeneratedColumn<String> habitId = GeneratedColumn<String>(
    'habit_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localDayMeta = const VerificationMeta(
    'localDay',
  );
  @override
  late final GeneratedColumn<String> localDay = GeneratedColumn<String>(
    'local_day',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceTsMeta = const VerificationMeta(
    'deviceTs',
  );
  @override
  late final GeneratedColumn<DateTime> deviceTs = GeneratedColumn<DateTime>(
    'device_ts',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tzMeta = const VerificationMeta('tz');
  @override
  late final GeneratedColumn<String> tz = GeneratedColumn<String>(
    'tz',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncedMeta = const VerificationMeta('synced');
  @override
  late final GeneratedColumn<bool> synced = GeneratedColumn<bool>(
    'synced',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("synced" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    habitId,
    localDay,
    deviceTs,
    tz,
    deletedAt,
    synced,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'habit_logs';
  @override
  VerificationContext validateIntegrity(
    Insertable<HabitLogRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('habit_id')) {
      context.handle(
        _habitIdMeta,
        habitId.isAcceptableOrUnknown(data['habit_id']!, _habitIdMeta),
      );
    } else if (isInserting) {
      context.missing(_habitIdMeta);
    }
    if (data.containsKey('local_day')) {
      context.handle(
        _localDayMeta,
        localDay.isAcceptableOrUnknown(data['local_day']!, _localDayMeta),
      );
    } else if (isInserting) {
      context.missing(_localDayMeta);
    }
    if (data.containsKey('device_ts')) {
      context.handle(
        _deviceTsMeta,
        deviceTs.isAcceptableOrUnknown(data['device_ts']!, _deviceTsMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceTsMeta);
    }
    if (data.containsKey('tz')) {
      context.handle(_tzMeta, tz.isAcceptableOrUnknown(data['tz']!, _tzMeta));
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('synced')) {
      context.handle(
        _syncedMeta,
        synced.isAcceptableOrUnknown(data['synced']!, _syncedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HabitLogRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HabitLogRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      habitId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}habit_id'],
      )!,
      localDay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_day'],
      )!,
      deviceTs: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}device_ts'],
      )!,
      tz: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tz'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      synced: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}synced'],
      )!,
    );
  }

  @override
  $HabitLogsTable createAlias(String alias) {
    return $HabitLogsTable(attachedDatabase, alias);
  }
}

class HabitLogRow extends DataClass implements Insertable<HabitLogRow> {
  final String id;
  final String habitId;
  final String localDay;
  final DateTime deviceTs;

  /// IANA zone the day was stamped in (schema v2).
  final String? tz;
  final DateTime? deletedAt;
  final bool synced;
  const HabitLogRow({
    required this.id,
    required this.habitId,
    required this.localDay,
    required this.deviceTs,
    this.tz,
    this.deletedAt,
    required this.synced,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['habit_id'] = Variable<String>(habitId);
    map['local_day'] = Variable<String>(localDay);
    map['device_ts'] = Variable<DateTime>(deviceTs);
    if (!nullToAbsent || tz != null) {
      map['tz'] = Variable<String>(tz);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['synced'] = Variable<bool>(synced);
    return map;
  }

  HabitLogsCompanion toCompanion(bool nullToAbsent) {
    return HabitLogsCompanion(
      id: Value(id),
      habitId: Value(habitId),
      localDay: Value(localDay),
      deviceTs: Value(deviceTs),
      tz: tz == null && nullToAbsent ? const Value.absent() : Value(tz),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      synced: Value(synced),
    );
  }

  factory HabitLogRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HabitLogRow(
      id: serializer.fromJson<String>(json['id']),
      habitId: serializer.fromJson<String>(json['habitId']),
      localDay: serializer.fromJson<String>(json['localDay']),
      deviceTs: serializer.fromJson<DateTime>(json['deviceTs']),
      tz: serializer.fromJson<String?>(json['tz']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      synced: serializer.fromJson<bool>(json['synced']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'habitId': serializer.toJson<String>(habitId),
      'localDay': serializer.toJson<String>(localDay),
      'deviceTs': serializer.toJson<DateTime>(deviceTs),
      'tz': serializer.toJson<String?>(tz),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'synced': serializer.toJson<bool>(synced),
    };
  }

  HabitLogRow copyWith({
    String? id,
    String? habitId,
    String? localDay,
    DateTime? deviceTs,
    Value<String?> tz = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
    bool? synced,
  }) => HabitLogRow(
    id: id ?? this.id,
    habitId: habitId ?? this.habitId,
    localDay: localDay ?? this.localDay,
    deviceTs: deviceTs ?? this.deviceTs,
    tz: tz.present ? tz.value : this.tz,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    synced: synced ?? this.synced,
  );
  HabitLogRow copyWithCompanion(HabitLogsCompanion data) {
    return HabitLogRow(
      id: data.id.present ? data.id.value : this.id,
      habitId: data.habitId.present ? data.habitId.value : this.habitId,
      localDay: data.localDay.present ? data.localDay.value : this.localDay,
      deviceTs: data.deviceTs.present ? data.deviceTs.value : this.deviceTs,
      tz: data.tz.present ? data.tz.value : this.tz,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      synced: data.synced.present ? data.synced.value : this.synced,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HabitLogRow(')
          ..write('id: $id, ')
          ..write('habitId: $habitId, ')
          ..write('localDay: $localDay, ')
          ..write('deviceTs: $deviceTs, ')
          ..write('tz: $tz, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('synced: $synced')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, habitId, localDay, deviceTs, tz, deletedAt, synced);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HabitLogRow &&
          other.id == this.id &&
          other.habitId == this.habitId &&
          other.localDay == this.localDay &&
          other.deviceTs == this.deviceTs &&
          other.tz == this.tz &&
          other.deletedAt == this.deletedAt &&
          other.synced == this.synced);
}

class HabitLogsCompanion extends UpdateCompanion<HabitLogRow> {
  final Value<String> id;
  final Value<String> habitId;
  final Value<String> localDay;
  final Value<DateTime> deviceTs;
  final Value<String?> tz;
  final Value<DateTime?> deletedAt;
  final Value<bool> synced;
  final Value<int> rowid;
  const HabitLogsCompanion({
    this.id = const Value.absent(),
    this.habitId = const Value.absent(),
    this.localDay = const Value.absent(),
    this.deviceTs = const Value.absent(),
    this.tz = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.synced = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HabitLogsCompanion.insert({
    required String id,
    required String habitId,
    required String localDay,
    required DateTime deviceTs,
    this.tz = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.synced = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       habitId = Value(habitId),
       localDay = Value(localDay),
       deviceTs = Value(deviceTs);
  static Insertable<HabitLogRow> custom({
    Expression<String>? id,
    Expression<String>? habitId,
    Expression<String>? localDay,
    Expression<DateTime>? deviceTs,
    Expression<String>? tz,
    Expression<DateTime>? deletedAt,
    Expression<bool>? synced,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (habitId != null) 'habit_id': habitId,
      if (localDay != null) 'local_day': localDay,
      if (deviceTs != null) 'device_ts': deviceTs,
      if (tz != null) 'tz': tz,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (synced != null) 'synced': synced,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HabitLogsCompanion copyWith({
    Value<String>? id,
    Value<String>? habitId,
    Value<String>? localDay,
    Value<DateTime>? deviceTs,
    Value<String?>? tz,
    Value<DateTime?>? deletedAt,
    Value<bool>? synced,
    Value<int>? rowid,
  }) {
    return HabitLogsCompanion(
      id: id ?? this.id,
      habitId: habitId ?? this.habitId,
      localDay: localDay ?? this.localDay,
      deviceTs: deviceTs ?? this.deviceTs,
      tz: tz ?? this.tz,
      deletedAt: deletedAt ?? this.deletedAt,
      synced: synced ?? this.synced,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (habitId.present) {
      map['habit_id'] = Variable<String>(habitId.value);
    }
    if (localDay.present) {
      map['local_day'] = Variable<String>(localDay.value);
    }
    if (deviceTs.present) {
      map['device_ts'] = Variable<DateTime>(deviceTs.value);
    }
    if (tz.present) {
      map['tz'] = Variable<String>(tz.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (synced.present) {
      map['synced'] = Variable<bool>(synced.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HabitLogsCompanion(')
          ..write('id: $id, ')
          ..write('habitId: $habitId, ')
          ..write('localDay: $localDay, ')
          ..write('deviceTs: $deviceTs, ')
          ..write('tz: $tz, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('synced: $synced, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutboxTable extends Outbox with TableInfo<$OutboxTable, OutboxRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _mutationIdMeta = const VerificationMeta(
    'mutationId',
  );
  @override
  late final GeneratedColumn<String> mutationId = GeneratedColumn<String>(
    'mutation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _entityMeta = const VerificationMeta('entity');
  @override
  late final GeneratedColumn<String> entity = GeneratedColumn<String>(
    'entity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _opMeta = const VerificationMeta('op');
  @override
  late final GeneratedColumn<String> op = GeneratedColumn<String>(
    'op',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceTsMeta = const VerificationMeta(
    'deviceTs',
  );
  @override
  late final GeneratedColumn<DateTime> deviceTs = GeneratedColumn<DateTime>(
    'device_ts',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localDayMeta = const VerificationMeta(
    'localDay',
  );
  @override
  late final GeneratedColumn<String> localDay = GeneratedColumn<String>(
    'local_day',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tzMeta = const VerificationMeta('tz');
  @override
  late final GeneratedColumn<String> tz = GeneratedColumn<String>(
    'tz',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _needsNoteMeta = const VerificationMeta(
    'needsNote',
  );
  @override
  late final GeneratedColumn<bool> needsNote = GeneratedColumn<bool>(
    'needs_note',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("needs_note" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _nextAttemptAtMeta = const VerificationMeta(
    'nextAttemptAt',
  );
  @override
  late final GeneratedColumn<DateTime> nextAttemptAt =
      GeneratedColumn<DateTime>(
        'next_attempt_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _needsMediaMeta = const VerificationMeta(
    'needsMedia',
  );
  @override
  late final GeneratedColumn<bool> needsMedia = GeneratedColumn<bool>(
    'needs_media',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("needs_media" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _mediaAttemptsMeta = const VerificationMeta(
    'mediaAttempts',
  );
  @override
  late final GeneratedColumn<int> mediaAttempts = GeneratedColumn<int>(
    'media_attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    seq,
    mutationId,
    entity,
    op,
    entityId,
    deviceTs,
    localDay,
    tz,
    payload,
    needsNote,
    attempts,
    nextAttemptAt,
    createdAt,
    needsMedia,
    mediaAttempts,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    }
    if (data.containsKey('mutation_id')) {
      context.handle(
        _mutationIdMeta,
        mutationId.isAcceptableOrUnknown(data['mutation_id']!, _mutationIdMeta),
      );
    } else if (isInserting) {
      context.missing(_mutationIdMeta);
    }
    if (data.containsKey('entity')) {
      context.handle(
        _entityMeta,
        entity.isAcceptableOrUnknown(data['entity']!, _entityMeta),
      );
    } else if (isInserting) {
      context.missing(_entityMeta);
    }
    if (data.containsKey('op')) {
      context.handle(_opMeta, op.isAcceptableOrUnknown(data['op']!, _opMeta));
    } else if (isInserting) {
      context.missing(_opMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('device_ts')) {
      context.handle(
        _deviceTsMeta,
        deviceTs.isAcceptableOrUnknown(data['device_ts']!, _deviceTsMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceTsMeta);
    }
    if (data.containsKey('local_day')) {
      context.handle(
        _localDayMeta,
        localDay.isAcceptableOrUnknown(data['local_day']!, _localDayMeta),
      );
    } else if (isInserting) {
      context.missing(_localDayMeta);
    }
    if (data.containsKey('tz')) {
      context.handle(_tzMeta, tz.isAcceptableOrUnknown(data['tz']!, _tzMeta));
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('needs_note')) {
      context.handle(
        _needsNoteMeta,
        needsNote.isAcceptableOrUnknown(data['needs_note']!, _needsNoteMeta),
      );
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('next_attempt_at')) {
      context.handle(
        _nextAttemptAtMeta,
        nextAttemptAt.isAcceptableOrUnknown(
          data['next_attempt_at']!,
          _nextAttemptAtMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('needs_media')) {
      context.handle(
        _needsMediaMeta,
        needsMedia.isAcceptableOrUnknown(data['needs_media']!, _needsMediaMeta),
      );
    }
    if (data.containsKey('media_attempts')) {
      context.handle(
        _mediaAttemptsMeta,
        mediaAttempts.isAcceptableOrUnknown(
          data['media_attempts']!,
          _mediaAttemptsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {seq};
  @override
  OutboxRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxRow(
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      mutationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mutation_id'],
      )!,
      entity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity'],
      )!,
      op: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}op'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      deviceTs: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}device_ts'],
      )!,
      localDay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_day'],
      )!,
      tz: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tz'],
      ),
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      needsNote: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}needs_note'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      nextAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_attempt_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      needsMedia: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}needs_media'],
      )!,
      mediaAttempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}media_attempts'],
      )!,
    );
  }

  @override
  $OutboxTable createAlias(String alias) {
    return $OutboxTable(attachedDatabase, alias);
  }
}

class OutboxRow extends DataClass implements Insertable<OutboxRow> {
  final int seq;
  final String mutationId;
  final String entity;
  final String op;
  final String entityId;
  final DateTime deviceTs;
  final String localDay;

  /// IANA zone `localDay` was stamped in, sent as `tz` (schema v2).
  final String? tz;
  final String payload;
  final bool needsNote;
  final int attempts;
  final DateTime? nextAttemptAt;
  final DateTime createdAt;

  /// A `check_in` upsert that goes out only after its voice note is uploaded
  /// (schema v4, like [needsNote]): `voicePath` is filled in right before
  /// sending. Cleared when the outbox gives up on the upload — the check-in
  /// then goes without it (never blocked by media).
  final bool needsMedia;

  /// Failed upload attempts of this row's voice note (schema v4).
  final int mediaAttempts;
  const OutboxRow({
    required this.seq,
    required this.mutationId,
    required this.entity,
    required this.op,
    required this.entityId,
    required this.deviceTs,
    required this.localDay,
    this.tz,
    required this.payload,
    required this.needsNote,
    required this.attempts,
    this.nextAttemptAt,
    required this.createdAt,
    required this.needsMedia,
    required this.mediaAttempts,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['seq'] = Variable<int>(seq);
    map['mutation_id'] = Variable<String>(mutationId);
    map['entity'] = Variable<String>(entity);
    map['op'] = Variable<String>(op);
    map['entity_id'] = Variable<String>(entityId);
    map['device_ts'] = Variable<DateTime>(deviceTs);
    map['local_day'] = Variable<String>(localDay);
    if (!nullToAbsent || tz != null) {
      map['tz'] = Variable<String>(tz);
    }
    map['payload'] = Variable<String>(payload);
    map['needs_note'] = Variable<bool>(needsNote);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || nextAttemptAt != null) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['needs_media'] = Variable<bool>(needsMedia);
    map['media_attempts'] = Variable<int>(mediaAttempts);
    return map;
  }

  OutboxCompanion toCompanion(bool nullToAbsent) {
    return OutboxCompanion(
      seq: Value(seq),
      mutationId: Value(mutationId),
      entity: Value(entity),
      op: Value(op),
      entityId: Value(entityId),
      deviceTs: Value(deviceTs),
      localDay: Value(localDay),
      tz: tz == null && nullToAbsent ? const Value.absent() : Value(tz),
      payload: Value(payload),
      needsNote: Value(needsNote),
      attempts: Value(attempts),
      nextAttemptAt: nextAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextAttemptAt),
      createdAt: Value(createdAt),
      needsMedia: Value(needsMedia),
      mediaAttempts: Value(mediaAttempts),
    );
  }

  factory OutboxRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxRow(
      seq: serializer.fromJson<int>(json['seq']),
      mutationId: serializer.fromJson<String>(json['mutationId']),
      entity: serializer.fromJson<String>(json['entity']),
      op: serializer.fromJson<String>(json['op']),
      entityId: serializer.fromJson<String>(json['entityId']),
      deviceTs: serializer.fromJson<DateTime>(json['deviceTs']),
      localDay: serializer.fromJson<String>(json['localDay']),
      tz: serializer.fromJson<String?>(json['tz']),
      payload: serializer.fromJson<String>(json['payload']),
      needsNote: serializer.fromJson<bool>(json['needsNote']),
      attempts: serializer.fromJson<int>(json['attempts']),
      nextAttemptAt: serializer.fromJson<DateTime?>(json['nextAttemptAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      needsMedia: serializer.fromJson<bool>(json['needsMedia']),
      mediaAttempts: serializer.fromJson<int>(json['mediaAttempts']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'seq': serializer.toJson<int>(seq),
      'mutationId': serializer.toJson<String>(mutationId),
      'entity': serializer.toJson<String>(entity),
      'op': serializer.toJson<String>(op),
      'entityId': serializer.toJson<String>(entityId),
      'deviceTs': serializer.toJson<DateTime>(deviceTs),
      'localDay': serializer.toJson<String>(localDay),
      'tz': serializer.toJson<String?>(tz),
      'payload': serializer.toJson<String>(payload),
      'needsNote': serializer.toJson<bool>(needsNote),
      'attempts': serializer.toJson<int>(attempts),
      'nextAttemptAt': serializer.toJson<DateTime?>(nextAttemptAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'needsMedia': serializer.toJson<bool>(needsMedia),
      'mediaAttempts': serializer.toJson<int>(mediaAttempts),
    };
  }

  OutboxRow copyWith({
    int? seq,
    String? mutationId,
    String? entity,
    String? op,
    String? entityId,
    DateTime? deviceTs,
    String? localDay,
    Value<String?> tz = const Value.absent(),
    String? payload,
    bool? needsNote,
    int? attempts,
    Value<DateTime?> nextAttemptAt = const Value.absent(),
    DateTime? createdAt,
    bool? needsMedia,
    int? mediaAttempts,
  }) => OutboxRow(
    seq: seq ?? this.seq,
    mutationId: mutationId ?? this.mutationId,
    entity: entity ?? this.entity,
    op: op ?? this.op,
    entityId: entityId ?? this.entityId,
    deviceTs: deviceTs ?? this.deviceTs,
    localDay: localDay ?? this.localDay,
    tz: tz.present ? tz.value : this.tz,
    payload: payload ?? this.payload,
    needsNote: needsNote ?? this.needsNote,
    attempts: attempts ?? this.attempts,
    nextAttemptAt: nextAttemptAt.present
        ? nextAttemptAt.value
        : this.nextAttemptAt,
    createdAt: createdAt ?? this.createdAt,
    needsMedia: needsMedia ?? this.needsMedia,
    mediaAttempts: mediaAttempts ?? this.mediaAttempts,
  );
  OutboxRow copyWithCompanion(OutboxCompanion data) {
    return OutboxRow(
      seq: data.seq.present ? data.seq.value : this.seq,
      mutationId: data.mutationId.present
          ? data.mutationId.value
          : this.mutationId,
      entity: data.entity.present ? data.entity.value : this.entity,
      op: data.op.present ? data.op.value : this.op,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      deviceTs: data.deviceTs.present ? data.deviceTs.value : this.deviceTs,
      localDay: data.localDay.present ? data.localDay.value : this.localDay,
      tz: data.tz.present ? data.tz.value : this.tz,
      payload: data.payload.present ? data.payload.value : this.payload,
      needsNote: data.needsNote.present ? data.needsNote.value : this.needsNote,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      nextAttemptAt: data.nextAttemptAt.present
          ? data.nextAttemptAt.value
          : this.nextAttemptAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      needsMedia: data.needsMedia.present
          ? data.needsMedia.value
          : this.needsMedia,
      mediaAttempts: data.mediaAttempts.present
          ? data.mediaAttempts.value
          : this.mediaAttempts,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxRow(')
          ..write('seq: $seq, ')
          ..write('mutationId: $mutationId, ')
          ..write('entity: $entity, ')
          ..write('op: $op, ')
          ..write('entityId: $entityId, ')
          ..write('deviceTs: $deviceTs, ')
          ..write('localDay: $localDay, ')
          ..write('tz: $tz, ')
          ..write('payload: $payload, ')
          ..write('needsNote: $needsNote, ')
          ..write('attempts: $attempts, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('needsMedia: $needsMedia, ')
          ..write('mediaAttempts: $mediaAttempts')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    seq,
    mutationId,
    entity,
    op,
    entityId,
    deviceTs,
    localDay,
    tz,
    payload,
    needsNote,
    attempts,
    nextAttemptAt,
    createdAt,
    needsMedia,
    mediaAttempts,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxRow &&
          other.seq == this.seq &&
          other.mutationId == this.mutationId &&
          other.entity == this.entity &&
          other.op == this.op &&
          other.entityId == this.entityId &&
          other.deviceTs == this.deviceTs &&
          other.localDay == this.localDay &&
          other.tz == this.tz &&
          other.payload == this.payload &&
          other.needsNote == this.needsNote &&
          other.attempts == this.attempts &&
          other.nextAttemptAt == this.nextAttemptAt &&
          other.createdAt == this.createdAt &&
          other.needsMedia == this.needsMedia &&
          other.mediaAttempts == this.mediaAttempts);
}

class OutboxCompanion extends UpdateCompanion<OutboxRow> {
  final Value<int> seq;
  final Value<String> mutationId;
  final Value<String> entity;
  final Value<String> op;
  final Value<String> entityId;
  final Value<DateTime> deviceTs;
  final Value<String> localDay;
  final Value<String?> tz;
  final Value<String> payload;
  final Value<bool> needsNote;
  final Value<int> attempts;
  final Value<DateTime?> nextAttemptAt;
  final Value<DateTime> createdAt;
  final Value<bool> needsMedia;
  final Value<int> mediaAttempts;
  const OutboxCompanion({
    this.seq = const Value.absent(),
    this.mutationId = const Value.absent(),
    this.entity = const Value.absent(),
    this.op = const Value.absent(),
    this.entityId = const Value.absent(),
    this.deviceTs = const Value.absent(),
    this.localDay = const Value.absent(),
    this.tz = const Value.absent(),
    this.payload = const Value.absent(),
    this.needsNote = const Value.absent(),
    this.attempts = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.needsMedia = const Value.absent(),
    this.mediaAttempts = const Value.absent(),
  });
  OutboxCompanion.insert({
    this.seq = const Value.absent(),
    required String mutationId,
    required String entity,
    required String op,
    required String entityId,
    required DateTime deviceTs,
    required String localDay,
    this.tz = const Value.absent(),
    required String payload,
    this.needsNote = const Value.absent(),
    this.attempts = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    required DateTime createdAt,
    this.needsMedia = const Value.absent(),
    this.mediaAttempts = const Value.absent(),
  }) : mutationId = Value(mutationId),
       entity = Value(entity),
       op = Value(op),
       entityId = Value(entityId),
       deviceTs = Value(deviceTs),
       localDay = Value(localDay),
       payload = Value(payload),
       createdAt = Value(createdAt);
  static Insertable<OutboxRow> custom({
    Expression<int>? seq,
    Expression<String>? mutationId,
    Expression<String>? entity,
    Expression<String>? op,
    Expression<String>? entityId,
    Expression<DateTime>? deviceTs,
    Expression<String>? localDay,
    Expression<String>? tz,
    Expression<String>? payload,
    Expression<bool>? needsNote,
    Expression<int>? attempts,
    Expression<DateTime>? nextAttemptAt,
    Expression<DateTime>? createdAt,
    Expression<bool>? needsMedia,
    Expression<int>? mediaAttempts,
  }) {
    return RawValuesInsertable({
      if (seq != null) 'seq': seq,
      if (mutationId != null) 'mutation_id': mutationId,
      if (entity != null) 'entity': entity,
      if (op != null) 'op': op,
      if (entityId != null) 'entity_id': entityId,
      if (deviceTs != null) 'device_ts': deviceTs,
      if (localDay != null) 'local_day': localDay,
      if (tz != null) 'tz': tz,
      if (payload != null) 'payload': payload,
      if (needsNote != null) 'needs_note': needsNote,
      if (attempts != null) 'attempts': attempts,
      if (nextAttemptAt != null) 'next_attempt_at': nextAttemptAt,
      if (createdAt != null) 'created_at': createdAt,
      if (needsMedia != null) 'needs_media': needsMedia,
      if (mediaAttempts != null) 'media_attempts': mediaAttempts,
    });
  }

  OutboxCompanion copyWith({
    Value<int>? seq,
    Value<String>? mutationId,
    Value<String>? entity,
    Value<String>? op,
    Value<String>? entityId,
    Value<DateTime>? deviceTs,
    Value<String>? localDay,
    Value<String?>? tz,
    Value<String>? payload,
    Value<bool>? needsNote,
    Value<int>? attempts,
    Value<DateTime?>? nextAttemptAt,
    Value<DateTime>? createdAt,
    Value<bool>? needsMedia,
    Value<int>? mediaAttempts,
  }) {
    return OutboxCompanion(
      seq: seq ?? this.seq,
      mutationId: mutationId ?? this.mutationId,
      entity: entity ?? this.entity,
      op: op ?? this.op,
      entityId: entityId ?? this.entityId,
      deviceTs: deviceTs ?? this.deviceTs,
      localDay: localDay ?? this.localDay,
      tz: tz ?? this.tz,
      payload: payload ?? this.payload,
      needsNote: needsNote ?? this.needsNote,
      attempts: attempts ?? this.attempts,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      createdAt: createdAt ?? this.createdAt,
      needsMedia: needsMedia ?? this.needsMedia,
      mediaAttempts: mediaAttempts ?? this.mediaAttempts,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (mutationId.present) {
      map['mutation_id'] = Variable<String>(mutationId.value);
    }
    if (entity.present) {
      map['entity'] = Variable<String>(entity.value);
    }
    if (op.present) {
      map['op'] = Variable<String>(op.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (deviceTs.present) {
      map['device_ts'] = Variable<DateTime>(deviceTs.value);
    }
    if (localDay.present) {
      map['local_day'] = Variable<String>(localDay.value);
    }
    if (tz.present) {
      map['tz'] = Variable<String>(tz.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (needsNote.present) {
      map['needs_note'] = Variable<bool>(needsNote.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (nextAttemptAt.present) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (needsMedia.present) {
      map['needs_media'] = Variable<bool>(needsMedia.value);
    }
    if (mediaAttempts.present) {
      map['media_attempts'] = Variable<int>(mediaAttempts.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxCompanion(')
          ..write('seq: $seq, ')
          ..write('mutationId: $mutationId, ')
          ..write('entity: $entity, ')
          ..write('op: $op, ')
          ..write('entityId: $entityId, ')
          ..write('deviceTs: $deviceTs, ')
          ..write('localDay: $localDay, ')
          ..write('tz: $tz, ')
          ..write('payload: $payload, ')
          ..write('needsNote: $needsNote, ')
          ..write('attempts: $attempts, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('needsMedia: $needsMedia, ')
          ..write('mediaAttempts: $mediaAttempts')
          ..write(')'))
        .toString();
  }
}

class $DeadLettersTable extends DeadLetters
    with TableInfo<$DeadLettersTable, DeadLetterRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DeadLettersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _mutationIdMeta = const VerificationMeta(
    'mutationId',
  );
  @override
  late final GeneratedColumn<String> mutationId = GeneratedColumn<String>(
    'mutation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityMeta = const VerificationMeta('entity');
  @override
  late final GeneratedColumn<String> entity = GeneratedColumn<String>(
    'entity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _opMeta = const VerificationMeta('op');
  @override
  late final GeneratedColumn<String> op = GeneratedColumn<String>(
    'op',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
    'reason',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _failedAtMeta = const VerificationMeta(
    'failedAt',
  );
  @override
  late final GeneratedColumn<DateTime> failedAt = GeneratedColumn<DateTime>(
    'failed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceTsMeta = const VerificationMeta(
    'deviceTs',
  );
  @override
  late final GeneratedColumn<DateTime> deviceTs = GeneratedColumn<DateTime>(
    'device_ts',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localDayMeta = const VerificationMeta(
    'localDay',
  );
  @override
  late final GeneratedColumn<String> localDay = GeneratedColumn<String>(
    'local_day',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tzMeta = const VerificationMeta('tz');
  @override
  late final GeneratedColumn<String> tz = GeneratedColumn<String>(
    'tz',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    seq,
    mutationId,
    entity,
    op,
    entityId,
    payload,
    reason,
    failedAt,
    deviceTs,
    localDay,
    tz,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dead_letters';
  @override
  VerificationContext validateIntegrity(
    Insertable<DeadLetterRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    }
    if (data.containsKey('mutation_id')) {
      context.handle(
        _mutationIdMeta,
        mutationId.isAcceptableOrUnknown(data['mutation_id']!, _mutationIdMeta),
      );
    } else if (isInserting) {
      context.missing(_mutationIdMeta);
    }
    if (data.containsKey('entity')) {
      context.handle(
        _entityMeta,
        entity.isAcceptableOrUnknown(data['entity']!, _entityMeta),
      );
    } else if (isInserting) {
      context.missing(_entityMeta);
    }
    if (data.containsKey('op')) {
      context.handle(_opMeta, op.isAcceptableOrUnknown(data['op']!, _opMeta));
    } else if (isInserting) {
      context.missing(_opMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('reason')) {
      context.handle(
        _reasonMeta,
        reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta),
      );
    } else if (isInserting) {
      context.missing(_reasonMeta);
    }
    if (data.containsKey('failed_at')) {
      context.handle(
        _failedAtMeta,
        failedAt.isAcceptableOrUnknown(data['failed_at']!, _failedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_failedAtMeta);
    }
    if (data.containsKey('device_ts')) {
      context.handle(
        _deviceTsMeta,
        deviceTs.isAcceptableOrUnknown(data['device_ts']!, _deviceTsMeta),
      );
    }
    if (data.containsKey('local_day')) {
      context.handle(
        _localDayMeta,
        localDay.isAcceptableOrUnknown(data['local_day']!, _localDayMeta),
      );
    }
    if (data.containsKey('tz')) {
      context.handle(_tzMeta, tz.isAcceptableOrUnknown(data['tz']!, _tzMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {seq};
  @override
  DeadLetterRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DeadLetterRow(
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      mutationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mutation_id'],
      )!,
      entity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity'],
      )!,
      op: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}op'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      reason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason'],
      )!,
      failedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}failed_at'],
      )!,
      deviceTs: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}device_ts'],
      ),
      localDay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_day'],
      ),
      tz: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tz'],
      ),
    );
  }

  @override
  $DeadLettersTable createAlias(String alias) {
    return $DeadLettersTable(attachedDatabase, alias);
  }
}

class DeadLetterRow extends DataClass implements Insertable<DeadLetterRow> {
  final int seq;
  final String mutationId;
  final String entity;
  final String op;
  final String entityId;
  final String payload;
  final String reason;
  final DateTime failedAt;
  final DateTime? deviceTs;
  final String? localDay;
  final String? tz;
  const DeadLetterRow({
    required this.seq,
    required this.mutationId,
    required this.entity,
    required this.op,
    required this.entityId,
    required this.payload,
    required this.reason,
    required this.failedAt,
    this.deviceTs,
    this.localDay,
    this.tz,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['seq'] = Variable<int>(seq);
    map['mutation_id'] = Variable<String>(mutationId);
    map['entity'] = Variable<String>(entity);
    map['op'] = Variable<String>(op);
    map['entity_id'] = Variable<String>(entityId);
    map['payload'] = Variable<String>(payload);
    map['reason'] = Variable<String>(reason);
    map['failed_at'] = Variable<DateTime>(failedAt);
    if (!nullToAbsent || deviceTs != null) {
      map['device_ts'] = Variable<DateTime>(deviceTs);
    }
    if (!nullToAbsent || localDay != null) {
      map['local_day'] = Variable<String>(localDay);
    }
    if (!nullToAbsent || tz != null) {
      map['tz'] = Variable<String>(tz);
    }
    return map;
  }

  DeadLettersCompanion toCompanion(bool nullToAbsent) {
    return DeadLettersCompanion(
      seq: Value(seq),
      mutationId: Value(mutationId),
      entity: Value(entity),
      op: Value(op),
      entityId: Value(entityId),
      payload: Value(payload),
      reason: Value(reason),
      failedAt: Value(failedAt),
      deviceTs: deviceTs == null && nullToAbsent
          ? const Value.absent()
          : Value(deviceTs),
      localDay: localDay == null && nullToAbsent
          ? const Value.absent()
          : Value(localDay),
      tz: tz == null && nullToAbsent ? const Value.absent() : Value(tz),
    );
  }

  factory DeadLetterRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DeadLetterRow(
      seq: serializer.fromJson<int>(json['seq']),
      mutationId: serializer.fromJson<String>(json['mutationId']),
      entity: serializer.fromJson<String>(json['entity']),
      op: serializer.fromJson<String>(json['op']),
      entityId: serializer.fromJson<String>(json['entityId']),
      payload: serializer.fromJson<String>(json['payload']),
      reason: serializer.fromJson<String>(json['reason']),
      failedAt: serializer.fromJson<DateTime>(json['failedAt']),
      deviceTs: serializer.fromJson<DateTime?>(json['deviceTs']),
      localDay: serializer.fromJson<String?>(json['localDay']),
      tz: serializer.fromJson<String?>(json['tz']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'seq': serializer.toJson<int>(seq),
      'mutationId': serializer.toJson<String>(mutationId),
      'entity': serializer.toJson<String>(entity),
      'op': serializer.toJson<String>(op),
      'entityId': serializer.toJson<String>(entityId),
      'payload': serializer.toJson<String>(payload),
      'reason': serializer.toJson<String>(reason),
      'failedAt': serializer.toJson<DateTime>(failedAt),
      'deviceTs': serializer.toJson<DateTime?>(deviceTs),
      'localDay': serializer.toJson<String?>(localDay),
      'tz': serializer.toJson<String?>(tz),
    };
  }

  DeadLetterRow copyWith({
    int? seq,
    String? mutationId,
    String? entity,
    String? op,
    String? entityId,
    String? payload,
    String? reason,
    DateTime? failedAt,
    Value<DateTime?> deviceTs = const Value.absent(),
    Value<String?> localDay = const Value.absent(),
    Value<String?> tz = const Value.absent(),
  }) => DeadLetterRow(
    seq: seq ?? this.seq,
    mutationId: mutationId ?? this.mutationId,
    entity: entity ?? this.entity,
    op: op ?? this.op,
    entityId: entityId ?? this.entityId,
    payload: payload ?? this.payload,
    reason: reason ?? this.reason,
    failedAt: failedAt ?? this.failedAt,
    deviceTs: deviceTs.present ? deviceTs.value : this.deviceTs,
    localDay: localDay.present ? localDay.value : this.localDay,
    tz: tz.present ? tz.value : this.tz,
  );
  DeadLetterRow copyWithCompanion(DeadLettersCompanion data) {
    return DeadLetterRow(
      seq: data.seq.present ? data.seq.value : this.seq,
      mutationId: data.mutationId.present
          ? data.mutationId.value
          : this.mutationId,
      entity: data.entity.present ? data.entity.value : this.entity,
      op: data.op.present ? data.op.value : this.op,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      payload: data.payload.present ? data.payload.value : this.payload,
      reason: data.reason.present ? data.reason.value : this.reason,
      failedAt: data.failedAt.present ? data.failedAt.value : this.failedAt,
      deviceTs: data.deviceTs.present ? data.deviceTs.value : this.deviceTs,
      localDay: data.localDay.present ? data.localDay.value : this.localDay,
      tz: data.tz.present ? data.tz.value : this.tz,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DeadLetterRow(')
          ..write('seq: $seq, ')
          ..write('mutationId: $mutationId, ')
          ..write('entity: $entity, ')
          ..write('op: $op, ')
          ..write('entityId: $entityId, ')
          ..write('payload: $payload, ')
          ..write('reason: $reason, ')
          ..write('failedAt: $failedAt, ')
          ..write('deviceTs: $deviceTs, ')
          ..write('localDay: $localDay, ')
          ..write('tz: $tz')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    seq,
    mutationId,
    entity,
    op,
    entityId,
    payload,
    reason,
    failedAt,
    deviceTs,
    localDay,
    tz,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DeadLetterRow &&
          other.seq == this.seq &&
          other.mutationId == this.mutationId &&
          other.entity == this.entity &&
          other.op == this.op &&
          other.entityId == this.entityId &&
          other.payload == this.payload &&
          other.reason == this.reason &&
          other.failedAt == this.failedAt &&
          other.deviceTs == this.deviceTs &&
          other.localDay == this.localDay &&
          other.tz == this.tz);
}

class DeadLettersCompanion extends UpdateCompanion<DeadLetterRow> {
  final Value<int> seq;
  final Value<String> mutationId;
  final Value<String> entity;
  final Value<String> op;
  final Value<String> entityId;
  final Value<String> payload;
  final Value<String> reason;
  final Value<DateTime> failedAt;
  final Value<DateTime?> deviceTs;
  final Value<String?> localDay;
  final Value<String?> tz;
  const DeadLettersCompanion({
    this.seq = const Value.absent(),
    this.mutationId = const Value.absent(),
    this.entity = const Value.absent(),
    this.op = const Value.absent(),
    this.entityId = const Value.absent(),
    this.payload = const Value.absent(),
    this.reason = const Value.absent(),
    this.failedAt = const Value.absent(),
    this.deviceTs = const Value.absent(),
    this.localDay = const Value.absent(),
    this.tz = const Value.absent(),
  });
  DeadLettersCompanion.insert({
    this.seq = const Value.absent(),
    required String mutationId,
    required String entity,
    required String op,
    required String entityId,
    required String payload,
    required String reason,
    required DateTime failedAt,
    this.deviceTs = const Value.absent(),
    this.localDay = const Value.absent(),
    this.tz = const Value.absent(),
  }) : mutationId = Value(mutationId),
       entity = Value(entity),
       op = Value(op),
       entityId = Value(entityId),
       payload = Value(payload),
       reason = Value(reason),
       failedAt = Value(failedAt);
  static Insertable<DeadLetterRow> custom({
    Expression<int>? seq,
    Expression<String>? mutationId,
    Expression<String>? entity,
    Expression<String>? op,
    Expression<String>? entityId,
    Expression<String>? payload,
    Expression<String>? reason,
    Expression<DateTime>? failedAt,
    Expression<DateTime>? deviceTs,
    Expression<String>? localDay,
    Expression<String>? tz,
  }) {
    return RawValuesInsertable({
      if (seq != null) 'seq': seq,
      if (mutationId != null) 'mutation_id': mutationId,
      if (entity != null) 'entity': entity,
      if (op != null) 'op': op,
      if (entityId != null) 'entity_id': entityId,
      if (payload != null) 'payload': payload,
      if (reason != null) 'reason': reason,
      if (failedAt != null) 'failed_at': failedAt,
      if (deviceTs != null) 'device_ts': deviceTs,
      if (localDay != null) 'local_day': localDay,
      if (tz != null) 'tz': tz,
    });
  }

  DeadLettersCompanion copyWith({
    Value<int>? seq,
    Value<String>? mutationId,
    Value<String>? entity,
    Value<String>? op,
    Value<String>? entityId,
    Value<String>? payload,
    Value<String>? reason,
    Value<DateTime>? failedAt,
    Value<DateTime?>? deviceTs,
    Value<String?>? localDay,
    Value<String?>? tz,
  }) {
    return DeadLettersCompanion(
      seq: seq ?? this.seq,
      mutationId: mutationId ?? this.mutationId,
      entity: entity ?? this.entity,
      op: op ?? this.op,
      entityId: entityId ?? this.entityId,
      payload: payload ?? this.payload,
      reason: reason ?? this.reason,
      failedAt: failedAt ?? this.failedAt,
      deviceTs: deviceTs ?? this.deviceTs,
      localDay: localDay ?? this.localDay,
      tz: tz ?? this.tz,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (mutationId.present) {
      map['mutation_id'] = Variable<String>(mutationId.value);
    }
    if (entity.present) {
      map['entity'] = Variable<String>(entity.value);
    }
    if (op.present) {
      map['op'] = Variable<String>(op.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (failedAt.present) {
      map['failed_at'] = Variable<DateTime>(failedAt.value);
    }
    if (deviceTs.present) {
      map['device_ts'] = Variable<DateTime>(deviceTs.value);
    }
    if (localDay.present) {
      map['local_day'] = Variable<String>(localDay.value);
    }
    if (tz.present) {
      map['tz'] = Variable<String>(tz.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DeadLettersCompanion(')
          ..write('seq: $seq, ')
          ..write('mutationId: $mutationId, ')
          ..write('entity: $entity, ')
          ..write('op: $op, ')
          ..write('entityId: $entityId, ')
          ..write('payload: $payload, ')
          ..write('reason: $reason, ')
          ..write('failedAt: $failedAt, ')
          ..write('deviceTs: $deviceTs, ')
          ..write('localDay: $localDay, ')
          ..write('tz: $tz')
          ..write(')'))
        .toString();
  }
}

class $KeyValuesTable extends KeyValues
    with TableInfo<$KeyValuesTable, KeyValueRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KeyValuesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'key_values';
  @override
  VerificationContext validateIntegrity(
    Insertable<KeyValueRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  KeyValueRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KeyValueRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $KeyValuesTable createAlias(String alias) {
    return $KeyValuesTable(attachedDatabase, alias);
  }
}

class KeyValueRow extends DataClass implements Insertable<KeyValueRow> {
  final String key;
  final String value;
  const KeyValueRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  KeyValuesCompanion toCompanion(bool nullToAbsent) {
    return KeyValuesCompanion(key: Value(key), value: Value(value));
  }

  factory KeyValueRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KeyValueRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  KeyValueRow copyWith({String? key, String? value}) =>
      KeyValueRow(key: key ?? this.key, value: value ?? this.value);
  KeyValueRow copyWithCompanion(KeyValuesCompanion data) {
    return KeyValueRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('KeyValueRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KeyValueRow &&
          other.key == this.key &&
          other.value == this.value);
}

class KeyValuesCompanion extends UpdateCompanion<KeyValueRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const KeyValuesCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  KeyValuesCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<KeyValueRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  KeyValuesCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return KeyValuesCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('KeyValuesCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CapsulesTable extends Capsules
    with TableInfo<$CapsulesTable, CapsuleRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CapsulesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unlockTypeMeta = const VerificationMeta(
    'unlockType',
  );
  @override
  late final GeneratedColumn<String> unlockType = GeneratedColumn<String>(
    'unlock_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unlockLocalDateMeta = const VerificationMeta(
    'unlockLocalDate',
  );
  @override
  late final GeneratedColumn<String> unlockLocalDate = GeneratedColumn<String>(
    'unlock_local_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _triggerMoodIdMeta = const VerificationMeta(
    'triggerMoodId',
  );
  @override
  late final GeneratedColumn<String> triggerMoodId = GeneratedColumn<String>(
    'trigger_mood_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _triggerQuadrantMeta = const VerificationMeta(
    'triggerQuadrant',
  );
  @override
  late final GeneratedColumn<String> triggerQuadrant = GeneratedColumn<String>(
    'trigger_quadrant',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _payloadCtMeta = const VerificationMeta(
    'payloadCt',
  );
  @override
  late final GeneratedColumn<String> payloadCt = GeneratedColumn<String>(
    'payload_ct',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _payloadClearMeta = const VerificationMeta(
    'payloadClear',
  );
  @override
  late final GeneratedColumn<String> payloadClear = GeneratedColumn<String>(
    'payload_clear',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sealedAtMeta = const VerificationMeta(
    'sealedAt',
  );
  @override
  late final GeneratedColumn<DateTime> sealedAt = GeneratedColumn<DateTime>(
    'sealed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sealTzMeta = const VerificationMeta('sealTz');
  @override
  late final GeneratedColumn<String> sealTz = GeneratedColumn<String>(
    'seal_tz',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _armedAtMeta = const VerificationMeta(
    'armedAt',
  );
  @override
  late final GeneratedColumn<DateTime> armedAt = GeneratedColumn<DateTime>(
    'armed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cycleMeta = const VerificationMeta('cycle');
  @override
  late final GeneratedColumn<int> cycle = GeneratedColumn<int>(
    'cycle',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _firedAtMeta = const VerificationMeta(
    'firedAt',
  );
  @override
  late final GeneratedColumn<DateTime> firedAt = GeneratedColumn<DateTime>(
    'fired_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cooldownUntilMeta = const VerificationMeta(
    'cooldownUntil',
  );
  @override
  late final GeneratedColumn<DateTime> cooldownUntil =
      GeneratedColumn<DateTime>(
        'cooldown_until',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _openedAtMeta = const VerificationMeta(
    'openedAt',
  );
  @override
  late final GeneratedColumn<DateTime> openedAt = GeneratedColumn<DateTime>(
    'opened_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _openedDeviceTsMeta = const VerificationMeta(
    'openedDeviceTs',
  );
  @override
  late final GeneratedColumn<DateTime> openedDeviceTs =
      GeneratedColumn<DateTime>(
        'opened_device_ts',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _serverUpdatedAtMeta = const VerificationMeta(
    'serverUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> serverUpdatedAt =
      GeneratedColumn<DateTime>(
        'server_updated_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _syncedMeta = const VerificationMeta('synced');
  @override
  late final GeneratedColumn<bool> synced = GeneratedColumn<bool>(
    'synced',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("synced" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _rejectedMeta = const VerificationMeta(
    'rejected',
  );
  @override
  late final GeneratedColumn<String> rejected = GeneratedColumn<String>(
    'rejected',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notifyAtMeta = const VerificationMeta(
    'notifyAt',
  );
  @override
  late final GeneratedColumn<DateTime> notifyAt = GeneratedColumn<DateTime>(
    'notify_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    unlockType,
    unlockLocalDate,
    triggerMoodId,
    triggerQuadrant,
    payloadCt,
    payloadClear,
    sealedAt,
    sealTz,
    armedAt,
    cycle,
    firedAt,
    cooldownUntil,
    openedAt,
    openedDeviceTs,
    deletedAt,
    serverUpdatedAt,
    synced,
    rejected,
    notifyAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'capsules';
  @override
  VerificationContext validateIntegrity(
    Insertable<CapsuleRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('unlock_type')) {
      context.handle(
        _unlockTypeMeta,
        unlockType.isAcceptableOrUnknown(data['unlock_type']!, _unlockTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_unlockTypeMeta);
    }
    if (data.containsKey('unlock_local_date')) {
      context.handle(
        _unlockLocalDateMeta,
        unlockLocalDate.isAcceptableOrUnknown(
          data['unlock_local_date']!,
          _unlockLocalDateMeta,
        ),
      );
    }
    if (data.containsKey('trigger_mood_id')) {
      context.handle(
        _triggerMoodIdMeta,
        triggerMoodId.isAcceptableOrUnknown(
          data['trigger_mood_id']!,
          _triggerMoodIdMeta,
        ),
      );
    }
    if (data.containsKey('trigger_quadrant')) {
      context.handle(
        _triggerQuadrantMeta,
        triggerQuadrant.isAcceptableOrUnknown(
          data['trigger_quadrant']!,
          _triggerQuadrantMeta,
        ),
      );
    }
    if (data.containsKey('payload_ct')) {
      context.handle(
        _payloadCtMeta,
        payloadCt.isAcceptableOrUnknown(data['payload_ct']!, _payloadCtMeta),
      );
    }
    if (data.containsKey('payload_clear')) {
      context.handle(
        _payloadClearMeta,
        payloadClear.isAcceptableOrUnknown(
          data['payload_clear']!,
          _payloadClearMeta,
        ),
      );
    }
    if (data.containsKey('sealed_at')) {
      context.handle(
        _sealedAtMeta,
        sealedAt.isAcceptableOrUnknown(data['sealed_at']!, _sealedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_sealedAtMeta);
    }
    if (data.containsKey('seal_tz')) {
      context.handle(
        _sealTzMeta,
        sealTz.isAcceptableOrUnknown(data['seal_tz']!, _sealTzMeta),
      );
    }
    if (data.containsKey('armed_at')) {
      context.handle(
        _armedAtMeta,
        armedAt.isAcceptableOrUnknown(data['armed_at']!, _armedAtMeta),
      );
    }
    if (data.containsKey('cycle')) {
      context.handle(
        _cycleMeta,
        cycle.isAcceptableOrUnknown(data['cycle']!, _cycleMeta),
      );
    }
    if (data.containsKey('fired_at')) {
      context.handle(
        _firedAtMeta,
        firedAt.isAcceptableOrUnknown(data['fired_at']!, _firedAtMeta),
      );
    }
    if (data.containsKey('cooldown_until')) {
      context.handle(
        _cooldownUntilMeta,
        cooldownUntil.isAcceptableOrUnknown(
          data['cooldown_until']!,
          _cooldownUntilMeta,
        ),
      );
    }
    if (data.containsKey('opened_at')) {
      context.handle(
        _openedAtMeta,
        openedAt.isAcceptableOrUnknown(data['opened_at']!, _openedAtMeta),
      );
    }
    if (data.containsKey('opened_device_ts')) {
      context.handle(
        _openedDeviceTsMeta,
        openedDeviceTs.isAcceptableOrUnknown(
          data['opened_device_ts']!,
          _openedDeviceTsMeta,
        ),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('server_updated_at')) {
      context.handle(
        _serverUpdatedAtMeta,
        serverUpdatedAt.isAcceptableOrUnknown(
          data['server_updated_at']!,
          _serverUpdatedAtMeta,
        ),
      );
    }
    if (data.containsKey('synced')) {
      context.handle(
        _syncedMeta,
        synced.isAcceptableOrUnknown(data['synced']!, _syncedMeta),
      );
    }
    if (data.containsKey('rejected')) {
      context.handle(
        _rejectedMeta,
        rejected.isAcceptableOrUnknown(data['rejected']!, _rejectedMeta),
      );
    }
    if (data.containsKey('notify_at')) {
      context.handle(
        _notifyAtMeta,
        notifyAt.isAcceptableOrUnknown(data['notify_at']!, _notifyAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CapsuleRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CapsuleRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      unlockType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unlock_type'],
      )!,
      unlockLocalDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unlock_local_date'],
      ),
      triggerMoodId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}trigger_mood_id'],
      ),
      triggerQuadrant: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}trigger_quadrant'],
      ),
      payloadCt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_ct'],
      ),
      payloadClear: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_clear'],
      ),
      sealedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}sealed_at'],
      )!,
      sealTz: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}seal_tz'],
      ),
      armedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}armed_at'],
      ),
      cycle: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cycle'],
      )!,
      firedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fired_at'],
      ),
      cooldownUntil: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cooldown_until'],
      ),
      openedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}opened_at'],
      ),
      openedDeviceTs: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}opened_device_ts'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      serverUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}server_updated_at'],
      ),
      synced: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}synced'],
      )!,
      rejected: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rejected'],
      ),
      notifyAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}notify_at'],
      ),
    );
  }

  @override
  $CapsulesTable createAlias(String alias) {
    return $CapsulesTable(attachedDatabase, alias);
  }
}

class CapsuleRow extends DataClass implements Insertable<CapsuleRow> {
  final String id;

  /// `date` | `mood`.
  final String unlockType;

  /// Date capsules: opens at 10:00 on this date (`YYYY-MM-DD`) in the
  /// current zone.
  final String? unlockLocalDate;

  /// Mood capsules: exactly one of these two.
  final String? triggerMoodId;
  final String? triggerQuadrant;

  /// DS-1 ciphertext of the payload (AD = the capsule id). `null` on
  /// tombstones and while [payloadClear] waits for the data key.
  final String? payloadCt;

  /// The payload JSON, only until a data key seals it (never synced).
  final String? payloadClear;

  /// Device time of sealing, and the zone it was sealed in (the window's
  /// calendar date).
  final DateTime sealedAt;
  final String? sealTz;

  /// Mood capsules: may fire from here (seal + 24 h, or the re-arm time).
  final DateTime? armedAt;

  /// Re-arms so far ("Keep for next time"); sent with open/fire/rearm.
  final int cycle;

  /// Fire time in the current cycle (earliest wins across devices).
  final DateTime? firedAt;

  /// Most recent fire + 168 h. The global cooldown is the max over all rows,
  /// tombstones included.
  final DateTime? cooldownUntil;

  /// First open in the current cycle: the server's time once pulled, this
  /// phone's until then. One-way.
  final DateTime? openedAt;
  final DateTime? openedDeviceTs;

  /// Tombstone.
  final DateTime? deletedAt;

  /// The server row's `updated_at` (last pull that touched it).
  final DateTime? serverUpdatedAt;

  /// The seal reached the server (acknowledged, or pulled).
  final bool synced;

  /// The server refused the seal for good (`trigger_capsule_limit`,
  /// `invalid_unlock_date`, `date_capsule_limit`): the capsule lives only
  /// on this phone until the person changes it (e.g. makes it a date
  /// capsule, which re-seals the same id).
  final String? rejected;

  /// When this phone's local "ready to open" notification fires (date
  /// capsules; `null` when none is scheduled). Lets the push handler skip
  /// the server's backup push for the same capsule.
  final DateTime? notifyAt;
  const CapsuleRow({
    required this.id,
    required this.unlockType,
    this.unlockLocalDate,
    this.triggerMoodId,
    this.triggerQuadrant,
    this.payloadCt,
    this.payloadClear,
    required this.sealedAt,
    this.sealTz,
    this.armedAt,
    required this.cycle,
    this.firedAt,
    this.cooldownUntil,
    this.openedAt,
    this.openedDeviceTs,
    this.deletedAt,
    this.serverUpdatedAt,
    required this.synced,
    this.rejected,
    this.notifyAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['unlock_type'] = Variable<String>(unlockType);
    if (!nullToAbsent || unlockLocalDate != null) {
      map['unlock_local_date'] = Variable<String>(unlockLocalDate);
    }
    if (!nullToAbsent || triggerMoodId != null) {
      map['trigger_mood_id'] = Variable<String>(triggerMoodId);
    }
    if (!nullToAbsent || triggerQuadrant != null) {
      map['trigger_quadrant'] = Variable<String>(triggerQuadrant);
    }
    if (!nullToAbsent || payloadCt != null) {
      map['payload_ct'] = Variable<String>(payloadCt);
    }
    if (!nullToAbsent || payloadClear != null) {
      map['payload_clear'] = Variable<String>(payloadClear);
    }
    map['sealed_at'] = Variable<DateTime>(sealedAt);
    if (!nullToAbsent || sealTz != null) {
      map['seal_tz'] = Variable<String>(sealTz);
    }
    if (!nullToAbsent || armedAt != null) {
      map['armed_at'] = Variable<DateTime>(armedAt);
    }
    map['cycle'] = Variable<int>(cycle);
    if (!nullToAbsent || firedAt != null) {
      map['fired_at'] = Variable<DateTime>(firedAt);
    }
    if (!nullToAbsent || cooldownUntil != null) {
      map['cooldown_until'] = Variable<DateTime>(cooldownUntil);
    }
    if (!nullToAbsent || openedAt != null) {
      map['opened_at'] = Variable<DateTime>(openedAt);
    }
    if (!nullToAbsent || openedDeviceTs != null) {
      map['opened_device_ts'] = Variable<DateTime>(openedDeviceTs);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    if (!nullToAbsent || serverUpdatedAt != null) {
      map['server_updated_at'] = Variable<DateTime>(serverUpdatedAt);
    }
    map['synced'] = Variable<bool>(synced);
    if (!nullToAbsent || rejected != null) {
      map['rejected'] = Variable<String>(rejected);
    }
    if (!nullToAbsent || notifyAt != null) {
      map['notify_at'] = Variable<DateTime>(notifyAt);
    }
    return map;
  }

  CapsulesCompanion toCompanion(bool nullToAbsent) {
    return CapsulesCompanion(
      id: Value(id),
      unlockType: Value(unlockType),
      unlockLocalDate: unlockLocalDate == null && nullToAbsent
          ? const Value.absent()
          : Value(unlockLocalDate),
      triggerMoodId: triggerMoodId == null && nullToAbsent
          ? const Value.absent()
          : Value(triggerMoodId),
      triggerQuadrant: triggerQuadrant == null && nullToAbsent
          ? const Value.absent()
          : Value(triggerQuadrant),
      payloadCt: payloadCt == null && nullToAbsent
          ? const Value.absent()
          : Value(payloadCt),
      payloadClear: payloadClear == null && nullToAbsent
          ? const Value.absent()
          : Value(payloadClear),
      sealedAt: Value(sealedAt),
      sealTz: sealTz == null && nullToAbsent
          ? const Value.absent()
          : Value(sealTz),
      armedAt: armedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(armedAt),
      cycle: Value(cycle),
      firedAt: firedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(firedAt),
      cooldownUntil: cooldownUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(cooldownUntil),
      openedAt: openedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(openedAt),
      openedDeviceTs: openedDeviceTs == null && nullToAbsent
          ? const Value.absent()
          : Value(openedDeviceTs),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      serverUpdatedAt: serverUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(serverUpdatedAt),
      synced: Value(synced),
      rejected: rejected == null && nullToAbsent
          ? const Value.absent()
          : Value(rejected),
      notifyAt: notifyAt == null && nullToAbsent
          ? const Value.absent()
          : Value(notifyAt),
    );
  }

  factory CapsuleRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CapsuleRow(
      id: serializer.fromJson<String>(json['id']),
      unlockType: serializer.fromJson<String>(json['unlockType']),
      unlockLocalDate: serializer.fromJson<String?>(json['unlockLocalDate']),
      triggerMoodId: serializer.fromJson<String?>(json['triggerMoodId']),
      triggerQuadrant: serializer.fromJson<String?>(json['triggerQuadrant']),
      payloadCt: serializer.fromJson<String?>(json['payloadCt']),
      payloadClear: serializer.fromJson<String?>(json['payloadClear']),
      sealedAt: serializer.fromJson<DateTime>(json['sealedAt']),
      sealTz: serializer.fromJson<String?>(json['sealTz']),
      armedAt: serializer.fromJson<DateTime?>(json['armedAt']),
      cycle: serializer.fromJson<int>(json['cycle']),
      firedAt: serializer.fromJson<DateTime?>(json['firedAt']),
      cooldownUntil: serializer.fromJson<DateTime?>(json['cooldownUntil']),
      openedAt: serializer.fromJson<DateTime?>(json['openedAt']),
      openedDeviceTs: serializer.fromJson<DateTime?>(json['openedDeviceTs']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      serverUpdatedAt: serializer.fromJson<DateTime?>(json['serverUpdatedAt']),
      synced: serializer.fromJson<bool>(json['synced']),
      rejected: serializer.fromJson<String?>(json['rejected']),
      notifyAt: serializer.fromJson<DateTime?>(json['notifyAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'unlockType': serializer.toJson<String>(unlockType),
      'unlockLocalDate': serializer.toJson<String?>(unlockLocalDate),
      'triggerMoodId': serializer.toJson<String?>(triggerMoodId),
      'triggerQuadrant': serializer.toJson<String?>(triggerQuadrant),
      'payloadCt': serializer.toJson<String?>(payloadCt),
      'payloadClear': serializer.toJson<String?>(payloadClear),
      'sealedAt': serializer.toJson<DateTime>(sealedAt),
      'sealTz': serializer.toJson<String?>(sealTz),
      'armedAt': serializer.toJson<DateTime?>(armedAt),
      'cycle': serializer.toJson<int>(cycle),
      'firedAt': serializer.toJson<DateTime?>(firedAt),
      'cooldownUntil': serializer.toJson<DateTime?>(cooldownUntil),
      'openedAt': serializer.toJson<DateTime?>(openedAt),
      'openedDeviceTs': serializer.toJson<DateTime?>(openedDeviceTs),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'serverUpdatedAt': serializer.toJson<DateTime?>(serverUpdatedAt),
      'synced': serializer.toJson<bool>(synced),
      'rejected': serializer.toJson<String?>(rejected),
      'notifyAt': serializer.toJson<DateTime?>(notifyAt),
    };
  }

  CapsuleRow copyWith({
    String? id,
    String? unlockType,
    Value<String?> unlockLocalDate = const Value.absent(),
    Value<String?> triggerMoodId = const Value.absent(),
    Value<String?> triggerQuadrant = const Value.absent(),
    Value<String?> payloadCt = const Value.absent(),
    Value<String?> payloadClear = const Value.absent(),
    DateTime? sealedAt,
    Value<String?> sealTz = const Value.absent(),
    Value<DateTime?> armedAt = const Value.absent(),
    int? cycle,
    Value<DateTime?> firedAt = const Value.absent(),
    Value<DateTime?> cooldownUntil = const Value.absent(),
    Value<DateTime?> openedAt = const Value.absent(),
    Value<DateTime?> openedDeviceTs = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
    Value<DateTime?> serverUpdatedAt = const Value.absent(),
    bool? synced,
    Value<String?> rejected = const Value.absent(),
    Value<DateTime?> notifyAt = const Value.absent(),
  }) => CapsuleRow(
    id: id ?? this.id,
    unlockType: unlockType ?? this.unlockType,
    unlockLocalDate: unlockLocalDate.present
        ? unlockLocalDate.value
        : this.unlockLocalDate,
    triggerMoodId: triggerMoodId.present
        ? triggerMoodId.value
        : this.triggerMoodId,
    triggerQuadrant: triggerQuadrant.present
        ? triggerQuadrant.value
        : this.triggerQuadrant,
    payloadCt: payloadCt.present ? payloadCt.value : this.payloadCt,
    payloadClear: payloadClear.present ? payloadClear.value : this.payloadClear,
    sealedAt: sealedAt ?? this.sealedAt,
    sealTz: sealTz.present ? sealTz.value : this.sealTz,
    armedAt: armedAt.present ? armedAt.value : this.armedAt,
    cycle: cycle ?? this.cycle,
    firedAt: firedAt.present ? firedAt.value : this.firedAt,
    cooldownUntil: cooldownUntil.present
        ? cooldownUntil.value
        : this.cooldownUntil,
    openedAt: openedAt.present ? openedAt.value : this.openedAt,
    openedDeviceTs: openedDeviceTs.present
        ? openedDeviceTs.value
        : this.openedDeviceTs,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    serverUpdatedAt: serverUpdatedAt.present
        ? serverUpdatedAt.value
        : this.serverUpdatedAt,
    synced: synced ?? this.synced,
    rejected: rejected.present ? rejected.value : this.rejected,
    notifyAt: notifyAt.present ? notifyAt.value : this.notifyAt,
  );
  CapsuleRow copyWithCompanion(CapsulesCompanion data) {
    return CapsuleRow(
      id: data.id.present ? data.id.value : this.id,
      unlockType: data.unlockType.present
          ? data.unlockType.value
          : this.unlockType,
      unlockLocalDate: data.unlockLocalDate.present
          ? data.unlockLocalDate.value
          : this.unlockLocalDate,
      triggerMoodId: data.triggerMoodId.present
          ? data.triggerMoodId.value
          : this.triggerMoodId,
      triggerQuadrant: data.triggerQuadrant.present
          ? data.triggerQuadrant.value
          : this.triggerQuadrant,
      payloadCt: data.payloadCt.present ? data.payloadCt.value : this.payloadCt,
      payloadClear: data.payloadClear.present
          ? data.payloadClear.value
          : this.payloadClear,
      sealedAt: data.sealedAt.present ? data.sealedAt.value : this.sealedAt,
      sealTz: data.sealTz.present ? data.sealTz.value : this.sealTz,
      armedAt: data.armedAt.present ? data.armedAt.value : this.armedAt,
      cycle: data.cycle.present ? data.cycle.value : this.cycle,
      firedAt: data.firedAt.present ? data.firedAt.value : this.firedAt,
      cooldownUntil: data.cooldownUntil.present
          ? data.cooldownUntil.value
          : this.cooldownUntil,
      openedAt: data.openedAt.present ? data.openedAt.value : this.openedAt,
      openedDeviceTs: data.openedDeviceTs.present
          ? data.openedDeviceTs.value
          : this.openedDeviceTs,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      serverUpdatedAt: data.serverUpdatedAt.present
          ? data.serverUpdatedAt.value
          : this.serverUpdatedAt,
      synced: data.synced.present ? data.synced.value : this.synced,
      rejected: data.rejected.present ? data.rejected.value : this.rejected,
      notifyAt: data.notifyAt.present ? data.notifyAt.value : this.notifyAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CapsuleRow(')
          ..write('id: $id, ')
          ..write('unlockType: $unlockType, ')
          ..write('unlockLocalDate: $unlockLocalDate, ')
          ..write('triggerMoodId: $triggerMoodId, ')
          ..write('triggerQuadrant: $triggerQuadrant, ')
          ..write('payloadCt: $payloadCt, ')
          ..write('payloadClear: $payloadClear, ')
          ..write('sealedAt: $sealedAt, ')
          ..write('sealTz: $sealTz, ')
          ..write('armedAt: $armedAt, ')
          ..write('cycle: $cycle, ')
          ..write('firedAt: $firedAt, ')
          ..write('cooldownUntil: $cooldownUntil, ')
          ..write('openedAt: $openedAt, ')
          ..write('openedDeviceTs: $openedDeviceTs, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('serverUpdatedAt: $serverUpdatedAt, ')
          ..write('synced: $synced, ')
          ..write('rejected: $rejected, ')
          ..write('notifyAt: $notifyAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    unlockType,
    unlockLocalDate,
    triggerMoodId,
    triggerQuadrant,
    payloadCt,
    payloadClear,
    sealedAt,
    sealTz,
    armedAt,
    cycle,
    firedAt,
    cooldownUntil,
    openedAt,
    openedDeviceTs,
    deletedAt,
    serverUpdatedAt,
    synced,
    rejected,
    notifyAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CapsuleRow &&
          other.id == this.id &&
          other.unlockType == this.unlockType &&
          other.unlockLocalDate == this.unlockLocalDate &&
          other.triggerMoodId == this.triggerMoodId &&
          other.triggerQuadrant == this.triggerQuadrant &&
          other.payloadCt == this.payloadCt &&
          other.payloadClear == this.payloadClear &&
          other.sealedAt == this.sealedAt &&
          other.sealTz == this.sealTz &&
          other.armedAt == this.armedAt &&
          other.cycle == this.cycle &&
          other.firedAt == this.firedAt &&
          other.cooldownUntil == this.cooldownUntil &&
          other.openedAt == this.openedAt &&
          other.openedDeviceTs == this.openedDeviceTs &&
          other.deletedAt == this.deletedAt &&
          other.serverUpdatedAt == this.serverUpdatedAt &&
          other.synced == this.synced &&
          other.rejected == this.rejected &&
          other.notifyAt == this.notifyAt);
}

class CapsulesCompanion extends UpdateCompanion<CapsuleRow> {
  final Value<String> id;
  final Value<String> unlockType;
  final Value<String?> unlockLocalDate;
  final Value<String?> triggerMoodId;
  final Value<String?> triggerQuadrant;
  final Value<String?> payloadCt;
  final Value<String?> payloadClear;
  final Value<DateTime> sealedAt;
  final Value<String?> sealTz;
  final Value<DateTime?> armedAt;
  final Value<int> cycle;
  final Value<DateTime?> firedAt;
  final Value<DateTime?> cooldownUntil;
  final Value<DateTime?> openedAt;
  final Value<DateTime?> openedDeviceTs;
  final Value<DateTime?> deletedAt;
  final Value<DateTime?> serverUpdatedAt;
  final Value<bool> synced;
  final Value<String?> rejected;
  final Value<DateTime?> notifyAt;
  final Value<int> rowid;
  const CapsulesCompanion({
    this.id = const Value.absent(),
    this.unlockType = const Value.absent(),
    this.unlockLocalDate = const Value.absent(),
    this.triggerMoodId = const Value.absent(),
    this.triggerQuadrant = const Value.absent(),
    this.payloadCt = const Value.absent(),
    this.payloadClear = const Value.absent(),
    this.sealedAt = const Value.absent(),
    this.sealTz = const Value.absent(),
    this.armedAt = const Value.absent(),
    this.cycle = const Value.absent(),
    this.firedAt = const Value.absent(),
    this.cooldownUntil = const Value.absent(),
    this.openedAt = const Value.absent(),
    this.openedDeviceTs = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.serverUpdatedAt = const Value.absent(),
    this.synced = const Value.absent(),
    this.rejected = const Value.absent(),
    this.notifyAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CapsulesCompanion.insert({
    required String id,
    required String unlockType,
    this.unlockLocalDate = const Value.absent(),
    this.triggerMoodId = const Value.absent(),
    this.triggerQuadrant = const Value.absent(),
    this.payloadCt = const Value.absent(),
    this.payloadClear = const Value.absent(),
    required DateTime sealedAt,
    this.sealTz = const Value.absent(),
    this.armedAt = const Value.absent(),
    this.cycle = const Value.absent(),
    this.firedAt = const Value.absent(),
    this.cooldownUntil = const Value.absent(),
    this.openedAt = const Value.absent(),
    this.openedDeviceTs = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.serverUpdatedAt = const Value.absent(),
    this.synced = const Value.absent(),
    this.rejected = const Value.absent(),
    this.notifyAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       unlockType = Value(unlockType),
       sealedAt = Value(sealedAt);
  static Insertable<CapsuleRow> custom({
    Expression<String>? id,
    Expression<String>? unlockType,
    Expression<String>? unlockLocalDate,
    Expression<String>? triggerMoodId,
    Expression<String>? triggerQuadrant,
    Expression<String>? payloadCt,
    Expression<String>? payloadClear,
    Expression<DateTime>? sealedAt,
    Expression<String>? sealTz,
    Expression<DateTime>? armedAt,
    Expression<int>? cycle,
    Expression<DateTime>? firedAt,
    Expression<DateTime>? cooldownUntil,
    Expression<DateTime>? openedAt,
    Expression<DateTime>? openedDeviceTs,
    Expression<DateTime>? deletedAt,
    Expression<DateTime>? serverUpdatedAt,
    Expression<bool>? synced,
    Expression<String>? rejected,
    Expression<DateTime>? notifyAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (unlockType != null) 'unlock_type': unlockType,
      if (unlockLocalDate != null) 'unlock_local_date': unlockLocalDate,
      if (triggerMoodId != null) 'trigger_mood_id': triggerMoodId,
      if (triggerQuadrant != null) 'trigger_quadrant': triggerQuadrant,
      if (payloadCt != null) 'payload_ct': payloadCt,
      if (payloadClear != null) 'payload_clear': payloadClear,
      if (sealedAt != null) 'sealed_at': sealedAt,
      if (sealTz != null) 'seal_tz': sealTz,
      if (armedAt != null) 'armed_at': armedAt,
      if (cycle != null) 'cycle': cycle,
      if (firedAt != null) 'fired_at': firedAt,
      if (cooldownUntil != null) 'cooldown_until': cooldownUntil,
      if (openedAt != null) 'opened_at': openedAt,
      if (openedDeviceTs != null) 'opened_device_ts': openedDeviceTs,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (serverUpdatedAt != null) 'server_updated_at': serverUpdatedAt,
      if (synced != null) 'synced': synced,
      if (rejected != null) 'rejected': rejected,
      if (notifyAt != null) 'notify_at': notifyAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CapsulesCompanion copyWith({
    Value<String>? id,
    Value<String>? unlockType,
    Value<String?>? unlockLocalDate,
    Value<String?>? triggerMoodId,
    Value<String?>? triggerQuadrant,
    Value<String?>? payloadCt,
    Value<String?>? payloadClear,
    Value<DateTime>? sealedAt,
    Value<String?>? sealTz,
    Value<DateTime?>? armedAt,
    Value<int>? cycle,
    Value<DateTime?>? firedAt,
    Value<DateTime?>? cooldownUntil,
    Value<DateTime?>? openedAt,
    Value<DateTime?>? openedDeviceTs,
    Value<DateTime?>? deletedAt,
    Value<DateTime?>? serverUpdatedAt,
    Value<bool>? synced,
    Value<String?>? rejected,
    Value<DateTime?>? notifyAt,
    Value<int>? rowid,
  }) {
    return CapsulesCompanion(
      id: id ?? this.id,
      unlockType: unlockType ?? this.unlockType,
      unlockLocalDate: unlockLocalDate ?? this.unlockLocalDate,
      triggerMoodId: triggerMoodId ?? this.triggerMoodId,
      triggerQuadrant: triggerQuadrant ?? this.triggerQuadrant,
      payloadCt: payloadCt ?? this.payloadCt,
      payloadClear: payloadClear ?? this.payloadClear,
      sealedAt: sealedAt ?? this.sealedAt,
      sealTz: sealTz ?? this.sealTz,
      armedAt: armedAt ?? this.armedAt,
      cycle: cycle ?? this.cycle,
      firedAt: firedAt ?? this.firedAt,
      cooldownUntil: cooldownUntil ?? this.cooldownUntil,
      openedAt: openedAt ?? this.openedAt,
      openedDeviceTs: openedDeviceTs ?? this.openedDeviceTs,
      deletedAt: deletedAt ?? this.deletedAt,
      serverUpdatedAt: serverUpdatedAt ?? this.serverUpdatedAt,
      synced: synced ?? this.synced,
      rejected: rejected ?? this.rejected,
      notifyAt: notifyAt ?? this.notifyAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (unlockType.present) {
      map['unlock_type'] = Variable<String>(unlockType.value);
    }
    if (unlockLocalDate.present) {
      map['unlock_local_date'] = Variable<String>(unlockLocalDate.value);
    }
    if (triggerMoodId.present) {
      map['trigger_mood_id'] = Variable<String>(triggerMoodId.value);
    }
    if (triggerQuadrant.present) {
      map['trigger_quadrant'] = Variable<String>(triggerQuadrant.value);
    }
    if (payloadCt.present) {
      map['payload_ct'] = Variable<String>(payloadCt.value);
    }
    if (payloadClear.present) {
      map['payload_clear'] = Variable<String>(payloadClear.value);
    }
    if (sealedAt.present) {
      map['sealed_at'] = Variable<DateTime>(sealedAt.value);
    }
    if (sealTz.present) {
      map['seal_tz'] = Variable<String>(sealTz.value);
    }
    if (armedAt.present) {
      map['armed_at'] = Variable<DateTime>(armedAt.value);
    }
    if (cycle.present) {
      map['cycle'] = Variable<int>(cycle.value);
    }
    if (firedAt.present) {
      map['fired_at'] = Variable<DateTime>(firedAt.value);
    }
    if (cooldownUntil.present) {
      map['cooldown_until'] = Variable<DateTime>(cooldownUntil.value);
    }
    if (openedAt.present) {
      map['opened_at'] = Variable<DateTime>(openedAt.value);
    }
    if (openedDeviceTs.present) {
      map['opened_device_ts'] = Variable<DateTime>(openedDeviceTs.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (serverUpdatedAt.present) {
      map['server_updated_at'] = Variable<DateTime>(serverUpdatedAt.value);
    }
    if (synced.present) {
      map['synced'] = Variable<bool>(synced.value);
    }
    if (rejected.present) {
      map['rejected'] = Variable<String>(rejected.value);
    }
    if (notifyAt.present) {
      map['notify_at'] = Variable<DateTime>(notifyAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CapsulesCompanion(')
          ..write('id: $id, ')
          ..write('unlockType: $unlockType, ')
          ..write('unlockLocalDate: $unlockLocalDate, ')
          ..write('triggerMoodId: $triggerMoodId, ')
          ..write('triggerQuadrant: $triggerQuadrant, ')
          ..write('payloadCt: $payloadCt, ')
          ..write('payloadClear: $payloadClear, ')
          ..write('sealedAt: $sealedAt, ')
          ..write('sealTz: $sealTz, ')
          ..write('armedAt: $armedAt, ')
          ..write('cycle: $cycle, ')
          ..write('firedAt: $firedAt, ')
          ..write('cooldownUntil: $cooldownUntil, ')
          ..write('openedAt: $openedAt, ')
          ..write('openedDeviceTs: $openedDeviceTs, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('serverUpdatedAt: $serverUpdatedAt, ')
          ..write('synced: $synced, ')
          ..write('rejected: $rejected, ')
          ..write('notifyAt: $notifyAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CapsuleMediaTable extends CapsuleMedia
    with TableInfo<$CapsuleMediaTable, CapsuleMediaRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CapsuleMediaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _capsuleIdMeta = const VerificationMeta(
    'capsuleId',
  );
  @override
  late final GeneratedColumn<String> capsuleId = GeneratedColumn<String>(
    'capsule_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _slotMeta = const VerificationMeta('slot');
  @override
  late final GeneratedColumn<String> slot = GeneratedColumn<String>(
    'slot',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileMeta = const VerificationMeta('file');
  @override
  late final GeneratedColumn<String> file = GeneratedColumn<String>(
    'file',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _nextAttemptAtMeta = const VerificationMeta(
    'nextAttemptAt',
  );
  @override
  late final GeneratedColumn<DateTime> nextAttemptAt =
      GeneratedColumn<DateTime>(
        'next_attempt_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _failedMeta = const VerificationMeta('failed');
  @override
  late final GeneratedColumn<bool> failed = GeneratedColumn<bool>(
    'failed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("failed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    capsuleId,
    slot,
    file,
    path,
    attempts,
    nextAttemptAt,
    failed,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'capsule_media';
  @override
  VerificationContext validateIntegrity(
    Insertable<CapsuleMediaRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('capsule_id')) {
      context.handle(
        _capsuleIdMeta,
        capsuleId.isAcceptableOrUnknown(data['capsule_id']!, _capsuleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_capsuleIdMeta);
    }
    if (data.containsKey('slot')) {
      context.handle(
        _slotMeta,
        slot.isAcceptableOrUnknown(data['slot']!, _slotMeta),
      );
    } else if (isInserting) {
      context.missing(_slotMeta);
    }
    if (data.containsKey('file')) {
      context.handle(
        _fileMeta,
        file.isAcceptableOrUnknown(data['file']!, _fileMeta),
      );
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('next_attempt_at')) {
      context.handle(
        _nextAttemptAtMeta,
        nextAttemptAt.isAcceptableOrUnknown(
          data['next_attempt_at']!,
          _nextAttemptAtMeta,
        ),
      );
    }
    if (data.containsKey('failed')) {
      context.handle(
        _failedMeta,
        failed.isAcceptableOrUnknown(data['failed']!, _failedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {capsuleId, slot};
  @override
  CapsuleMediaRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CapsuleMediaRow(
      capsuleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}capsule_id'],
      )!,
      slot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}slot'],
      )!,
      file: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file'],
      ),
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      ),
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      nextAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_attempt_at'],
      ),
      failed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}failed'],
      )!,
    );
  }

  @override
  $CapsuleMediaTable createAlias(String alias) {
    return $CapsuleMediaTable(attachedDatabase, alias);
  }
}

class CapsuleMediaRow extends DataClass implements Insertable<CapsuleMediaRow> {
  final String capsuleId;
  final String slot;
  final String? file;
  final String? path;

  /// Failed uploads, and when to try again (uploads keep retrying after the
  /// seal was pushed without them).
  final int attempts;
  final DateTime? nextAttemptAt;

  /// The upload can never succeed (e.g. too large): stop trying.
  final bool failed;
  const CapsuleMediaRow({
    required this.capsuleId,
    required this.slot,
    this.file,
    this.path,
    required this.attempts,
    this.nextAttemptAt,
    required this.failed,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['capsule_id'] = Variable<String>(capsuleId);
    map['slot'] = Variable<String>(slot);
    if (!nullToAbsent || file != null) {
      map['file'] = Variable<String>(file);
    }
    if (!nullToAbsent || path != null) {
      map['path'] = Variable<String>(path);
    }
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || nextAttemptAt != null) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt);
    }
    map['failed'] = Variable<bool>(failed);
    return map;
  }

  CapsuleMediaCompanion toCompanion(bool nullToAbsent) {
    return CapsuleMediaCompanion(
      capsuleId: Value(capsuleId),
      slot: Value(slot),
      file: file == null && nullToAbsent ? const Value.absent() : Value(file),
      path: path == null && nullToAbsent ? const Value.absent() : Value(path),
      attempts: Value(attempts),
      nextAttemptAt: nextAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextAttemptAt),
      failed: Value(failed),
    );
  }

  factory CapsuleMediaRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CapsuleMediaRow(
      capsuleId: serializer.fromJson<String>(json['capsuleId']),
      slot: serializer.fromJson<String>(json['slot']),
      file: serializer.fromJson<String?>(json['file']),
      path: serializer.fromJson<String?>(json['path']),
      attempts: serializer.fromJson<int>(json['attempts']),
      nextAttemptAt: serializer.fromJson<DateTime?>(json['nextAttemptAt']),
      failed: serializer.fromJson<bool>(json['failed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'capsuleId': serializer.toJson<String>(capsuleId),
      'slot': serializer.toJson<String>(slot),
      'file': serializer.toJson<String?>(file),
      'path': serializer.toJson<String?>(path),
      'attempts': serializer.toJson<int>(attempts),
      'nextAttemptAt': serializer.toJson<DateTime?>(nextAttemptAt),
      'failed': serializer.toJson<bool>(failed),
    };
  }

  CapsuleMediaRow copyWith({
    String? capsuleId,
    String? slot,
    Value<String?> file = const Value.absent(),
    Value<String?> path = const Value.absent(),
    int? attempts,
    Value<DateTime?> nextAttemptAt = const Value.absent(),
    bool? failed,
  }) => CapsuleMediaRow(
    capsuleId: capsuleId ?? this.capsuleId,
    slot: slot ?? this.slot,
    file: file.present ? file.value : this.file,
    path: path.present ? path.value : this.path,
    attempts: attempts ?? this.attempts,
    nextAttemptAt: nextAttemptAt.present
        ? nextAttemptAt.value
        : this.nextAttemptAt,
    failed: failed ?? this.failed,
  );
  CapsuleMediaRow copyWithCompanion(CapsuleMediaCompanion data) {
    return CapsuleMediaRow(
      capsuleId: data.capsuleId.present ? data.capsuleId.value : this.capsuleId,
      slot: data.slot.present ? data.slot.value : this.slot,
      file: data.file.present ? data.file.value : this.file,
      path: data.path.present ? data.path.value : this.path,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      nextAttemptAt: data.nextAttemptAt.present
          ? data.nextAttemptAt.value
          : this.nextAttemptAt,
      failed: data.failed.present ? data.failed.value : this.failed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CapsuleMediaRow(')
          ..write('capsuleId: $capsuleId, ')
          ..write('slot: $slot, ')
          ..write('file: $file, ')
          ..write('path: $path, ')
          ..write('attempts: $attempts, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('failed: $failed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(capsuleId, slot, file, path, attempts, nextAttemptAt, failed);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CapsuleMediaRow &&
          other.capsuleId == this.capsuleId &&
          other.slot == this.slot &&
          other.file == this.file &&
          other.path == this.path &&
          other.attempts == this.attempts &&
          other.nextAttemptAt == this.nextAttemptAt &&
          other.failed == this.failed);
}

class CapsuleMediaCompanion extends UpdateCompanion<CapsuleMediaRow> {
  final Value<String> capsuleId;
  final Value<String> slot;
  final Value<String?> file;
  final Value<String?> path;
  final Value<int> attempts;
  final Value<DateTime?> nextAttemptAt;
  final Value<bool> failed;
  final Value<int> rowid;
  const CapsuleMediaCompanion({
    this.capsuleId = const Value.absent(),
    this.slot = const Value.absent(),
    this.file = const Value.absent(),
    this.path = const Value.absent(),
    this.attempts = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.failed = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CapsuleMediaCompanion.insert({
    required String capsuleId,
    required String slot,
    this.file = const Value.absent(),
    this.path = const Value.absent(),
    this.attempts = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.failed = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : capsuleId = Value(capsuleId),
       slot = Value(slot);
  static Insertable<CapsuleMediaRow> custom({
    Expression<String>? capsuleId,
    Expression<String>? slot,
    Expression<String>? file,
    Expression<String>? path,
    Expression<int>? attempts,
    Expression<DateTime>? nextAttemptAt,
    Expression<bool>? failed,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (capsuleId != null) 'capsule_id': capsuleId,
      if (slot != null) 'slot': slot,
      if (file != null) 'file': file,
      if (path != null) 'path': path,
      if (attempts != null) 'attempts': attempts,
      if (nextAttemptAt != null) 'next_attempt_at': nextAttemptAt,
      if (failed != null) 'failed': failed,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CapsuleMediaCompanion copyWith({
    Value<String>? capsuleId,
    Value<String>? slot,
    Value<String?>? file,
    Value<String?>? path,
    Value<int>? attempts,
    Value<DateTime?>? nextAttemptAt,
    Value<bool>? failed,
    Value<int>? rowid,
  }) {
    return CapsuleMediaCompanion(
      capsuleId: capsuleId ?? this.capsuleId,
      slot: slot ?? this.slot,
      file: file ?? this.file,
      path: path ?? this.path,
      attempts: attempts ?? this.attempts,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      failed: failed ?? this.failed,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (capsuleId.present) {
      map['capsule_id'] = Variable<String>(capsuleId.value);
    }
    if (slot.present) {
      map['slot'] = Variable<String>(slot.value);
    }
    if (file.present) {
      map['file'] = Variable<String>(file.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (nextAttemptAt.present) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt.value);
    }
    if (failed.present) {
      map['failed'] = Variable<bool>(failed.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CapsuleMediaCompanion(')
          ..write('capsuleId: $capsuleId, ')
          ..write('slot: $slot, ')
          ..write('file: $file, ')
          ..write('path: $path, ')
          ..write('attempts: $attempts, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('failed: $failed, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LoomConstellationsTable extends LoomConstellations
    with TableInfo<$LoomConstellationsTable, LoomConstellationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LoomConstellationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _starsMeta = const VerificationMeta('stars');
  @override
  late final GeneratedColumn<String> stars = GeneratedColumn<String>(
    'stars',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _linksMeta = const VerificationMeta('links');
  @override
  late final GeneratedColumn<String> links = GeneratedColumn<String>(
    'links',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _meaningMeta = const VerificationMeta(
    'meaning',
  );
  @override
  late final GeneratedColumn<String> meaning = GeneratedColumn<String>(
    'meaning',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localDayMeta = const VerificationMeta(
    'localDay',
  );
  @override
  late final GeneratedColumn<String> localDay = GeneratedColumn<String>(
    'local_day',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceTsMeta = const VerificationMeta(
    'deviceTs',
  );
  @override
  late final GeneratedColumn<DateTime> deviceTs = GeneratedColumn<DateTime>(
    'device_ts',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tzMeta = const VerificationMeta('tz');
  @override
  late final GeneratedColumn<String> tz = GeneratedColumn<String>(
    'tz',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncedMeta = const VerificationMeta('synced');
  @override
  late final GeneratedColumn<bool> synced = GeneratedColumn<bool>(
    'synced',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("synced" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    stars,
    links,
    meaning,
    localDay,
    deviceTs,
    tz,
    deletedAt,
    synced,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'loom_constellations';
  @override
  VerificationContext validateIntegrity(
    Insertable<LoomConstellationRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('stars')) {
      context.handle(
        _starsMeta,
        stars.isAcceptableOrUnknown(data['stars']!, _starsMeta),
      );
    }
    if (data.containsKey('links')) {
      context.handle(
        _linksMeta,
        links.isAcceptableOrUnknown(data['links']!, _linksMeta),
      );
    }
    if (data.containsKey('meaning')) {
      context.handle(
        _meaningMeta,
        meaning.isAcceptableOrUnknown(data['meaning']!, _meaningMeta),
      );
    }
    if (data.containsKey('local_day')) {
      context.handle(
        _localDayMeta,
        localDay.isAcceptableOrUnknown(data['local_day']!, _localDayMeta),
      );
    } else if (isInserting) {
      context.missing(_localDayMeta);
    }
    if (data.containsKey('device_ts')) {
      context.handle(
        _deviceTsMeta,
        deviceTs.isAcceptableOrUnknown(data['device_ts']!, _deviceTsMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceTsMeta);
    }
    if (data.containsKey('tz')) {
      context.handle(_tzMeta, tz.isAcceptableOrUnknown(data['tz']!, _tzMeta));
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('synced')) {
      context.handle(
        _syncedMeta,
        synced.isAcceptableOrUnknown(data['synced']!, _syncedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LoomConstellationRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LoomConstellationRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      stars: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stars'],
      ),
      links: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}links'],
      ),
      meaning: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meaning'],
      ),
      localDay: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_day'],
      )!,
      deviceTs: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}device_ts'],
      )!,
      tz: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tz'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      synced: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}synced'],
      )!,
    );
  }

  @override
  $LoomConstellationsTable createAlias(String alias) {
    return $LoomConstellationsTable(attachedDatabase, alias);
  }
}

class LoomConstellationRow extends DataClass
    implements Insertable<LoomConstellationRow> {
  final String id;
  final String? stars;
  final String? links;
  final String? meaning;

  /// The Aura day it was kept (the per-day limit).
  final String localDay;
  final DateTime deviceTs;
  final String? tz;
  final DateTime? deletedAt;

  /// The server holds it (pushed and applied, or pulled).
  final bool synced;
  const LoomConstellationRow({
    required this.id,
    this.stars,
    this.links,
    this.meaning,
    required this.localDay,
    required this.deviceTs,
    this.tz,
    this.deletedAt,
    required this.synced,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || stars != null) {
      map['stars'] = Variable<String>(stars);
    }
    if (!nullToAbsent || links != null) {
      map['links'] = Variable<String>(links);
    }
    if (!nullToAbsent || meaning != null) {
      map['meaning'] = Variable<String>(meaning);
    }
    map['local_day'] = Variable<String>(localDay);
    map['device_ts'] = Variable<DateTime>(deviceTs);
    if (!nullToAbsent || tz != null) {
      map['tz'] = Variable<String>(tz);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['synced'] = Variable<bool>(synced);
    return map;
  }

  LoomConstellationsCompanion toCompanion(bool nullToAbsent) {
    return LoomConstellationsCompanion(
      id: Value(id),
      stars: stars == null && nullToAbsent
          ? const Value.absent()
          : Value(stars),
      links: links == null && nullToAbsent
          ? const Value.absent()
          : Value(links),
      meaning: meaning == null && nullToAbsent
          ? const Value.absent()
          : Value(meaning),
      localDay: Value(localDay),
      deviceTs: Value(deviceTs),
      tz: tz == null && nullToAbsent ? const Value.absent() : Value(tz),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      synced: Value(synced),
    );
  }

  factory LoomConstellationRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LoomConstellationRow(
      id: serializer.fromJson<String>(json['id']),
      stars: serializer.fromJson<String?>(json['stars']),
      links: serializer.fromJson<String?>(json['links']),
      meaning: serializer.fromJson<String?>(json['meaning']),
      localDay: serializer.fromJson<String>(json['localDay']),
      deviceTs: serializer.fromJson<DateTime>(json['deviceTs']),
      tz: serializer.fromJson<String?>(json['tz']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      synced: serializer.fromJson<bool>(json['synced']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'stars': serializer.toJson<String?>(stars),
      'links': serializer.toJson<String?>(links),
      'meaning': serializer.toJson<String?>(meaning),
      'localDay': serializer.toJson<String>(localDay),
      'deviceTs': serializer.toJson<DateTime>(deviceTs),
      'tz': serializer.toJson<String?>(tz),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'synced': serializer.toJson<bool>(synced),
    };
  }

  LoomConstellationRow copyWith({
    String? id,
    Value<String?> stars = const Value.absent(),
    Value<String?> links = const Value.absent(),
    Value<String?> meaning = const Value.absent(),
    String? localDay,
    DateTime? deviceTs,
    Value<String?> tz = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
    bool? synced,
  }) => LoomConstellationRow(
    id: id ?? this.id,
    stars: stars.present ? stars.value : this.stars,
    links: links.present ? links.value : this.links,
    meaning: meaning.present ? meaning.value : this.meaning,
    localDay: localDay ?? this.localDay,
    deviceTs: deviceTs ?? this.deviceTs,
    tz: tz.present ? tz.value : this.tz,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    synced: synced ?? this.synced,
  );
  LoomConstellationRow copyWithCompanion(LoomConstellationsCompanion data) {
    return LoomConstellationRow(
      id: data.id.present ? data.id.value : this.id,
      stars: data.stars.present ? data.stars.value : this.stars,
      links: data.links.present ? data.links.value : this.links,
      meaning: data.meaning.present ? data.meaning.value : this.meaning,
      localDay: data.localDay.present ? data.localDay.value : this.localDay,
      deviceTs: data.deviceTs.present ? data.deviceTs.value : this.deviceTs,
      tz: data.tz.present ? data.tz.value : this.tz,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      synced: data.synced.present ? data.synced.value : this.synced,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LoomConstellationRow(')
          ..write('id: $id, ')
          ..write('stars: $stars, ')
          ..write('links: $links, ')
          ..write('meaning: $meaning, ')
          ..write('localDay: $localDay, ')
          ..write('deviceTs: $deviceTs, ')
          ..write('tz: $tz, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('synced: $synced')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    stars,
    links,
    meaning,
    localDay,
    deviceTs,
    tz,
    deletedAt,
    synced,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LoomConstellationRow &&
          other.id == this.id &&
          other.stars == this.stars &&
          other.links == this.links &&
          other.meaning == this.meaning &&
          other.localDay == this.localDay &&
          other.deviceTs == this.deviceTs &&
          other.tz == this.tz &&
          other.deletedAt == this.deletedAt &&
          other.synced == this.synced);
}

class LoomConstellationsCompanion
    extends UpdateCompanion<LoomConstellationRow> {
  final Value<String> id;
  final Value<String?> stars;
  final Value<String?> links;
  final Value<String?> meaning;
  final Value<String> localDay;
  final Value<DateTime> deviceTs;
  final Value<String?> tz;
  final Value<DateTime?> deletedAt;
  final Value<bool> synced;
  final Value<int> rowid;
  const LoomConstellationsCompanion({
    this.id = const Value.absent(),
    this.stars = const Value.absent(),
    this.links = const Value.absent(),
    this.meaning = const Value.absent(),
    this.localDay = const Value.absent(),
    this.deviceTs = const Value.absent(),
    this.tz = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.synced = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LoomConstellationsCompanion.insert({
    required String id,
    this.stars = const Value.absent(),
    this.links = const Value.absent(),
    this.meaning = const Value.absent(),
    required String localDay,
    required DateTime deviceTs,
    this.tz = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.synced = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       localDay = Value(localDay),
       deviceTs = Value(deviceTs);
  static Insertable<LoomConstellationRow> custom({
    Expression<String>? id,
    Expression<String>? stars,
    Expression<String>? links,
    Expression<String>? meaning,
    Expression<String>? localDay,
    Expression<DateTime>? deviceTs,
    Expression<String>? tz,
    Expression<DateTime>? deletedAt,
    Expression<bool>? synced,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (stars != null) 'stars': stars,
      if (links != null) 'links': links,
      if (meaning != null) 'meaning': meaning,
      if (localDay != null) 'local_day': localDay,
      if (deviceTs != null) 'device_ts': deviceTs,
      if (tz != null) 'tz': tz,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (synced != null) 'synced': synced,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LoomConstellationsCompanion copyWith({
    Value<String>? id,
    Value<String?>? stars,
    Value<String?>? links,
    Value<String?>? meaning,
    Value<String>? localDay,
    Value<DateTime>? deviceTs,
    Value<String?>? tz,
    Value<DateTime?>? deletedAt,
    Value<bool>? synced,
    Value<int>? rowid,
  }) {
    return LoomConstellationsCompanion(
      id: id ?? this.id,
      stars: stars ?? this.stars,
      links: links ?? this.links,
      meaning: meaning ?? this.meaning,
      localDay: localDay ?? this.localDay,
      deviceTs: deviceTs ?? this.deviceTs,
      tz: tz ?? this.tz,
      deletedAt: deletedAt ?? this.deletedAt,
      synced: synced ?? this.synced,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (stars.present) {
      map['stars'] = Variable<String>(stars.value);
    }
    if (links.present) {
      map['links'] = Variable<String>(links.value);
    }
    if (meaning.present) {
      map['meaning'] = Variable<String>(meaning.value);
    }
    if (localDay.present) {
      map['local_day'] = Variable<String>(localDay.value);
    }
    if (deviceTs.present) {
      map['device_ts'] = Variable<DateTime>(deviceTs.value);
    }
    if (tz.present) {
      map['tz'] = Variable<String>(tz.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (synced.present) {
      map['synced'] = Variable<bool>(synced.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LoomConstellationsCompanion(')
          ..write('id: $id, ')
          ..write('stars: $stars, ')
          ..write('links: $links, ')
          ..write('meaning: $meaning, ')
          ..write('localDay: $localDay, ')
          ..write('deviceTs: $deviceTs, ')
          ..write('tz: $tz, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('synced: $synced, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CheckInsTable checkIns = $CheckInsTable(this);
  late final $HabitsTable habits = $HabitsTable(this);
  late final $HabitLogsTable habitLogs = $HabitLogsTable(this);
  late final $OutboxTable outbox = $OutboxTable(this);
  late final $DeadLettersTable deadLetters = $DeadLettersTable(this);
  late final $KeyValuesTable keyValues = $KeyValuesTable(this);
  late final $CapsulesTable capsules = $CapsulesTable(this);
  late final $CapsuleMediaTable capsuleMedia = $CapsuleMediaTable(this);
  late final $LoomConstellationsTable loomConstellations =
      $LoomConstellationsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    checkIns,
    habits,
    habitLogs,
    outbox,
    deadLetters,
    keyValues,
    capsules,
    capsuleMedia,
    loomConstellations,
  ];
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}

typedef $$CheckInsTableCreateCompanionBuilder = CheckInsCompanion Function({
  required String id,
  required String moodId,
  required String quadrant,
  Value<List<String>> tags,
  Value<String?> note,
  required String localDay,
  required DateTime deviceTs,
  required int tzOffsetMinutes,
  Value<String?> tz,
  Value<String> source,
  Value<DateTime?> deletedAt,
  Value<bool> synced,
  Value<bool> noteLocked,
  Value<String?> voiceFile,
  Value<int?> voiceMs,
  Value<String?> voicePath,
  Value<int> rowid,
});
typedef $$CheckInsTableUpdateCompanionBuilder = CheckInsCompanion Function({
  Value<String> id,
  Value<String> moodId,
  Value<String> quadrant,
  Value<List<String>> tags,
  Value<String?> note,
  Value<String> localDay,
  Value<DateTime> deviceTs,
  Value<int> tzOffsetMinutes,
  Value<String?> tz,
  Value<String> source,
  Value<DateTime?> deletedAt,
  Value<bool> synced,
  Value<bool> noteLocked,
  Value<String?> voiceFile,
  Value<int?> voiceMs,
  Value<String?> voicePath,
  Value<int> rowid,
});

class $$CheckInsTableFilterComposer
    extends Composer<_$AppDatabase, $CheckInsTable> {
  $$CheckInsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get moodId => $composableBuilder(
    column: $table.moodId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get quadrant => $composableBuilder(
    column: $table.quadrant,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<List<String>, List<String>, String> get tags =>
      $composableBuilder(
        column: $table.tags,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localDay => $composableBuilder(
    column: $table.localDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deviceTs => $composableBuilder(
    column: $table.deviceTs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tzOffsetMinutes => $composableBuilder(
    column: $table.tzOffsetMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tz => $composableBuilder(
    column: $table.tz,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get noteLocked => $composableBuilder(
    column: $table.noteLocked,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get voiceFile => $composableBuilder(
    column: $table.voiceFile,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get voiceMs => $composableBuilder(
    column: $table.voiceMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get voicePath => $composableBuilder(
    column: $table.voicePath,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CheckInsTableOrderingComposer
    extends Composer<_$AppDatabase, $CheckInsTable> {
  $$CheckInsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get moodId => $composableBuilder(
    column: $table.moodId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get quadrant => $composableBuilder(
    column: $table.quadrant,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localDay => $composableBuilder(
    column: $table.localDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deviceTs => $composableBuilder(
    column: $table.deviceTs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tzOffsetMinutes => $composableBuilder(
    column: $table.tzOffsetMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tz => $composableBuilder(
    column: $table.tz,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get noteLocked => $composableBuilder(
    column: $table.noteLocked,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get voiceFile => $composableBuilder(
    column: $table.voiceFile,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get voiceMs => $composableBuilder(
    column: $table.voiceMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get voicePath => $composableBuilder(
    column: $table.voicePath,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CheckInsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CheckInsTable> {
  $$CheckInsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get moodId =>
      $composableBuilder(column: $table.moodId, builder: (column) => column);

  GeneratedColumn<String> get quadrant =>
      $composableBuilder(column: $table.quadrant, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<String>, String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get localDay =>
      $composableBuilder(column: $table.localDay, builder: (column) => column);

  GeneratedColumn<DateTime> get deviceTs =>
      $composableBuilder(column: $table.deviceTs, builder: (column) => column);

  GeneratedColumn<int> get tzOffsetMinutes => $composableBuilder(
    column: $table.tzOffsetMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tz =>
      $composableBuilder(column: $table.tz, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<bool> get synced =>
      $composableBuilder(column: $table.synced, builder: (column) => column);

  GeneratedColumn<bool> get noteLocked => $composableBuilder(
    column: $table.noteLocked,
    builder: (column) => column,
  );

  GeneratedColumn<String> get voiceFile =>
      $composableBuilder(column: $table.voiceFile, builder: (column) => column);

  GeneratedColumn<int> get voiceMs =>
      $composableBuilder(column: $table.voiceMs, builder: (column) => column);

  GeneratedColumn<String> get voicePath =>
      $composableBuilder(column: $table.voicePath, builder: (column) => column);
}

class $$CheckInsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CheckInsTable,
          CheckInRow,
          $$CheckInsTableFilterComposer,
          $$CheckInsTableOrderingComposer,
          $$CheckInsTableAnnotationComposer,
          $$CheckInsTableCreateCompanionBuilder,
          $$CheckInsTableUpdateCompanionBuilder,
          (
            CheckInRow,
            BaseReferences<_$AppDatabase, $CheckInsTable, CheckInRow>,
          ),
          CheckInRow,
          PrefetchHooks Function()
        > {
  $$CheckInsTableTableManager(_$AppDatabase db, $CheckInsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CheckInsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CheckInsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CheckInsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> moodId = const Value.absent(),
                Value<String> quadrant = const Value.absent(),
                Value<List<String>> tags = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String> localDay = const Value.absent(),
                Value<DateTime> deviceTs = const Value.absent(),
                Value<int> tzOffsetMinutes = const Value.absent(),
                Value<String?> tz = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<bool> synced = const Value.absent(),
                Value<bool> noteLocked = const Value.absent(),
                Value<String?> voiceFile = const Value.absent(),
                Value<int?> voiceMs = const Value.absent(),
                Value<String?> voicePath = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CheckInsCompanion(
                id: id,
                moodId: moodId,
                quadrant: quadrant,
                tags: tags,
                note: note,
                localDay: localDay,
                deviceTs: deviceTs,
                tzOffsetMinutes: tzOffsetMinutes,
                tz: tz,
                source: source,
                deletedAt: deletedAt,
                synced: synced,
                noteLocked: noteLocked,
                voiceFile: voiceFile,
                voiceMs: voiceMs,
                voicePath: voicePath,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String moodId,
                required String quadrant,
                Value<List<String>> tags = const Value.absent(),
                Value<String?> note = const Value.absent(),
                required String localDay,
                required DateTime deviceTs,
                required int tzOffsetMinutes,
                Value<String?> tz = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<bool> synced = const Value.absent(),
                Value<bool> noteLocked = const Value.absent(),
                Value<String?> voiceFile = const Value.absent(),
                Value<int?> voiceMs = const Value.absent(),
                Value<String?> voicePath = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CheckInsCompanion.insert(
                id: id,
                moodId: moodId,
                quadrant: quadrant,
                tags: tags,
                note: note,
                localDay: localDay,
                deviceTs: deviceTs,
                tzOffsetMinutes: tzOffsetMinutes,
                tz: tz,
                source: source,
                deletedAt: deletedAt,
                synced: synced,
                noteLocked: noteLocked,
                voiceFile: voiceFile,
                voiceMs: voiceMs,
                voicePath: voicePath,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CheckInsTable, CheckInRow>(table),
                  BaseReferences<_$AppDatabase, $CheckInsTable, CheckInRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CheckInsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CheckInsTable,
      CheckInRow,
      $$CheckInsTableFilterComposer,
      $$CheckInsTableOrderingComposer,
      $$CheckInsTableAnnotationComposer,
      $$CheckInsTableCreateCompanionBuilder,
      $$CheckInsTableUpdateCompanionBuilder,
      (CheckInRow, BaseReferences<_$AppDatabase, $CheckInsTable, CheckInRow>),
      CheckInRow,
      PrefetchHooks Function()
    >;
typedef $$HabitsTableCreateCompanionBuilder = HabitsCompanion Function({
  required String id,
  required String kind,
  Value<String?> presetKey,
  Value<String?> name,
  Value<bool> active,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<bool> synced,
  Value<String?> committedFrom,
  Value<String?> pausedThrough,
  Value<int> rowid,
});
typedef $$HabitsTableUpdateCompanionBuilder = HabitsCompanion Function({
  Value<String> id,
  Value<String> kind,
  Value<String?> presetKey,
  Value<String?> name,
  Value<bool> active,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<bool> synced,
  Value<String?> committedFrom,
  Value<String?> pausedThrough,
  Value<int> rowid,
});

class $$HabitsTableFilterComposer
    extends Composer<_$AppDatabase, $HabitsTable> {
  $$HabitsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get presetKey => $composableBuilder(
    column: $table.presetKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get committedFrom => $composableBuilder(
    column: $table.committedFrom,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pausedThrough => $composableBuilder(
    column: $table.pausedThrough,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HabitsTableOrderingComposer
    extends Composer<_$AppDatabase, $HabitsTable> {
  $$HabitsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get presetKey => $composableBuilder(
    column: $table.presetKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get committedFrom => $composableBuilder(
    column: $table.committedFrom,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pausedThrough => $composableBuilder(
    column: $table.pausedThrough,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HabitsTableAnnotationComposer
    extends Composer<_$AppDatabase, $HabitsTable> {
  $$HabitsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get presetKey =>
      $composableBuilder(column: $table.presetKey, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<bool> get active =>
      $composableBuilder(column: $table.active, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get synced =>
      $composableBuilder(column: $table.synced, builder: (column) => column);

  GeneratedColumn<String> get committedFrom => $composableBuilder(
    column: $table.committedFrom,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pausedThrough => $composableBuilder(
    column: $table.pausedThrough,
    builder: (column) => column,
  );
}

class $$HabitsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HabitsTable,
          HabitRow,
          $$HabitsTableFilterComposer,
          $$HabitsTableOrderingComposer,
          $$HabitsTableAnnotationComposer,
          $$HabitsTableCreateCompanionBuilder,
          $$HabitsTableUpdateCompanionBuilder,
          (HabitRow, BaseReferences<_$AppDatabase, $HabitsTable, HabitRow>),
          HabitRow,
          PrefetchHooks Function()
        > {
  $$HabitsTableTableManager(_$AppDatabase db, $HabitsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HabitsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HabitsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HabitsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> presetKey = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<bool> active = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> synced = const Value.absent(),
                Value<String?> committedFrom = const Value.absent(),
                Value<String?> pausedThrough = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HabitsCompanion(
                id: id,
                kind: kind,
                presetKey: presetKey,
                name: name,
                active: active,
                createdAt: createdAt,
                updatedAt: updatedAt,
                synced: synced,
                committedFrom: committedFrom,
                pausedThrough: pausedThrough,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String kind,
                Value<String?> presetKey = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<bool> active = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<bool> synced = const Value.absent(),
                Value<String?> committedFrom = const Value.absent(),
                Value<String?> pausedThrough = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HabitsCompanion.insert(
                id: id,
                kind: kind,
                presetKey: presetKey,
                name: name,
                active: active,
                createdAt: createdAt,
                updatedAt: updatedAt,
                synced: synced,
                committedFrom: committedFrom,
                pausedThrough: pausedThrough,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$HabitsTable, HabitRow>(table),
                  BaseReferences<_$AppDatabase, $HabitsTable, HabitRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HabitsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HabitsTable,
      HabitRow,
      $$HabitsTableFilterComposer,
      $$HabitsTableOrderingComposer,
      $$HabitsTableAnnotationComposer,
      $$HabitsTableCreateCompanionBuilder,
      $$HabitsTableUpdateCompanionBuilder,
      (HabitRow, BaseReferences<_$AppDatabase, $HabitsTable, HabitRow>),
      HabitRow,
      PrefetchHooks Function()
    >;
typedef $$HabitLogsTableCreateCompanionBuilder = HabitLogsCompanion Function({
  required String id,
  required String habitId,
  required String localDay,
  required DateTime deviceTs,
  Value<String?> tz,
  Value<DateTime?> deletedAt,
  Value<bool> synced,
  Value<int> rowid,
});
typedef $$HabitLogsTableUpdateCompanionBuilder = HabitLogsCompanion Function({
  Value<String> id,
  Value<String> habitId,
  Value<String> localDay,
  Value<DateTime> deviceTs,
  Value<String?> tz,
  Value<DateTime?> deletedAt,
  Value<bool> synced,
  Value<int> rowid,
});

class $$HabitLogsTableFilterComposer
    extends Composer<_$AppDatabase, $HabitLogsTable> {
  $$HabitLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get habitId => $composableBuilder(
    column: $table.habitId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localDay => $composableBuilder(
    column: $table.localDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deviceTs => $composableBuilder(
    column: $table.deviceTs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tz => $composableBuilder(
    column: $table.tz,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HabitLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $HabitLogsTable> {
  $$HabitLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get habitId => $composableBuilder(
    column: $table.habitId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localDay => $composableBuilder(
    column: $table.localDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deviceTs => $composableBuilder(
    column: $table.deviceTs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tz => $composableBuilder(
    column: $table.tz,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HabitLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $HabitLogsTable> {
  $$HabitLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get habitId =>
      $composableBuilder(column: $table.habitId, builder: (column) => column);

  GeneratedColumn<String> get localDay =>
      $composableBuilder(column: $table.localDay, builder: (column) => column);

  GeneratedColumn<DateTime> get deviceTs =>
      $composableBuilder(column: $table.deviceTs, builder: (column) => column);

  GeneratedColumn<String> get tz =>
      $composableBuilder(column: $table.tz, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<bool> get synced =>
      $composableBuilder(column: $table.synced, builder: (column) => column);
}

class $$HabitLogsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HabitLogsTable,
          HabitLogRow,
          $$HabitLogsTableFilterComposer,
          $$HabitLogsTableOrderingComposer,
          $$HabitLogsTableAnnotationComposer,
          $$HabitLogsTableCreateCompanionBuilder,
          $$HabitLogsTableUpdateCompanionBuilder,
          (
            HabitLogRow,
            BaseReferences<_$AppDatabase, $HabitLogsTable, HabitLogRow>,
          ),
          HabitLogRow,
          PrefetchHooks Function()
        > {
  $$HabitLogsTableTableManager(_$AppDatabase db, $HabitLogsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HabitLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HabitLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HabitLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> habitId = const Value.absent(),
                Value<String> localDay = const Value.absent(),
                Value<DateTime> deviceTs = const Value.absent(),
                Value<String?> tz = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<bool> synced = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HabitLogsCompanion(
                id: id,
                habitId: habitId,
                localDay: localDay,
                deviceTs: deviceTs,
                tz: tz,
                deletedAt: deletedAt,
                synced: synced,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String habitId,
                required String localDay,
                required DateTime deviceTs,
                Value<String?> tz = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<bool> synced = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HabitLogsCompanion.insert(
                id: id,
                habitId: habitId,
                localDay: localDay,
                deviceTs: deviceTs,
                tz: tz,
                deletedAt: deletedAt,
                synced: synced,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$HabitLogsTable, HabitLogRow>(table),
                  BaseReferences<_$AppDatabase, $HabitLogsTable, HabitLogRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HabitLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HabitLogsTable,
      HabitLogRow,
      $$HabitLogsTableFilterComposer,
      $$HabitLogsTableOrderingComposer,
      $$HabitLogsTableAnnotationComposer,
      $$HabitLogsTableCreateCompanionBuilder,
      $$HabitLogsTableUpdateCompanionBuilder,
      (
        HabitLogRow,
        BaseReferences<_$AppDatabase, $HabitLogsTable, HabitLogRow>,
      ),
      HabitLogRow,
      PrefetchHooks Function()
    >;
typedef $$OutboxTableCreateCompanionBuilder = OutboxCompanion Function({
  Value<int> seq,
  required String mutationId,
  required String entity,
  required String op,
  required String entityId,
  required DateTime deviceTs,
  required String localDay,
  Value<String?> tz,
  required String payload,
  Value<bool> needsNote,
  Value<int> attempts,
  Value<DateTime?> nextAttemptAt,
  required DateTime createdAt,
  Value<bool> needsMedia,
  Value<int> mediaAttempts,
});
typedef $$OutboxTableUpdateCompanionBuilder = OutboxCompanion Function({
  Value<int> seq,
  Value<String> mutationId,
  Value<String> entity,
  Value<String> op,
  Value<String> entityId,
  Value<DateTime> deviceTs,
  Value<String> localDay,
  Value<String?> tz,
  Value<String> payload,
  Value<bool> needsNote,
  Value<int> attempts,
  Value<DateTime?> nextAttemptAt,
  Value<DateTime> createdAt,
  Value<bool> needsMedia,
  Value<int> mediaAttempts,
});

class $$OutboxTableFilterComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get op => $composableBuilder(
    column: $table.op,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deviceTs => $composableBuilder(
    column: $table.deviceTs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localDay => $composableBuilder(
    column: $table.localDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tz => $composableBuilder(
    column: $table.tz,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get needsNote => $composableBuilder(
    column: $table.needsNote,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get needsMedia => $composableBuilder(
    column: $table.needsMedia,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get mediaAttempts => $composableBuilder(
    column: $table.mediaAttempts,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OutboxTableOrderingComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get op => $composableBuilder(
    column: $table.op,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deviceTs => $composableBuilder(
    column: $table.deviceTs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localDay => $composableBuilder(
    column: $table.localDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tz => $composableBuilder(
    column: $table.tz,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get needsNote => $composableBuilder(
    column: $table.needsNote,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get needsMedia => $composableBuilder(
    column: $table.needsMedia,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get mediaAttempts => $composableBuilder(
    column: $table.mediaAttempts,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OutboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entity =>
      $composableBuilder(column: $table.entity, builder: (column) => column);

  GeneratedColumn<String> get op =>
      $composableBuilder(column: $table.op, builder: (column) => column);

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<DateTime> get deviceTs =>
      $composableBuilder(column: $table.deviceTs, builder: (column) => column);

  GeneratedColumn<String> get localDay =>
      $composableBuilder(column: $table.localDay, builder: (column) => column);

  GeneratedColumn<String> get tz =>
      $composableBuilder(column: $table.tz, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<bool> get needsNote =>
      $composableBuilder(column: $table.needsNote, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<bool> get needsMedia => $composableBuilder(
    column: $table.needsMedia,
    builder: (column) => column,
  );

  GeneratedColumn<int> get mediaAttempts => $composableBuilder(
    column: $table.mediaAttempts,
    builder: (column) => column,
  );
}

class $$OutboxTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OutboxTable,
          OutboxRow,
          $$OutboxTableFilterComposer,
          $$OutboxTableOrderingComposer,
          $$OutboxTableAnnotationComposer,
          $$OutboxTableCreateCompanionBuilder,
          $$OutboxTableUpdateCompanionBuilder,
          (OutboxRow, BaseReferences<_$AppDatabase, $OutboxTable, OutboxRow>),
          OutboxRow,
          PrefetchHooks Function()
        > {
  $$OutboxTableTableManager(_$AppDatabase db, $OutboxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                Value<String> mutationId = const Value.absent(),
                Value<String> entity = const Value.absent(),
                Value<String> op = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<DateTime> deviceTs = const Value.absent(),
                Value<String> localDay = const Value.absent(),
                Value<String?> tz = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<bool> needsNote = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<DateTime?> nextAttemptAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<bool> needsMedia = const Value.absent(),
                Value<int> mediaAttempts = const Value.absent(),
              }) => OutboxCompanion(
                seq: seq,
                mutationId: mutationId,
                entity: entity,
                op: op,
                entityId: entityId,
                deviceTs: deviceTs,
                localDay: localDay,
                tz: tz,
                payload: payload,
                needsNote: needsNote,
                attempts: attempts,
                nextAttemptAt: nextAttemptAt,
                createdAt: createdAt,
                needsMedia: needsMedia,
                mediaAttempts: mediaAttempts,
              ),
          createCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                required String mutationId,
                required String entity,
                required String op,
                required String entityId,
                required DateTime deviceTs,
                required String localDay,
                Value<String?> tz = const Value.absent(),
                required String payload,
                Value<bool> needsNote = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<DateTime?> nextAttemptAt = const Value.absent(),
                required DateTime createdAt,
                Value<bool> needsMedia = const Value.absent(),
                Value<int> mediaAttempts = const Value.absent(),
              }) => OutboxCompanion.insert(
                seq: seq,
                mutationId: mutationId,
                entity: entity,
                op: op,
                entityId: entityId,
                deviceTs: deviceTs,
                localDay: localDay,
                tz: tz,
                payload: payload,
                needsNote: needsNote,
                attempts: attempts,
                nextAttemptAt: nextAttemptAt,
                createdAt: createdAt,
                needsMedia: needsMedia,
                mediaAttempts: mediaAttempts,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OutboxTable, OutboxRow>(table),
                  BaseReferences<_$AppDatabase, $OutboxTable, OutboxRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OutboxTable,
      OutboxRow,
      $$OutboxTableFilterComposer,
      $$OutboxTableOrderingComposer,
      $$OutboxTableAnnotationComposer,
      $$OutboxTableCreateCompanionBuilder,
      $$OutboxTableUpdateCompanionBuilder,
      (OutboxRow, BaseReferences<_$AppDatabase, $OutboxTable, OutboxRow>),
      OutboxRow,
      PrefetchHooks Function()
    >;
typedef $$DeadLettersTableCreateCompanionBuilder =
    DeadLettersCompanion Function({
      Value<int> seq,
      required String mutationId,
      required String entity,
      required String op,
      required String entityId,
      required String payload,
      required String reason,
      required DateTime failedAt,
      Value<DateTime?> deviceTs,
      Value<String?> localDay,
      Value<String?> tz,
    });
typedef $$DeadLettersTableUpdateCompanionBuilder =
    DeadLettersCompanion Function({
      Value<int> seq,
      Value<String> mutationId,
      Value<String> entity,
      Value<String> op,
      Value<String> entityId,
      Value<String> payload,
      Value<String> reason,
      Value<DateTime> failedAt,
      Value<DateTime?> deviceTs,
      Value<String?> localDay,
      Value<String?> tz,
    });

class $$DeadLettersTableFilterComposer
    extends Composer<_$AppDatabase, $DeadLettersTable> {
  $$DeadLettersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get op => $composableBuilder(
    column: $table.op,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get failedAt => $composableBuilder(
    column: $table.failedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deviceTs => $composableBuilder(
    column: $table.deviceTs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localDay => $composableBuilder(
    column: $table.localDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tz => $composableBuilder(
    column: $table.tz,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DeadLettersTableOrderingComposer
    extends Composer<_$AppDatabase, $DeadLettersTable> {
  $$DeadLettersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get op => $composableBuilder(
    column: $table.op,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get failedAt => $composableBuilder(
    column: $table.failedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deviceTs => $composableBuilder(
    column: $table.deviceTs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localDay => $composableBuilder(
    column: $table.localDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tz => $composableBuilder(
    column: $table.tz,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DeadLettersTableAnnotationComposer
    extends Composer<_$AppDatabase, $DeadLettersTable> {
  $$DeadLettersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get mutationId => $composableBuilder(
    column: $table.mutationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entity =>
      $composableBuilder(column: $table.entity, builder: (column) => column);

  GeneratedColumn<String> get op =>
      $composableBuilder(column: $table.op, builder: (column) => column);

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<DateTime> get failedAt =>
      $composableBuilder(column: $table.failedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deviceTs =>
      $composableBuilder(column: $table.deviceTs, builder: (column) => column);

  GeneratedColumn<String> get localDay =>
      $composableBuilder(column: $table.localDay, builder: (column) => column);

  GeneratedColumn<String> get tz =>
      $composableBuilder(column: $table.tz, builder: (column) => column);
}

class $$DeadLettersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DeadLettersTable,
          DeadLetterRow,
          $$DeadLettersTableFilterComposer,
          $$DeadLettersTableOrderingComposer,
          $$DeadLettersTableAnnotationComposer,
          $$DeadLettersTableCreateCompanionBuilder,
          $$DeadLettersTableUpdateCompanionBuilder,
          (
            DeadLetterRow,
            BaseReferences<_$AppDatabase, $DeadLettersTable, DeadLetterRow>,
          ),
          DeadLetterRow,
          PrefetchHooks Function()
        > {
  $$DeadLettersTableTableManager(_$AppDatabase db, $DeadLettersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DeadLettersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DeadLettersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DeadLettersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                Value<String> mutationId = const Value.absent(),
                Value<String> entity = const Value.absent(),
                Value<String> op = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<String> reason = const Value.absent(),
                Value<DateTime> failedAt = const Value.absent(),
                Value<DateTime?> deviceTs = const Value.absent(),
                Value<String?> localDay = const Value.absent(),
                Value<String?> tz = const Value.absent(),
              }) => DeadLettersCompanion(
                seq: seq,
                mutationId: mutationId,
                entity: entity,
                op: op,
                entityId: entityId,
                payload: payload,
                reason: reason,
                failedAt: failedAt,
                deviceTs: deviceTs,
                localDay: localDay,
                tz: tz,
              ),
          createCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                required String mutationId,
                required String entity,
                required String op,
                required String entityId,
                required String payload,
                required String reason,
                required DateTime failedAt,
                Value<DateTime?> deviceTs = const Value.absent(),
                Value<String?> localDay = const Value.absent(),
                Value<String?> tz = const Value.absent(),
              }) => DeadLettersCompanion.insert(
                seq: seq,
                mutationId: mutationId,
                entity: entity,
                op: op,
                entityId: entityId,
                payload: payload,
                reason: reason,
                failedAt: failedAt,
                deviceTs: deviceTs,
                localDay: localDay,
                tz: tz,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DeadLettersTable, DeadLetterRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $DeadLettersTable,
                    DeadLetterRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DeadLettersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DeadLettersTable,
      DeadLetterRow,
      $$DeadLettersTableFilterComposer,
      $$DeadLettersTableOrderingComposer,
      $$DeadLettersTableAnnotationComposer,
      $$DeadLettersTableCreateCompanionBuilder,
      $$DeadLettersTableUpdateCompanionBuilder,
      (
        DeadLetterRow,
        BaseReferences<_$AppDatabase, $DeadLettersTable, DeadLetterRow>,
      ),
      DeadLetterRow,
      PrefetchHooks Function()
    >;
typedef $$KeyValuesTableCreateCompanionBuilder = KeyValuesCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$KeyValuesTableUpdateCompanionBuilder = KeyValuesCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$KeyValuesTableFilterComposer
    extends Composer<_$AppDatabase, $KeyValuesTable> {
  $$KeyValuesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$KeyValuesTableOrderingComposer
    extends Composer<_$AppDatabase, $KeyValuesTable> {
  $$KeyValuesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$KeyValuesTableAnnotationComposer
    extends Composer<_$AppDatabase, $KeyValuesTable> {
  $$KeyValuesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$KeyValuesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $KeyValuesTable,
          KeyValueRow,
          $$KeyValuesTableFilterComposer,
          $$KeyValuesTableOrderingComposer,
          $$KeyValuesTableAnnotationComposer,
          $$KeyValuesTableCreateCompanionBuilder,
          $$KeyValuesTableUpdateCompanionBuilder,
          (
            KeyValueRow,
            BaseReferences<_$AppDatabase, $KeyValuesTable, KeyValueRow>,
          ),
          KeyValueRow,
          PrefetchHooks Function()
        > {
  $$KeyValuesTableTableManager(_$AppDatabase db, $KeyValuesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$KeyValuesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$KeyValuesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$KeyValuesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => KeyValuesCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => KeyValuesCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$KeyValuesTable, KeyValueRow>(table),
                  BaseReferences<_$AppDatabase, $KeyValuesTable, KeyValueRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$KeyValuesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $KeyValuesTable,
      KeyValueRow,
      $$KeyValuesTableFilterComposer,
      $$KeyValuesTableOrderingComposer,
      $$KeyValuesTableAnnotationComposer,
      $$KeyValuesTableCreateCompanionBuilder,
      $$KeyValuesTableUpdateCompanionBuilder,
      (
        KeyValueRow,
        BaseReferences<_$AppDatabase, $KeyValuesTable, KeyValueRow>,
      ),
      KeyValueRow,
      PrefetchHooks Function()
    >;
typedef $$CapsulesTableCreateCompanionBuilder = CapsulesCompanion Function({
  required String id,
  required String unlockType,
  Value<String?> unlockLocalDate,
  Value<String?> triggerMoodId,
  Value<String?> triggerQuadrant,
  Value<String?> payloadCt,
  Value<String?> payloadClear,
  required DateTime sealedAt,
  Value<String?> sealTz,
  Value<DateTime?> armedAt,
  Value<int> cycle,
  Value<DateTime?> firedAt,
  Value<DateTime?> cooldownUntil,
  Value<DateTime?> openedAt,
  Value<DateTime?> openedDeviceTs,
  Value<DateTime?> deletedAt,
  Value<DateTime?> serverUpdatedAt,
  Value<bool> synced,
  Value<String?> rejected,
  Value<DateTime?> notifyAt,
  Value<int> rowid,
});
typedef $$CapsulesTableUpdateCompanionBuilder = CapsulesCompanion Function({
  Value<String> id,
  Value<String> unlockType,
  Value<String?> unlockLocalDate,
  Value<String?> triggerMoodId,
  Value<String?> triggerQuadrant,
  Value<String?> payloadCt,
  Value<String?> payloadClear,
  Value<DateTime> sealedAt,
  Value<String?> sealTz,
  Value<DateTime?> armedAt,
  Value<int> cycle,
  Value<DateTime?> firedAt,
  Value<DateTime?> cooldownUntil,
  Value<DateTime?> openedAt,
  Value<DateTime?> openedDeviceTs,
  Value<DateTime?> deletedAt,
  Value<DateTime?> serverUpdatedAt,
  Value<bool> synced,
  Value<String?> rejected,
  Value<DateTime?> notifyAt,
  Value<int> rowid,
});

class $$CapsulesTableFilterComposer
    extends Composer<_$AppDatabase, $CapsulesTable> {
  $$CapsulesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unlockType => $composableBuilder(
    column: $table.unlockType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unlockLocalDate => $composableBuilder(
    column: $table.unlockLocalDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get triggerMoodId => $composableBuilder(
    column: $table.triggerMoodId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get triggerQuadrant => $composableBuilder(
    column: $table.triggerQuadrant,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadCt => $composableBuilder(
    column: $table.payloadCt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadClear => $composableBuilder(
    column: $table.payloadClear,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get sealedAt => $composableBuilder(
    column: $table.sealedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sealTz => $composableBuilder(
    column: $table.sealTz,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get armedAt => $composableBuilder(
    column: $table.armedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cycle => $composableBuilder(
    column: $table.cycle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get firedAt => $composableBuilder(
    column: $table.firedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cooldownUntil => $composableBuilder(
    column: $table.cooldownUntil,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get openedAt => $composableBuilder(
    column: $table.openedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get openedDeviceTs => $composableBuilder(
    column: $table.openedDeviceTs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get serverUpdatedAt => $composableBuilder(
    column: $table.serverUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rejected => $composableBuilder(
    column: $table.rejected,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get notifyAt => $composableBuilder(
    column: $table.notifyAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CapsulesTableOrderingComposer
    extends Composer<_$AppDatabase, $CapsulesTable> {
  $$CapsulesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unlockType => $composableBuilder(
    column: $table.unlockType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unlockLocalDate => $composableBuilder(
    column: $table.unlockLocalDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get triggerMoodId => $composableBuilder(
    column: $table.triggerMoodId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get triggerQuadrant => $composableBuilder(
    column: $table.triggerQuadrant,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadCt => $composableBuilder(
    column: $table.payloadCt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadClear => $composableBuilder(
    column: $table.payloadClear,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get sealedAt => $composableBuilder(
    column: $table.sealedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sealTz => $composableBuilder(
    column: $table.sealTz,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get armedAt => $composableBuilder(
    column: $table.armedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cycle => $composableBuilder(
    column: $table.cycle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get firedAt => $composableBuilder(
    column: $table.firedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cooldownUntil => $composableBuilder(
    column: $table.cooldownUntil,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get openedAt => $composableBuilder(
    column: $table.openedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get openedDeviceTs => $composableBuilder(
    column: $table.openedDeviceTs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get serverUpdatedAt => $composableBuilder(
    column: $table.serverUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rejected => $composableBuilder(
    column: $table.rejected,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get notifyAt => $composableBuilder(
    column: $table.notifyAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CapsulesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CapsulesTable> {
  $$CapsulesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get unlockType => $composableBuilder(
    column: $table.unlockType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get unlockLocalDate => $composableBuilder(
    column: $table.unlockLocalDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get triggerMoodId => $composableBuilder(
    column: $table.triggerMoodId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get triggerQuadrant => $composableBuilder(
    column: $table.triggerQuadrant,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadCt =>
      $composableBuilder(column: $table.payloadCt, builder: (column) => column);

  GeneratedColumn<String> get payloadClear => $composableBuilder(
    column: $table.payloadClear,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get sealedAt =>
      $composableBuilder(column: $table.sealedAt, builder: (column) => column);

  GeneratedColumn<String> get sealTz =>
      $composableBuilder(column: $table.sealTz, builder: (column) => column);

  GeneratedColumn<DateTime> get armedAt =>
      $composableBuilder(column: $table.armedAt, builder: (column) => column);

  GeneratedColumn<int> get cycle =>
      $composableBuilder(column: $table.cycle, builder: (column) => column);

  GeneratedColumn<DateTime> get firedAt =>
      $composableBuilder(column: $table.firedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get cooldownUntil => $composableBuilder(
    column: $table.cooldownUntil,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get openedAt =>
      $composableBuilder(column: $table.openedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get openedDeviceTs => $composableBuilder(
    column: $table.openedDeviceTs,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get serverUpdatedAt => $composableBuilder(
    column: $table.serverUpdatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get synced =>
      $composableBuilder(column: $table.synced, builder: (column) => column);

  GeneratedColumn<String> get rejected =>
      $composableBuilder(column: $table.rejected, builder: (column) => column);

  GeneratedColumn<DateTime> get notifyAt =>
      $composableBuilder(column: $table.notifyAt, builder: (column) => column);
}

class $$CapsulesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CapsulesTable,
          CapsuleRow,
          $$CapsulesTableFilterComposer,
          $$CapsulesTableOrderingComposer,
          $$CapsulesTableAnnotationComposer,
          $$CapsulesTableCreateCompanionBuilder,
          $$CapsulesTableUpdateCompanionBuilder,
          (
            CapsuleRow,
            BaseReferences<_$AppDatabase, $CapsulesTable, CapsuleRow>,
          ),
          CapsuleRow,
          PrefetchHooks Function()
        > {
  $$CapsulesTableTableManager(_$AppDatabase db, $CapsulesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CapsulesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CapsulesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CapsulesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> unlockType = const Value.absent(),
                Value<String?> unlockLocalDate = const Value.absent(),
                Value<String?> triggerMoodId = const Value.absent(),
                Value<String?> triggerQuadrant = const Value.absent(),
                Value<String?> payloadCt = const Value.absent(),
                Value<String?> payloadClear = const Value.absent(),
                Value<DateTime> sealedAt = const Value.absent(),
                Value<String?> sealTz = const Value.absent(),
                Value<DateTime?> armedAt = const Value.absent(),
                Value<int> cycle = const Value.absent(),
                Value<DateTime?> firedAt = const Value.absent(),
                Value<DateTime?> cooldownUntil = const Value.absent(),
                Value<DateTime?> openedAt = const Value.absent(),
                Value<DateTime?> openedDeviceTs = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<DateTime?> serverUpdatedAt = const Value.absent(),
                Value<bool> synced = const Value.absent(),
                Value<String?> rejected = const Value.absent(),
                Value<DateTime?> notifyAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CapsulesCompanion(
                id: id,
                unlockType: unlockType,
                unlockLocalDate: unlockLocalDate,
                triggerMoodId: triggerMoodId,
                triggerQuadrant: triggerQuadrant,
                payloadCt: payloadCt,
                payloadClear: payloadClear,
                sealedAt: sealedAt,
                sealTz: sealTz,
                armedAt: armedAt,
                cycle: cycle,
                firedAt: firedAt,
                cooldownUntil: cooldownUntil,
                openedAt: openedAt,
                openedDeviceTs: openedDeviceTs,
                deletedAt: deletedAt,
                serverUpdatedAt: serverUpdatedAt,
                synced: synced,
                rejected: rejected,
                notifyAt: notifyAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String unlockType,
                Value<String?> unlockLocalDate = const Value.absent(),
                Value<String?> triggerMoodId = const Value.absent(),
                Value<String?> triggerQuadrant = const Value.absent(),
                Value<String?> payloadCt = const Value.absent(),
                Value<String?> payloadClear = const Value.absent(),
                required DateTime sealedAt,
                Value<String?> sealTz = const Value.absent(),
                Value<DateTime?> armedAt = const Value.absent(),
                Value<int> cycle = const Value.absent(),
                Value<DateTime?> firedAt = const Value.absent(),
                Value<DateTime?> cooldownUntil = const Value.absent(),
                Value<DateTime?> openedAt = const Value.absent(),
                Value<DateTime?> openedDeviceTs = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<DateTime?> serverUpdatedAt = const Value.absent(),
                Value<bool> synced = const Value.absent(),
                Value<String?> rejected = const Value.absent(),
                Value<DateTime?> notifyAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CapsulesCompanion.insert(
                id: id,
                unlockType: unlockType,
                unlockLocalDate: unlockLocalDate,
                triggerMoodId: triggerMoodId,
                triggerQuadrant: triggerQuadrant,
                payloadCt: payloadCt,
                payloadClear: payloadClear,
                sealedAt: sealedAt,
                sealTz: sealTz,
                armedAt: armedAt,
                cycle: cycle,
                firedAt: firedAt,
                cooldownUntil: cooldownUntil,
                openedAt: openedAt,
                openedDeviceTs: openedDeviceTs,
                deletedAt: deletedAt,
                serverUpdatedAt: serverUpdatedAt,
                synced: synced,
                rejected: rejected,
                notifyAt: notifyAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CapsulesTable, CapsuleRow>(table),
                  BaseReferences<_$AppDatabase, $CapsulesTable, CapsuleRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CapsulesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CapsulesTable,
      CapsuleRow,
      $$CapsulesTableFilterComposer,
      $$CapsulesTableOrderingComposer,
      $$CapsulesTableAnnotationComposer,
      $$CapsulesTableCreateCompanionBuilder,
      $$CapsulesTableUpdateCompanionBuilder,
      (CapsuleRow, BaseReferences<_$AppDatabase, $CapsulesTable, CapsuleRow>),
      CapsuleRow,
      PrefetchHooks Function()
    >;
typedef $$CapsuleMediaTableCreateCompanionBuilder =
    CapsuleMediaCompanion Function({
      required String capsuleId,
      required String slot,
      Value<String?> file,
      Value<String?> path,
      Value<int> attempts,
      Value<DateTime?> nextAttemptAt,
      Value<bool> failed,
      Value<int> rowid,
    });
typedef $$CapsuleMediaTableUpdateCompanionBuilder =
    CapsuleMediaCompanion Function({
      Value<String> capsuleId,
      Value<String> slot,
      Value<String?> file,
      Value<String?> path,
      Value<int> attempts,
      Value<DateTime?> nextAttemptAt,
      Value<bool> failed,
      Value<int> rowid,
    });

class $$CapsuleMediaTableFilterComposer
    extends Composer<_$AppDatabase, $CapsuleMediaTable> {
  $$CapsuleMediaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get capsuleId => $composableBuilder(
    column: $table.capsuleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get slot => $composableBuilder(
    column: $table.slot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get file => $composableBuilder(
    column: $table.file,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get failed => $composableBuilder(
    column: $table.failed,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CapsuleMediaTableOrderingComposer
    extends Composer<_$AppDatabase, $CapsuleMediaTable> {
  $$CapsuleMediaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get capsuleId => $composableBuilder(
    column: $table.capsuleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get slot => $composableBuilder(
    column: $table.slot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get file => $composableBuilder(
    column: $table.file,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get failed => $composableBuilder(
    column: $table.failed,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CapsuleMediaTableAnnotationComposer
    extends Composer<_$AppDatabase, $CapsuleMediaTable> {
  $$CapsuleMediaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get capsuleId =>
      $composableBuilder(column: $table.capsuleId, builder: (column) => column);

  GeneratedColumn<String> get slot =>
      $composableBuilder(column: $table.slot, builder: (column) => column);

  GeneratedColumn<String> get file =>
      $composableBuilder(column: $table.file, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get failed =>
      $composableBuilder(column: $table.failed, builder: (column) => column);
}

class $$CapsuleMediaTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CapsuleMediaTable,
          CapsuleMediaRow,
          $$CapsuleMediaTableFilterComposer,
          $$CapsuleMediaTableOrderingComposer,
          $$CapsuleMediaTableAnnotationComposer,
          $$CapsuleMediaTableCreateCompanionBuilder,
          $$CapsuleMediaTableUpdateCompanionBuilder,
          (
            CapsuleMediaRow,
            BaseReferences<_$AppDatabase, $CapsuleMediaTable, CapsuleMediaRow>,
          ),
          CapsuleMediaRow,
          PrefetchHooks Function()
        > {
  $$CapsuleMediaTableTableManager(_$AppDatabase db, $CapsuleMediaTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CapsuleMediaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CapsuleMediaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CapsuleMediaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> capsuleId = const Value.absent(),
                Value<String> slot = const Value.absent(),
                Value<String?> file = const Value.absent(),
                Value<String?> path = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<DateTime?> nextAttemptAt = const Value.absent(),
                Value<bool> failed = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CapsuleMediaCompanion(
                capsuleId: capsuleId,
                slot: slot,
                file: file,
                path: path,
                attempts: attempts,
                nextAttemptAt: nextAttemptAt,
                failed: failed,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String capsuleId,
                required String slot,
                Value<String?> file = const Value.absent(),
                Value<String?> path = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<DateTime?> nextAttemptAt = const Value.absent(),
                Value<bool> failed = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CapsuleMediaCompanion.insert(
                capsuleId: capsuleId,
                slot: slot,
                file: file,
                path: path,
                attempts: attempts,
                nextAttemptAt: nextAttemptAt,
                failed: failed,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CapsuleMediaTable, CapsuleMediaRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $CapsuleMediaTable,
                    CapsuleMediaRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CapsuleMediaTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CapsuleMediaTable,
      CapsuleMediaRow,
      $$CapsuleMediaTableFilterComposer,
      $$CapsuleMediaTableOrderingComposer,
      $$CapsuleMediaTableAnnotationComposer,
      $$CapsuleMediaTableCreateCompanionBuilder,
      $$CapsuleMediaTableUpdateCompanionBuilder,
      (
        CapsuleMediaRow,
        BaseReferences<_$AppDatabase, $CapsuleMediaTable, CapsuleMediaRow>,
      ),
      CapsuleMediaRow,
      PrefetchHooks Function()
    >;
typedef $$LoomConstellationsTableCreateCompanionBuilder =
    LoomConstellationsCompanion Function({
      required String id,
      Value<String?> stars,
      Value<String?> links,
      Value<String?> meaning,
      required String localDay,
      required DateTime deviceTs,
      Value<String?> tz,
      Value<DateTime?> deletedAt,
      Value<bool> synced,
      Value<int> rowid,
    });
typedef $$LoomConstellationsTableUpdateCompanionBuilder =
    LoomConstellationsCompanion Function({
      Value<String> id,
      Value<String?> stars,
      Value<String?> links,
      Value<String?> meaning,
      Value<String> localDay,
      Value<DateTime> deviceTs,
      Value<String?> tz,
      Value<DateTime?> deletedAt,
      Value<bool> synced,
      Value<int> rowid,
    });

class $$LoomConstellationsTableFilterComposer
    extends Composer<_$AppDatabase, $LoomConstellationsTable> {
  $$LoomConstellationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stars => $composableBuilder(
    column: $table.stars,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get links => $composableBuilder(
    column: $table.links,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get meaning => $composableBuilder(
    column: $table.meaning,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localDay => $composableBuilder(
    column: $table.localDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deviceTs => $composableBuilder(
    column: $table.deviceTs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tz => $composableBuilder(
    column: $table.tz,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LoomConstellationsTableOrderingComposer
    extends Composer<_$AppDatabase, $LoomConstellationsTable> {
  $$LoomConstellationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stars => $composableBuilder(
    column: $table.stars,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get links => $composableBuilder(
    column: $table.links,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get meaning => $composableBuilder(
    column: $table.meaning,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localDay => $composableBuilder(
    column: $table.localDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deviceTs => $composableBuilder(
    column: $table.deviceTs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tz => $composableBuilder(
    column: $table.tz,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LoomConstellationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LoomConstellationsTable> {
  $$LoomConstellationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get stars =>
      $composableBuilder(column: $table.stars, builder: (column) => column);

  GeneratedColumn<String> get links =>
      $composableBuilder(column: $table.links, builder: (column) => column);

  GeneratedColumn<String> get meaning =>
      $composableBuilder(column: $table.meaning, builder: (column) => column);

  GeneratedColumn<String> get localDay =>
      $composableBuilder(column: $table.localDay, builder: (column) => column);

  GeneratedColumn<DateTime> get deviceTs =>
      $composableBuilder(column: $table.deviceTs, builder: (column) => column);

  GeneratedColumn<String> get tz =>
      $composableBuilder(column: $table.tz, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<bool> get synced =>
      $composableBuilder(column: $table.synced, builder: (column) => column);
}

class $$LoomConstellationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LoomConstellationsTable,
          LoomConstellationRow,
          $$LoomConstellationsTableFilterComposer,
          $$LoomConstellationsTableOrderingComposer,
          $$LoomConstellationsTableAnnotationComposer,
          $$LoomConstellationsTableCreateCompanionBuilder,
          $$LoomConstellationsTableUpdateCompanionBuilder,
          (
            LoomConstellationRow,
            BaseReferences<
              _$AppDatabase,
              $LoomConstellationsTable,
              LoomConstellationRow
            >,
          ),
          LoomConstellationRow,
          PrefetchHooks Function()
        > {
  $$LoomConstellationsTableTableManager(
    _$AppDatabase db,
    $LoomConstellationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LoomConstellationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LoomConstellationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LoomConstellationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> stars = const Value.absent(),
                Value<String?> links = const Value.absent(),
                Value<String?> meaning = const Value.absent(),
                Value<String> localDay = const Value.absent(),
                Value<DateTime> deviceTs = const Value.absent(),
                Value<String?> tz = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<bool> synced = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LoomConstellationsCompanion(
                id: id,
                stars: stars,
                links: links,
                meaning: meaning,
                localDay: localDay,
                deviceTs: deviceTs,
                tz: tz,
                deletedAt: deletedAt,
                synced: synced,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> stars = const Value.absent(),
                Value<String?> links = const Value.absent(),
                Value<String?> meaning = const Value.absent(),
                required String localDay,
                required DateTime deviceTs,
                Value<String?> tz = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<bool> synced = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LoomConstellationsCompanion.insert(
                id: id,
                stars: stars,
                links: links,
                meaning: meaning,
                localDay: localDay,
                deviceTs: deviceTs,
                tz: tz,
                deletedAt: deletedAt,
                synced: synced,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LoomConstellationsTable, LoomConstellationRow>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $LoomConstellationsTable,
                    LoomConstellationRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LoomConstellationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LoomConstellationsTable,
      LoomConstellationRow,
      $$LoomConstellationsTableFilterComposer,
      $$LoomConstellationsTableOrderingComposer,
      $$LoomConstellationsTableAnnotationComposer,
      $$LoomConstellationsTableCreateCompanionBuilder,
      $$LoomConstellationsTableUpdateCompanionBuilder,
      (
        LoomConstellationRow,
        BaseReferences<
          _$AppDatabase,
          $LoomConstellationsTable,
          LoomConstellationRow
        >,
      ),
      LoomConstellationRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CheckInsTableTableManager get checkIns =>
      $$CheckInsTableTableManager(_db, _db.checkIns);
  $$HabitsTableTableManager get habits =>
      $$HabitsTableTableManager(_db, _db.habits);
  $$HabitLogsTableTableManager get habitLogs =>
      $$HabitLogsTableTableManager(_db, _db.habitLogs);
  $$OutboxTableTableManager get outbox =>
      $$OutboxTableTableManager(_db, _db.outbox);
  $$DeadLettersTableTableManager get deadLetters =>
      $$DeadLettersTableTableManager(_db, _db.deadLetters);
  $$KeyValuesTableTableManager get keyValues =>
      $$KeyValuesTableTableManager(_db, _db.keyValues);
  $$CapsulesTableTableManager get capsules =>
      $$CapsulesTableTableManager(_db, _db.capsules);
  $$CapsuleMediaTableTableManager get capsuleMedia =>
      $$CapsuleMediaTableTableManager(_db, _db.capsuleMedia);
  $$LoomConstellationsTableTableManager get loomConstellations =>
      $$LoomConstellationsTableTableManager(_db, _db.loomConstellations);
}
