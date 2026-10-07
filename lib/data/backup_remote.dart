import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

/// Remote backup targets: where an automatic backup travels besides the phone.
///
/// Two shapes cover the self hosted setups this app is aimed at: WebDAV, which
/// every NAS and Nextcloud exposes, and S3, which MinIO and cloud object stores
/// speak. Both are built only on `package:http` and `package:crypto`, so neither
/// drags in a vendor SDK whose lifecycle the app would then have to follow.
///
/// This layer is deliberately ignorant of what a backup *is*: it moves opaque
/// bytes under a name and lists names, nothing more. Keeping the archive format
/// out of the transport means `backup.dart` can change shape without touching a
/// single line here, and a new transport only has to answer four questions.

/// Which protocol a [RemoteConfig] describes.
enum RemoteKind { webdav, s3 }

/// The outcome of a connectivity check. The message is written to be shown to a
/// user as-is, because the only reason to run a test is to explain a failure.
class RemoteResult {
  const RemoteResult(this.ok, this.message);

  final bool ok;
  final String message;
}

/// One object found on a remote. [name] is what the caller feeds back into
/// `download`, so it is a name relative to the target's root (no bucket, no
/// leading path), which lets a download rebuild the full key on its own.
class RemoteEntry {
  const RemoteEntry({required this.name, required this.size, this.modified});

  final String name;
  final int size;
  final DateTime? modified;
}

/// A place a backup can be pushed to. Deliberately small: a target that needs
/// more than these four verbs to be useful is not a backup target.
abstract class RemoteBackup {
  /// Shown in settings next to the target, so it names the endpoint rather than
  /// just the protocol.
  String get label;

  /// Verifies credentials and reachability without side effects a user would
  /// have to clean up.
  Future<RemoteResult> test();

  Future<void> upload(Uint8List data, String name);

  Future<List<RemoteEntry>> list();

  Future<Uint8List> download(String name);
}

/// Every network call is bounded: an automatic backup that hangs on a dead
/// server must fail the tick, not wedge the timer for the rest of the session.
const _timeout = Duration(seconds: 30);

// ---------------------------------------------------------------- WebDAV

/// WebDAV target: PUT to write, GET to read, a `Depth: 1` PROPFIND to list.
///
/// PROPFIND rather than a filesystem listing because the server may be a
/// Nextcloud or a folder on a NAS, and the multistatus body is the one listing
/// every WebDAV server agrees on.
class WebDavBackup implements RemoteBackup {
  WebDavBackup({required String baseUrl, String user = '', String pass = ''})
      : _base = baseUrl.trim().replaceAll(RegExp(r'/+$'), ''),
        _user = user,
        _pass = pass;

  /// Stored without a trailing slash so appending a name is unambiguous; a
  /// doubled slash is rejected by some servers, and tolerated-but-ugly by the
  /// rest.
  final String _base;
  final String _user;
  final String _pass;

  @override
  String get label {
    final host = Uri.tryParse(_base)?.host ?? '';
    return host.isEmpty ? 'WebDAV' : 'WebDAV ($host)';
  }

  /// Basic only when a user was given: an anonymous public share answers the
  /// same requests, and a bare `Basic Og==` is a confusing 401 rather than none.
  Map<String, String> get _auth {
    if (_user.isEmpty) return const <String, String>{};
    final token = base64.encode(utf8.encode('$_user:$_pass'));
    return {'Authorization': 'Basic $token'};
  }

  /// Builds the URL for an object. The name is split into segments and handed to
  /// [Uri] rather than concatenated, because a name is a file name and a `/` in
  /// it must stay a path separator while every other reserved character has to
  /// be percent-encoded once, not twice.
  Uri _uriFor(String name) {
    final base = Uri.parse(_base);
    final segments = <String>[
      ...base.pathSegments.where((s) => s.isNotEmpty),
      ...name.split('/').where((s) => s.isNotEmpty),
    ];
    return base.replace(pathSegments: segments);
  }

  @override
  Future<RemoteResult> test() async {
    final probe = _uriFor('.paradise_probe');
    try {
      final res = await http
          .put(probe, headers: _auth, body: utf8.encode('ok'))
          .timeout(_timeout);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return RemoteResult(false, 'The server answered ${res.statusCode}.');
      }
      // Best effort, never awaited and never fatal: a probe that stays behind
      // would show up in the user's own folder, but a cleanup failure must not
      // turn a working target into a "broken" one.
      unawaited(_deleteProbe(probe));
      return const RemoteResult(true, 'Writable.');
    } catch (e) {
      return RemoteResult(false, '$e');
    }
  }

  Future<void> _deleteProbe(Uri probe) async {
    try {
      await http.delete(probe, headers: _auth).timeout(_timeout);
    } catch (_) {
      // ignored on purpose, see test()
    }
  }

  @override
  Future<void> upload(Uint8List data, String name) async {
    final res =
        await http.put(_uriFor(name), headers: _auth, body: data).timeout(_timeout);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError('WebDAV upload failed (${res.statusCode}) for "$name".');
    }
  }

  @override
  Future<Uint8List> download(String name) async {
    final res = await http.get(_uriFor(name), headers: _auth).timeout(_timeout);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError('WebDAV download failed (${res.statusCode}) for "$name".');
    }
    return res.bodyBytes;
  }

  @override
  Future<List<RemoteEntry>> list() async {
    final req = http.Request('PROPFIND', Uri.parse(_base))
      ..headers.addAll(_auth)
      ..headers['Depth'] = '1';
    final streamed = await req.send().timeout(_timeout);
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError('WebDAV listing failed (${res.statusCode}).');
    }
    return _parsePropfind(utf8.decode(res.bodyBytes, allowMalformed: true));
  }

  /// A lighter parse than a real XML reader: the multistatus shape is fixed
  /// enough that one regex per element beats a dependency, and a listing that
  /// fails to parse degrades to fewer entries rather than an exception.
  List<RemoteEntry> _parsePropfind(String xml) {
    final entries = <RemoteEntry>[];
    final responses = RegExp(
      r'<(?:[\w.-]+:)?response\b[^>]*>(.*?)</(?:[\w.-]+:)?response>',
      dotAll: true,
    ).allMatches(xml);
    for (final r in responses) {
      final block = r.group(1)!;
      final href = _tag(block, 'href');
      if (href == null || href.isEmpty) continue;
      // A directory marks itself with a trailing slash; this target only holds
      // files, and a directory entry has no bytes to download.
      if (href.endsWith('/')) continue;
      var seg = href;
      final slash = seg.lastIndexOf('/');
      if (slash >= 0) seg = seg.substring(slash + 1);
      final cut = seg.indexOf(RegExp(r'[?#]'));
      if (cut >= 0) seg = seg.substring(0, cut);
      if (seg.isEmpty) continue;
      final sizeRaw = _tag(block, 'getcontentlength');
      final size = sizeRaw == null ? 0 : (int.tryParse(sizeRaw) ?? 0);
      final modRaw = _tag(block, 'getlastmodified');
      final modified = modRaw == null ? null : _parseHttpDate(modRaw);
      entries.add(RemoteEntry(
        name: Uri.decodeComponent(seg),
        size: size,
        modified: modified,
      ));
    }
    return entries;
  }
}

// ---------------------------------------------------------------- S3

/// S3 target, signed with AWS Signature Version 4.
///
/// Implemented by hand rather than with `aws_sigv4` or the AWS SDK: the request
/// surface here is three verbs, and the algorithm is small enough to own. It
/// also keeps the app's dependency list auditable, which matters for a client
/// that stores credentials.
///
/// Both addressing styles are supported because MinIO and a bucket without a
/// matching wildcard DNS record only answer path style, while a real S3 bucket
/// prefers virtual hosted style.
class S3Backup implements RemoteBackup {
  S3Backup({
    required String endpoint,
    required this.region,
    required this.bucket,
    required this.accessKey,
    required this.secretKey,
    String prefix = '',
    this.forcePathStyle = false,
  })  : prefix = _stripSlashes(prefix),
        _endpoint = _parseEndpoint(endpoint);

  final String region;
  final String bucket;
  final String accessKey;
  final String secretKey;

  /// Folder the backup lives under, normalised to have no leading or trailing
  /// slash so `prefix + '/' + name` is always a valid key.
  final String prefix;
  final bool forcePathStyle;

  /// Scheme, host and port only: a path on the endpoint would collide with the
  /// object path this class appends.
  final Uri _endpoint;

  /// sha256 of the empty payload. Every read request signs with this value, so
  /// folding it once avoids hashing an empty list on every call.
  static final String _emptyPayload = sha256.convert(const <int>[]).toString();

  @override
  String get label => 'S3 ($bucket)';

  // ---------------------------------------------------------- addressing

  /// The Host header (and, by extension, the authority of every request URL).
  /// Virtual hosted style lifts the bucket into the host name; path style keeps
  /// it in the path.
  String get _host {
    final authority = _endpoint.authority;
    return forcePathStyle ? authority : '$bucket.$authority';
  }

  /// The canonical URI, i.e. the percent-encoded path S3 will sign. Built once
  /// here so the URL that is sent and the string that is signed cannot drift.
  String _pathFor(String name) {
    final segments = <String>[
      if (forcePathStyle) bucket,
      if (prefix.isNotEmpty) ...prefix.split('/'),
      if (name.isNotEmpty) ...name.split('/'),
    ];
    return '/${segments.where((s) => s.isNotEmpty).map(_uriEncode).join('/')}';
  }

  Uri _uriFor(String path, Map<String, String> query) {
    final q = query.isEmpty ? '' : '?${_canonicalQuery(query)}';
    return Uri.parse('${_endpoint.scheme}://$_host$path$q');
  }

  // ---------------------------------------------------------- requests

  Future<http.Response> _listResponse({int? maxKeys}) async {
    // `list-type=2` is ListObjectsV2; `prefix` is only sent when set so a
    // pristine bucket listing stays cheap.
    final query = <String, String>{
      'list-type': '2',
      if (prefix.isNotEmpty) 'prefix': prefix,
      if (maxKeys != null) 'max-keys': '$maxKeys',
    };
    final path = _pathFor('');
    final headers = _signedHeaders(
      method: 'GET',
      path: path,
      query: query,
      payloadHash: _emptyPayload,
    );
    final res = await http.get(_uriFor(path, query), headers: headers).timeout(_timeout);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError('S3 listing failed (${res.statusCode}).');
    }
    return res;
  }

  @override
  Future<RemoteResult> test() async {
    try {
      // One key is enough to prove the bucket exists, the region is right and
      // the credential signs what the server expects.
      await _listResponse(maxKeys: 1);
      return const RemoteResult(true, 'Reachable.');
    } catch (e) {
      return RemoteResult(false, e is StateError ? e.message : '$e');
    }
  }

  @override
  Future<List<RemoteEntry>> list() async {
    final res = await _listResponse();
    return _parseListXml(utf8.decode(res.bodyBytes, allowMalformed: true));
  }

  @override
  Future<void> upload(Uint8List data, String name) async {
    final path = _pathFor(name);
    final headers = _signedHeaders(
      method: 'PUT',
      path: path,
      query: const {},
      payloadHash: sha256.convert(data).toString(),
    );
    final res =
        await http.put(_uriFor(path, const {}), headers: headers, body: data).timeout(_timeout);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError('S3 upload failed (${res.statusCode}) for "$name".');
    }
  }

  @override
  Future<Uint8List> download(String name) async {
    final path = _pathFor(name);
    final headers = _signedHeaders(
      method: 'GET',
      path: path,
      query: const {},
      payloadHash: _emptyPayload,
    );
    final res = await http.get(_uriFor(path, const {}), headers: headers).timeout(_timeout);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError('S3 download failed (${res.statusCode}) for "$name".');
    }
    return res.bodyBytes;
  }

  /// Turns the `ListObjectsV2` body into relative names. The prefix is stripped
  /// so the same string that [list] returns is accepted by [download], which
  /// puts the prefix back when it rebuilds the key.
  List<RemoteEntry> _parseListXml(String xml) {
    final entries = <RemoteEntry>[];
    final contents = RegExp(
      r'<(?:[\w.-]+:)?Contents\b[^>]*>(.*?)</(?:[\w.-]+:)?Contents>',
      dotAll: true,
    ).allMatches(xml);
    for (final c in contents) {
      final block = c.group(1)!;
      final key = _tag(block, 'Key');
      if (key == null || key.isEmpty) continue;
      var name = key;
      if (prefix.isNotEmpty && name.startsWith(prefix)) {
        name = name.substring(prefix.length);
      }
      if (name.startsWith('/')) name = name.substring(1);
      if (name.isEmpty) continue;
      final sizeRaw = _tag(block, 'Size');
      final lmRaw = _tag(block, 'LastModified');
      entries.add(RemoteEntry(
        name: name,
        size: sizeRaw == null ? 0 : (int.tryParse(sizeRaw) ?? 0),
        modified: lmRaw == null ? null : DateTime.tryParse(lmRaw),
      ));
    }
    return entries;
  }

  // ---------------------------------------------------------- signing

  /// Builds the four headers every signed request carries. The Host header is
  /// included because the client derives it from the request URL, which already
  /// carries the bucket in virtual hosted style, so signing it here keeps the
  /// signature and the wire in step.
  Map<String, String> _signedHeaders({
    required String method,
    required String path,
    required Map<String, String> query,
    required String payloadHash,
  }) {
    final now = DateTime.now().toUtc();
    final amzDate = _amzTimestamp(now);
    final dateStamp = amzDate.substring(0, 8);
    final scope = '$dateStamp/$region/s3/aws4_request';
    final canonicalQuery = _canonicalQuery(query);

    // Sorted by header name: the signer and the server must agree on the order,
    // and the alphabetical order is the one the spec pins.
    final canonicalHeaders = 'host:$_host\n'
        'x-amz-content-sha256:$payloadHash\n'
        'x-amz-date:$amzDate\n';
    const signedHeaders = 'host;x-amz-content-sha256;x-amz-date';

    final canonicalRequest =
        '$method\n$path\n$canonicalQuery\n$canonicalHeaders\n$signedHeaders\n$payloadHash';
    final stringToSign = 'AWS4-HMAC-SHA256\n$amzDate\n$scope\n'
        '${sha256.convert(utf8.encode(canonicalRequest))}';

    // Derive the signing key one step at a time; the chain, not the secret
    // alone, is what scopes the signature to this day, region and service.
    final kDate = Hmac(sha256, utf8.encode('AWS4$secretKey')).convert(utf8.encode(dateStamp)).bytes;
    final kRegion = Hmac(sha256, kDate).convert(utf8.encode(region)).bytes;
    final kService = Hmac(sha256, kRegion).convert(utf8.encode('s3')).bytes;
    final kSigning = Hmac(sha256, kService).convert(utf8.encode('aws4_request')).bytes;
    final signature = Hmac(sha256, kSigning).convert(utf8.encode(stringToSign)).toString();

    return {
      'Host': _host,
      'x-amz-date': amzDate,
      'x-amz-content-sha256': payloadHash,
      'Authorization': 'AWS4-HMAC-SHA256 '
          'Credential=$accessKey/$scope, '
          'SignedHeaders=$signedHeaders, '
          'Signature=$signature',
    };
  }

  /// `yyyyMMdd'T'HHmmss'Z'`, always UTC: the date is part of the signature and
  /// a local-time skew makes every request fail as if the key were wrong.
  static String _amzTimestamp(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year.toString().padLeft(4, '0')}${two(t.month)}${two(t.day)}T'
        '${two(t.hour)}${two(t.minute)}${two(t.second)}Z';
  }

  /// Canonical query string: parameters sorted by name, both halves encoded
  /// with the AWS rules, joined by `&`.
  static String _canonicalQuery(Map<String, String> params) {
    final keys = params.keys.toList()..sort();
    return keys.map((k) => '${_uriEncode(k)}=${_uriEncode(params[k]!)}').join('&');
  }

  /// AWS percent-encoding: unreserved characters stay literal, a slash survives
  /// only when the caller says so, everything else becomes an uppercase escape.
  /// A lowercase hex digit here is the classic reason a hand rolled signer gets
  /// a 403 with a "signature does not match" body and no other clue.
  static String _uriEncode(String input, {bool encodeSlash = true}) {
    final out = StringBuffer();
    for (final b in utf8.encode(input)) {
      final unreserved = (b >= 0x41 && b <= 0x5A) || // A-Z
          (b >= 0x61 && b <= 0x7A) || // a-z
          (b >= 0x30 && b <= 0x39) || // 0-9
          b == 0x2D || // -
          b == 0x2E || // .
          b == 0x5F || // _
          b == 0x7E; // ~
      if (unreserved) {
        out.writeCharCode(b);
      } else if (b == 0x2F && !encodeSlash) {
        out.write('/');
      } else {
        out.write('%${b.toRadixString(16).toUpperCase().padLeft(2, '0')}');
      }
    }
    return out.toString();
  }

  // ---------------------------------------------------------- parsing endpoint

  /// Accepts an endpoint with or without a scheme and keeps only the parts this
  /// class needs, so a trailing path a user copied from a console cannot leak
  /// into an object key.
  static Uri _parseEndpoint(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return Uri.parse('https://localhost');
    if (!s.contains('://')) s = 'https://$s';
    final u = Uri.parse(s);
    return Uri(
      scheme: u.scheme.isEmpty ? 'https' : u.scheme,
      host: u.host,
      port: u.hasPort ? u.port : null,
    );
  }

  /// Removes the slashes a user tends to include when naming a folder, so the
  /// prefix is always a bare path that can be joined with `/`.
  static String _stripSlashes(String p) {
    var s = p.trim();
    while (s.startsWith('/')) {
      s = s.substring(1);
    }
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }
}

// ---------------------------------------------------------------- config

/// The persistable half of a remote target, stored as one JSON blob in
/// SharedPreferences.
///
/// Kept as plain fields rather than the live [RemoteBackup] because the screen
/// edits it field by field and only builds a target to run a test. Nothing here
/// talks to the network, so the settings UI never needs a device.
class RemoteConfig {
  RemoteConfig({
    this.kind = RemoteKind.webdav,
    this.enabled = false,
    this.url = '',
    this.user = '',
    this.pass = '',
    this.endpoint = '',
    this.region = 'us-east-1',
    this.bucket = '',
    this.accessKey = '',
    this.secretKey = '',
    this.prefix = '',
    this.forcePathStyle = false,
  });

  RemoteKind kind;
  bool enabled;

  // WebDAV
  String url;
  String user;
  String pass;

  // S3
  String endpoint;
  String region;
  String bucket;
  String accessKey;
  String secretKey;
  String prefix;
  bool forcePathStyle;

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'enabled': enabled,
        'url': url,
        'user': user,
        'pass': pass,
        'endpoint': endpoint,
        'region': region,
        'bucket': bucket,
        'accessKey': accessKey,
        'secretKey': secretKey,
        'prefix': prefix,
        'forcePathStyle': forcePathStyle,
      };

  factory RemoteConfig.fromJson(Map<String, dynamic> j) => RemoteConfig(
        kind: j['kind'] == 's3' ? RemoteKind.s3 : RemoteKind.webdav,
        enabled: j['enabled'] as bool? ?? false,
        url: j['url'] as String? ?? '',
        user: j['user'] as String? ?? '',
        pass: j['pass'] as String? ?? '',
        endpoint: j['endpoint'] as String? ?? '',
        region: j['region'] as String? ?? 'us-east-1',
        bucket: j['bucket'] as String? ?? '',
        accessKey: j['accessKey'] as String? ?? '',
        secretKey: j['secretKey'] as String? ?? '',
        prefix: j['prefix'] as String? ?? '',
        forcePathStyle: j['forcePathStyle'] as bool? ?? false,
      );

  /// Builds the live target for the current [kind]. It returns an object even
  /// when fields are missing, so the UI can hold one and let [isConfigured]
  /// decide whether an upload is allowed, instead of juggling nulls.
  RemoteBackup build() => switch (kind) {
        RemoteKind.webdav =>
          WebDavBackup(baseUrl: url, user: user, pass: pass),
        RemoteKind.s3 => S3Backup(
            endpoint: endpoint,
            region: region,
            bucket: bucket,
            accessKey: accessKey,
            secretKey: secretKey,
            prefix: prefix,
            forcePathStyle: forcePathStyle,
          ),
      };

  /// Whether the fields a target cannot work without are present, which is what
  /// gates the "back up now" button rather than a full reachability test.
  bool get isConfigured => switch (kind) {
        RemoteKind.webdav => url.isNotEmpty,
        RemoteKind.s3 =>
          endpoint.isNotEmpty &&
              bucket.isNotEmpty &&
              accessKey.isNotEmpty &&
              secretKey.isNotEmpty,
      };
}

// ---------------------------------------------------------------- helpers

/// Pulls the text of the first `name` element, whatever namespace prefix the
/// server chose, and unescapes the handful of entities XML actually produces in
/// a listing. Returns null when the element is absent.
String? _tag(String xml, String name) {
  final m = RegExp(
    '<(?:[\\w.-]+:)?$name\\b[^>]*>(.*?)</(?:[\\w.-]+:)?$name>',
    dotAll: true,
  ).firstMatch(xml);
  if (m == null) return null;
  return _xmlUnescape(m.group(1)!.trim());
}

/// The inverse of the escaping an XML serialiser applies to text nodes. `&amp;`
/// is replaced last so an encoded `&amp;lt;` does not become `<`.
String _xmlUnescape(String s) => s
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'")
    .replaceAll('&amp;', '&');

/// Parses the RFC 1123 timestamp WebDAV uses for `getlastmodified`, e.g.
/// `Wed, 21 Oct 2015 07:28:00 GMT`. Returns null instead of throwing because a
/// missing modified time is not worth failing a listing over.
DateTime? _parseHttpDate(String raw) {
  final m = RegExp(
    r'(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})\s+(\d{1,2}):(\d{2}):(\d{2})',
  ).firstMatch(raw);
  if (m == null) return null;
  const months = {
    'Jan': 1,
    'Feb': 2,
    'Mar': 3,
    'Apr': 4,
    'May': 5,
    'Jun': 6,
    'Jul': 7,
    'Aug': 8,
    'Sep': 9,
    'Oct': 10,
    'Nov': 11,
    'Dec': 12,
  };
  final month = months[m.group(2)!];
  if (month == null) return null;
  try {
    return DateTime.utc(
      int.parse(m.group(3)!),
      month,
      int.parse(m.group(1)!),
      int.parse(m.group(4)!),
      int.parse(m.group(5)!),
      int.parse(m.group(6)!),
    );
  } catch (_) {
    return null;
  }
}
