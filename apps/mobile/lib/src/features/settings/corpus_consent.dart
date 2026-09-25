import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/env/env.dart';
import '../../core/net/aura_api.dart' show ApiException;
import '../../core/providers.dart';
import '../../core/theme/aura_tokens.dart';

/// REQ-SAFE-16 opt-out (PRD 06c F9 "Training corpus … privacy-notice
/// disclosure plus Settings opt-out"; contracts/api/v1-reflections.md §7):
/// whether the person's reflections, and the decisions about them, may be
/// kept without any link to them to train Aura's own safety filters. On by
/// default per the privacy notice; the server decides (under-18 authors are
/// never kept, whatever this says).
abstract interface class CorpusConsentApi {
  Future<bool> get();
  Future<bool> set(bool enabled);
}

class HttpCorpusConsentApi implements CorpusConsentApi {
  HttpCorpusConsentApi({
    required String baseUrl,
    required this.accessToken,
    Dio? dio,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: baseUrl,
               connectTimeout: const Duration(seconds: 6),
               receiveTimeout: const Duration(seconds: 8),
               contentType: Headers.jsonContentType,
               responseType: ResponseType.json,
             ),
           );

  final Dio _dio;
  final Future<String?> Function() accessToken;

  static const String _path = '/v1/safety/corpus-consent';

  Future<bool> _call(Future<Response<dynamic>> Function(Options o) f) async {
    final token = await accessToken();
    if (token == null) {
      throw const ApiException(code: 'signed_out', status: 401);
    }
    try {
      final res = await f(Options(headers: {'Authorization': 'Bearer $token'}));
      final data = res.data;
      final enabled = data is Map ? data['enabled'] : null;
      if (enabled is! bool) {
        throw const ApiException(code: 'bad_response', status: 200);
      }
      return enabled;
    } on DioException catch (e) {
      final r = e.response;
      if (r == null) throw ApiException(code: e.type.name, isNetwork: true);
      final d = r.data;
      throw ApiException(
        code: d is Map && d['code'] is String
            ? d['code'] as String
            : 'http_${r.statusCode}',
        status: r.statusCode,
      );
    }
  }

  @override
  Future<bool> get() => _call((o) => _dio.get<dynamic>(_path, options: o));

  @override
  Future<bool> set(bool enabled) => _call(
    (o) => _dio.put<dynamic>(_path, data: {'enabled': enabled}, options: o),
  );
}

/// `null` without an API or a signed-in account.
final corpusConsentApiProvider = Provider<CorpusConsentApi?>((ref) {
  if (!Env.hasApi) return null;
  final auth = ref.watch(authRepositoryProvider);
  if (!auth.isAvailable) return null;
  return HttpCorpusConsentApi(
    baseUrl: Env.apiUrl,
    accessToken: auth.accessToken,
  );
});

/// The switch in Settings › Help & Safety. Shows the server's answer; while
/// it loads, or offline, the switch waits (never guesses a value).
class CorpusConsentTile extends ConsumerStatefulWidget {
  const CorpusConsentTile({super.key});

  @override
  ConsumerState<CorpusConsentTile> createState() => _CorpusConsentTileState();
}

class _CorpusConsentTileState extends ConsumerState<CorpusConsentTile> {
  bool? _enabled;
  bool _busy = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = ref.read(corpusConsentApiProvider);
    if (api == null) return;
    try {
      final v = await api.get();
      if (mounted) setState(() => _enabled = v);
    } on Object {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _set(bool v) async {
    final api = ref.read(corpusConsentApiProvider);
    if (api == null) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      final now = await api.set(v);
      if (mounted) setState(() => _enabled = now);
    } on Object {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(corpusConsentApiProvider) == null) {
      return const SizedBox.shrink();
    }
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final enabled = _enabled;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          key: const ValueKey('set-corpus'),
          contentPadding: EdgeInsets.zero,
          value: enabled ?? false,
          onChanged: enabled == null || _busy ? null : _set,
          title: Text(l.set_corpusTitle),
          subtitle: Text(l.set_corpusNote),
          isThreeLine: true,
        ),
        if (_failed)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: AuraSpace.s),
            child: Text(
              l.set_corpusOffline,
              key: const ValueKey('set-corpus-failed'),
              style: t.bodySmall?.copyWith(color: AuraColors.textSoft),
            ),
          ),
      ],
    );
  }
}
