import 'dart:io';

/// A PostgreSQL of its own for the backend's tests: a cluster made in a
/// temporary directory, reachable only through a socket there, with the
/// Supabase stand-in (`supabase_stub.sql`) and the migration applied to a
/// template database every test copies.
///
/// It needs PostgreSQL's own programs. Where they are not installed it is
/// not started, and the tests say why they were skipped rather than
/// passing.
class LocalPostgres {
  final String bin;
  final Directory dir;
  final bool asPostgresUser;
  static const port = 54331;
  static const template = 'proframe_template';
  int _databases = 0;

  LocalPostgres._(this.bin, this.dir, this.asPostgresUser);

  /// Why it cannot be started here, or null.
  static String? unavailable;

  static String? _findBin() {
    final given = Platform.environment['PROFRAME_PG_BIN'];
    if (given != null && File('$given/initdb').existsSync()) return given;
    final root = Directory('/usr/lib/postgresql');
    if (root.existsSync()) {
      final versions =
          root
              .listSync()
              .whereType<Directory>()
              .map((d) => d.path)
              .where((p) => File('$p/bin/initdb').existsSync())
              .toList()
            ..sort();
      if (versions.isNotEmpty) return '${versions.last}/bin';
    }
    for (final p in (Platform.environment['PATH'] ?? '').split(':')) {
      if (File('$p/initdb').existsSync()) return p;
    }
    return null;
  }

  static Future<LocalPostgres?> start() async {
    if (!Platform.isLinux && !Platform.isMacOS) {
      unavailable = 'PostgreSQL tests run on Linux and macOS only';
      return null;
    }
    final bin = _findBin();
    if (bin == null) {
      unavailable =
          'PostgreSQL is not installed (no initdb found; set PROFRAME_PG_BIN)';
      return null;
    }
    final root = (await Process.run('id', ['-u'])).stdout.toString().trim();
    final asPostgres = root == '0';
    if (asPostgres && (await Process.run('id', ['postgres'])).exitCode != 0) {
      unavailable = 'running as root with no postgres user to run as';
      return null;
    }
    final dir = await Directory('/tmp').createTemp('proframe-pg.');
    if (asPostgres) {
      await Process.run('chmod', ['755', dir.path]);
      await Process.run('chown', ['postgres', dir.path]);
    }
    final pg = LocalPostgres._(bin, dir, asPostgres);
    final init = await pg._run('$bin/initdb', [
      '-D',
      '${dir.path}/data',
      '-A',
      'trust',
      '-U',
      'postgres',
      '--no-sync',
    ]);
    if (init.exitCode != 0) {
      unavailable = 'initdb failed: ${init.stderr}';
      return null;
    }
    final started = await pg._run('$bin/pg_ctl', [
      '-D',
      '${dir.path}/data',
      '-o',
      "-k ${dir.path} -c listen_addresses='' -p $port -c fsync=off "
          '-c max_connections=60',
      '-l',
      '${dir.path}/log',
      '-w',
      'start',
    ]);
    if (started.exitCode != 0) {
      unavailable = 'PostgreSQL did not start: ${started.stderr}';
      return null;
    }
    await pg.sql('postgres', 'create database $template');
    await pg.file(template, 'test/backend/supabase_stub.sql');
    for (final migration in _migrations()) {
      await pg.file(template, migration);
    }
    return pg;
  }

  static List<String> _migrations() =>
      (Directory('supabase/migrations')
          .listSync()
          .whereType<File>()
          .map((f) => f.path)
          .where((p) => p.endsWith('.sql'))
          .toList()
        ..sort());

  Future<ProcessResult> _run(String program, List<String> args) =>
      asPostgresUser
      ? Process.run('runuser', ['-u', 'postgres', '--', program, ...args])
      : Process.run(program, args);

  List<String> _psql(String db) => [
    '-X',
    '-q',
    '-At',
    '-F',
    '|',
    '-v',
    'ON_ERROR_STOP=1',
    '-h',
    dir.path,
    '-p',
    '$port',
    '-U',
    'postgres',
    '-d',
    db,
  ];

  /// A fresh database with the migration applied.
  Future<String> database() async {
    final name = 'test_${++_databases}';
    await sql('postgres', 'create database $name template $template');
    return name;
  }

  Future<void> file(String db, String path) async {
    final r = await Process.run('$bin/psql', [..._psql(db), '-f', path]);
    if (r.exitCode != 0) throw PgError(r.stderr.toString());
  }

  /// What [script] prints, run in [db] — as the signed-in user [as], as
  /// `anon` where [as] is `'anon'`, or as the database's superuser (the
  /// Auth service, an administrator) where it is null.
  Future<String> sql(String db, String script, {String? as}) async {
    final process = await Process.start('$bin/psql', _psql(db));
    process.stdin.write(_prefix(as));
    process.stdin.write(script);
    process.stdin.write(';\n');
    await process.stdin.close();
    final out = await process.stdout
        .transform(const SystemEncoding().decoder)
        .join();
    final err = await process.stderr
        .transform(const SystemEncoding().decoder)
        .join();
    if (await process.exitCode != 0) throw PgError(err);
    return out.trim();
  }

  static String _prefix(String? as) => switch (as) {
    null => '',
    'anon' => 'set role anon;\n',
    _ =>
      'set role authenticated;\nset request.jwt.claims to '
          "'{\"sub\":\"$as\",\"role\":\"authenticated\"}';\n",
  };

  Future<void> stop() async {
    await _run('$bin/pg_ctl', [
      '-D',
      '${dir.path}/data',
      '-m',
      'immediate',
      'stop',
    ]);
    await dir.delete(recursive: true);
  }
}

/// What PostgreSQL refused, with its message.
class PgError implements Exception {
  final String output;
  PgError(this.output);

  /// The error's own message: `PF:worker_limit`, `permission denied for
  /// table designs`.
  String get message {
    final line = output
        .split('\n')
        .firstWhere((l) => l.contains('ERROR:'), orElse: () => output);
    return line.substring(line.indexOf('ERROR:') + 6).trim();
  }

  @override
  String toString() => 'PgError($message)';
}
