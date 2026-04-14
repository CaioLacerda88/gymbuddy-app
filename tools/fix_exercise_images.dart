// One-off Dart script: download source exercise images and upload to Supabase Storage.
//
// Background
// ----------
// The seed URLs in `supabase/migrations/00004_seed_exercise_images.sql` were
// name-guesses that never matched the folder names in `yuhonas/free-exercise-db`
// — so every URL has been returning a 404 since the migration shipped.
//
// This script:
//   1. Reads `tools/exercise_image_mapping.json` (the curated name -> folder map).
//   2. Downloads `{source_id}/0.jpg` and `{source_id}/1.jpg` from
//      `raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/...`
//      into `tools/.staging_images/` (gitignored).
//   3. Validates each file is a non-empty JPEG (magic bytes `FF D8 FF`).
//   4. Uploads each `0.jpg` as `{upload_slug}_start.jpg` and each `1.jpg` as
//      `{upload_slug}_end.jpg` into the public `exercise-media` bucket via the
//      Supabase Storage REST API.
//
// Idempotency
// -----------
// Before upload the script HEADs the target object. If it already exists and
// the content length matches the staged file, the upload is skipped. If the
// size differs, the existing object is overwritten (with a warning log).
//
// Required env vars
// -----------------
//   SUPABASE_URL               — e.g. `http://127.0.0.1:54321` (local)
//                                  or `https://dgcueqvqfyuedclkxixz.supabase.co` (hosted)
//   SUPABASE_SERVICE_ROLE_KEY  — service role (not anon) key.
//
// How to obtain the service role key
// ----------------------------------
//   Local : `npx supabase status` prints `service_role key` after `npx supabase start`.
//   Hosted: `npx supabase projects api-keys --project-ref dgcueqvqfyuedclkxixz`
//           (or grab it from Supabase Dashboard -> Settings -> API).
//   Never commit the service role key. It is a full-access secret.
//
// Usage
// -----
//   # Local Supabase:
//   export SUPABASE_URL=http://127.0.0.1:54321
//   export SUPABASE_SERVICE_ROLE_KEY=<paste-local-service-role-key>
//   dart run tools/fix_exercise_images.dart
//
//   # Hosted Supabase:
//   export SUPABASE_URL=https://dgcueqvqfyuedclkxixz.supabase.co
//   export SUPABASE_SERVICE_ROLE_KEY=<paste-hosted-service-role-key>
//   dart run tools/fix_exercise_images.dart
//
// Flags
// -----
//   --skip-download   Reuse files already in `tools/.staging_images/`.
//   --skip-upload     Download + validate only (useful for CI dry-run).

// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

const String _sourceBase =
    'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises';
const String _bucket = 'exercise-media';
const String _stagingDir = 'tools/.staging_images';
const String _mappingPath = 'tools/exercise_image_mapping.json';

Future<void> main(List<String> args) async {
  final skipDownload = args.contains('--skip-download');
  final skipUpload = args.contains('--skip-upload');

  final mapping = _readMapping();
  print('Loaded ${mapping.length} mappings from $_mappingPath');

  // Validate unique upload_slugs (defence-in-depth — mapping file should already be clean).
  _assertUniqueSlugs(mapping);

  Directory(_stagingDir).createSync(recursive: true);

  final client = HttpClient();
  try {
    if (!skipDownload) {
      await _downloadAll(client, mapping);
    } else {
      print('Skipping download (--skip-download).');
    }

    if (!skipUpload) {
      final supabaseUrl = _requireEnv('SUPABASE_URL');
      final serviceRoleKey = _requireEnv('SUPABASE_SERVICE_ROLE_KEY');
      await _uploadAll(client, mapping, supabaseUrl, serviceRoleKey);
    } else {
      print('Skipping upload (--skip-upload).');
    }
  } finally {
    client.close(force: true);
  }

  print('\nDone.');
}

// ---------------------------------------------------------------------------
// Mapping + validation
// ---------------------------------------------------------------------------

List<Map<String, dynamic>> _readMapping() {
  final raw = File(_mappingPath).readAsStringSync();
  final list = jsonDecode(raw) as List<dynamic>;
  return list.cast<Map<String, dynamic>>();
}

void _assertUniqueSlugs(List<Map<String, dynamic>> mapping) {
  final seen = <String>{};
  for (final m in mapping) {
    final slug = m['upload_slug'] as String;
    if (!seen.add(slug)) {
      throw StateError('Duplicate upload_slug in mapping: $slug');
    }
  }
}

String _requireEnv(String name) {
  final v = Platform.environment[name];
  if (v == null || v.isEmpty) {
    stderr.writeln('ERROR: $name env var is required.');
    exit(2);
  }
  return v;
}

// ---------------------------------------------------------------------------
// Download phase
// ---------------------------------------------------------------------------

Future<void> _downloadAll(
  HttpClient client,
  List<Map<String, dynamic>> mapping,
) async {
  var i = 0;
  for (final m in mapping) {
    i += 1;
    final dbName = m['db_name'] as String;
    final sourceId = m['source_id'] as String?;
    final slug = m['upload_slug'] as String;

    if (sourceId == null) {
      print('[$i/${mapping.length}] SKIP $dbName — no source_id mapped.');
      continue;
    }

    for (final suffix in const ['0', '1']) {
      final url = '$_sourceBase/$sourceId/$suffix.jpg';
      final outPath =
          '$_stagingDir/${slug}_${suffix == "0" ? "start" : "end"}.jpg';
      await _downloadOne(client, url, outPath);
    }
    print('[$i/${mapping.length}] OK  $dbName  <-  $sourceId');
  }
}

Future<void> _downloadOne(HttpClient client, String url, String outPath) async {
  final outFile = File(outPath);
  if (outFile.existsSync() && outFile.lengthSync() > 0) {
    // Already staged — skip re-download.
    return;
  }
  final req = await client.getUrl(Uri.parse(url));
  final res = await req.close();
  if (res.statusCode != 200) {
    throw StateError('Download failed ${res.statusCode} for $url');
  }
  final bytes = await _collectBytes(res);
  if (bytes.length < 3 ||
      bytes[0] != 0xFF ||
      bytes[1] != 0xD8 ||
      bytes[2] != 0xFF) {
    throw StateError(
      'Not a JPEG (bad magic bytes) for $url (got ${bytes.take(3).map((b) => b.toRadixString(16)).join(" ")})',
    );
  }
  await outFile.writeAsBytes(bytes, flush: true);
}

Future<List<int>> _collectBytes(Stream<List<int>> stream) async {
  final builder = BytesBuilder(copy: false);
  await for (final chunk in stream) {
    builder.add(chunk);
  }
  return builder.takeBytes();
}

// ---------------------------------------------------------------------------
// Upload phase (Supabase Storage REST API)
// ---------------------------------------------------------------------------

Future<void> _uploadAll(
  HttpClient client,
  List<Map<String, dynamic>> mapping,
  String supabaseUrl,
  String serviceRoleKey,
) async {
  print('\nUploading to $supabaseUrl bucket=$_bucket ...');
  var i = 0;
  var uploaded = 0;
  var skipped = 0;
  var overwritten = 0;

  for (final m in mapping) {
    i += 1;
    final sourceId = m['source_id'] as String?;
    final slug = m['upload_slug'] as String;
    final dbName = m['db_name'] as String;

    if (sourceId == null) {
      print('[$i/${mapping.length}] SKIP $dbName — no source_id mapped.');
      continue;
    }

    for (final suffix in const ['start', 'end']) {
      final localPath = '$_stagingDir/${slug}_$suffix.jpg';
      final objectName = '${slug}_$suffix.jpg';
      final file = File(localPath);
      if (!file.existsSync()) {
        throw StateError(
          'Missing staged file $localPath — run without --skip-download first.',
        );
      }
      final localBytes = await file.readAsBytes();

      // HEAD equivalent — list the object to see if it exists and check size.
      final existingSize = await _headObjectSize(
        client,
        supabaseUrl,
        serviceRoleKey,
        objectName,
      );

      if (existingSize != null) {
        if (existingSize == localBytes.length) {
          skipped += 1;
          continue;
        } else {
          stderr.writeln(
            '  WARN: size mismatch for $objectName (remote=$existingSize local=${localBytes.length}) — overwriting.',
          );
          await _putObject(
            client,
            supabaseUrl,
            serviceRoleKey,
            objectName,
            localBytes,
            overwrite: true,
          );
          overwritten += 1;
        }
      } else {
        await _putObject(
          client,
          supabaseUrl,
          serviceRoleKey,
          objectName,
          localBytes,
          overwrite: false,
        );
        uploaded += 1;
      }
    }
    print('[$i/${mapping.length}] UP  $dbName  ->  ${slug}_{start,end}.jpg');
  }

  print(
    '\nUpload summary: uploaded=$uploaded  skipped=$skipped  overwritten=$overwritten',
  );
}

/// Returns the size of the object if it exists, else null.
Future<int?> _headObjectSize(
  HttpClient client,
  String supabaseUrl,
  String serviceRoleKey,
  String objectName,
) async {
  // Supabase storage: use the signed URL endpoint to check existence cheaply,
  // or HEAD on the public endpoint. Public HEAD is simplest.
  final url = Uri.parse(
    '$supabaseUrl/storage/v1/object/public/$_bucket/$objectName',
  );
  final req = await client.openUrl('HEAD', url);
  final res = await req.close();
  // Drain body (HEAD should have none, but be safe).
  await res.drain<void>();
  if (res.statusCode == 200) {
    return res.contentLength >= 0 ? res.contentLength : null;
  }
  if (res.statusCode == 400 || res.statusCode == 404) {
    return null;
  }
  throw StateError('HEAD $objectName returned ${res.statusCode}');
}

Future<void> _putObject(
  HttpClient client,
  String supabaseUrl,
  String serviceRoleKey,
  String objectName,
  List<int> bytes, {
  required bool overwrite,
}) async {
  final url = Uri.parse('$supabaseUrl/storage/v1/object/$_bucket/$objectName');
  // POST creates, PUT overwrites. Supabase Storage docs.
  final method = overwrite ? 'PUT' : 'POST';
  final req = await client.openUrl(method, url);
  req.headers.set('Authorization', 'Bearer $serviceRoleKey');
  req.headers.set('Content-Type', 'image/jpeg');
  req.headers.set('x-upsert', overwrite ? 'true' : 'false');
  req.headers.contentLength = bytes.length;
  req.add(bytes);
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  if (res.statusCode != 200 && res.statusCode != 201) {
    throw StateError('$method $objectName failed ${res.statusCode}: $body');
  }
}
