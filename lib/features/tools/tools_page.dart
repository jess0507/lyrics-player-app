import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:seek_player/features/tools/models/tool_kind.dart';
import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/shared/widgets/app_logo_leading.dart';

/// 「工具」分頁:集中針對單首曲目加工的功能(製作歌詞、更改封面 …),
/// 不必先播放、進播放頁才找得到。點工具後進選曲頁。
class ToolsPage extends StatelessWidget {
  const ToolsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        // 分頁根頁沒有返回鍵,左側改放 app 圖示。
        leading: const AppLogoLeading(),
        title: Text(l10n.tab_tools),
      ),
      body: ListView(
        children: [
          for (final tool in ToolKind.values)
            ListTile(
              leading: CircleAvatar(child: Icon(tool.icon)),
              title: Text(tool.label(l10n)),
              subtitle: Text(tool.description(l10n)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/tools/${tool.name}'),
            ),
        ],
      ),
    );
  }
}
