import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seek_player/l10n/app_localizations.dart';

class MusicListPage extends ConsumerStatefulWidget {
  const MusicListPage({super.key});

  @override
  ConsumerState<MusicListPage> createState() => _MusicListPageState();
}

class _MusicListPageState extends ConsumerState<MusicListPage> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tab_music_list)),
      body: SizedBox.shrink(),
    );
  }
}
