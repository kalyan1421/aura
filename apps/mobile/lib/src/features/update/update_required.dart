import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';
import '../../core/env/env.dart';
import '../../core/remote_config/app_version.dart';
import '../../core/remote_config/remote_config_providers.dart';
import '../../core/router/router.dart';
import '../../core/theme/aura_tokens.dart';
import '../../core/widgets/inline_notice.dart';
import '../onboarding/onboarding_frame.dart';
import '../support/support_sheet.dart';

/// Forced update (MASVS-CODE-2, docs/security/masvs-l1.md F-6).
///
/// When the server's `minAppVersion` for this platform (`GET /v1/config`,
/// contracts/api/v1.md "Remote config") is newer than this install, the app
/// shows [UpdateRequiredScreen] above everything: calm words, one button to
/// the store page, and "I need help now" in the top bar (help is never
/// locked). Nothing is deleted and nothing is signed out: the local database
/// and the sync outbox stay as they are and sync after the update (PRD 16).
/// If the server lowers the minimum again, the screen goes away by itself.

/// This install's version (null when the platform can't say: never gates).
final installedVersionReaderProvider = Provider<InstalledVersionReader>(
  (ref) => const ChannelInstalledVersionReader(),
);

final installedAppVersionProvider = FutureProvider<AppVersion?>(
  (ref) => ref.watch(installedVersionReaderProvider).read(),
);

/// The server's minimum per platform, as kept by the remote config
/// controller (offline too).
final minAppVersionProvider =
    NotifierProvider<MinAppVersionNotifier, MinAppVersions>(
      MinAppVersionNotifier.new,
    );

class MinAppVersionNotifier extends Notifier<MinAppVersions> {
  @override
  MinAppVersions build() {
    final value = ref.watch(remoteConfigControllerProvider).minAppVersion;
    void update() => state = value.value;
    value.addListener(update);
    ref.onDispose(() => value.removeListener(update));
    return value.value;
  }
}

/// The platform whose minimum applies (tests override it).
final updatePlatformProvider = Provider<TargetPlatform>(
  (ref) => defaultTargetPlatform,
);

/// True while this install is older than the server's minimum.
final updateRequiredProvider = Provider<bool>((ref) {
  final installed = ref.watch(installedAppVersionProvider).value;
  final minimum = ref
      .watch(minAppVersionProvider)
      .forPlatform(ref.watch(updatePlatformProvider));
  return isUpdateRequired(installed, minimum);
});

/// Puts [UpdateRequiredScreen] above everything and takes it away again
/// (tests replace it).
abstract interface class UpdateRequiredPresenter {
  void show();
  void hide();
}

class RouterUpdateRequiredPresenter implements UpdateRequiredPresenter {
  RouterUpdateRequiredPresenter(this._navigator);

  final NavigatorState? Function() _navigator;
  Route<void>? _route;
  bool _wanted = false;
  bool _scheduled = false;

  @override
  void show() {
    _wanted = true;
    _schedule();
  }

  @override
  void hide() {
    _wanted = false;
    // Nothing shown and nothing pending: no frame needed.
    if (_route == null && !_scheduled) return;
    _schedule();
  }

  /// Navigator changes wait for the end of the frame (the listener may fire
  /// while the app is building), and retry until the router's navigator is
  /// there (a kept config can say "update" before the first frame).
  void _schedule() {
    if (_scheduled) return;
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      _apply();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void _apply() {
    final route = _route;
    if (!_wanted) {
      if (route != null && route.isActive) {
        route.navigator?.removeRoute(route);
      }
      _route = null;
      return;
    }
    if (route?.isActive ?? false) return;
    final nav = _navigator();
    if (nav == null) {
      _schedule();
      return;
    }
    final next = UpdateRequiredScreen.route();
    _route = next;
    unawaited(nav.push(next));
  }
}

final updateRequiredPresenterProvider = Provider<UpdateRequiredPresenter>(
  (ref) => RouterUpdateRequiredPresenter(
    () => ref.read(routerProvider).routerDelegate.navigatorKey.currentState,
  ),
);

/// Keeps the screen in step with [updateRequiredProvider] for the whole
/// session (AuraApp watches it).
final updateGateProvider = Provider<void>((ref) {
  ref.listen<bool>(updateRequiredProvider, (_, required) {
    final presenter = ref.read(updateRequiredPresenterProvider);
    if (required) {
      presenter.show();
    } else {
      presenter.hide();
    }
  }, fireImmediately: true);
});

/// "Please update Aura." One way on: the store page. "I need help now"
/// stays in the top bar. Back does nothing.
class UpdateRequiredScreen extends StatefulWidget {
  const UpdateRequiredScreen({super.key, this.platform, this.opener});

  /// Overrides [defaultTargetPlatform] (tests).
  final TargetPlatform? platform;

  /// Opens the store page (tests); `launchUrl` otherwise.
  final Future<bool> Function(Uri uri)? opener;

  static Route<void> route() => MaterialPageRoute<void>(
    settings: const RouteSettings(name: 'update-required'),
    builder: (_) => const UpdateRequiredScreen(),
  );

  /// The store page for [platform], or null when this build doesn't know it.
  static Uri? storeUri(TargetPlatform platform) {
    final url = switch (platform) {
      TargetPlatform.iOS => Env.appStoreUrl,
      TargetPlatform.android => Env.playStoreUrl,
      _ => '',
    };
    return url.isEmpty ? null : Uri.parse(url);
  }

  @override
  State<UpdateRequiredScreen> createState() => _UpdateRequiredScreenState();
}

class _UpdateRequiredScreenState extends State<UpdateRequiredScreen> {
  bool _storeFailed = false;

  TargetPlatform get _platform => widget.platform ?? defaultTargetPlatform;

  Future<void> _openStore() async {
    final uri = UpdateRequiredScreen.storeUri(_platform);
    var opened = false;
    if (uri != null) {
      try {
        opened =
            await (widget.opener ??
                (u) => launchUrl(u, mode: LaunchMode.externalApplication))(uri);
      } on Object {
        opened = false;
      }
    }
    if (mounted) setState(() => _storeFailed = !opened);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return PopScope(
      canPop: false,
      child: OnboardingFrame(
        trailing: const HelpNowButton(compact: true),
        primary: FilledButton(
          key: const ValueKey('update-open-store'),
          onPressed: _openStore,
          child: Text(
            _platform == TargetPlatform.iOS
                ? l.update_openAppStore
                : l.update_openPlayStore,
          ),
        ),
        children: [
          const SizedBox(height: AuraSpace.xl),
          const ExcludeSemantics(
            child: Icon(
              Icons.system_update_rounded,
              size: 56,
              color: AuraColors.starlight,
            ),
          ),
          const SizedBox(height: AuraSpace.xl),
          Semantics(
            header: true,
            child: Text(
              l.update_title,
              key: const ValueKey('update-title'),
              style: t.headlineMedium,
            ),
          ),
          const SizedBox(height: AuraSpace.m),
          Text(
            l.update_body,
            style: t.bodyLarge?.copyWith(color: AuraColors.textSoft),
          ),
          const SizedBox(height: AuraSpace.l),
          Text(
            l.update_safe,
            key: const ValueKey('update-safe'),
            style: t.bodyMedium?.copyWith(color: AuraColors.textSoft),
          ),
          if (_storeFailed) ...[
            const SizedBox(height: AuraSpace.l),
            InlineNotice(
              l.update_storeFailed,
              key: const ValueKey('update-store-failed'),
            ),
          ],
        ],
      ),
    );
  }
}
