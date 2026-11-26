import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:seek_player/core/analytics/analytics_events.dart';
import 'package:seek_player/core/analytics/analytics_reporter.dart';
import 'package:seek_player/features/output/widgets/output_collections_section.dart';
import 'package:seek_player/features/tools/models/tool_kind.dart';
import 'package:seek_player/l10n/app_localizations.dart';
import 'package:seek_player/shared/widgets/action_card.dart';
import 'package:seek_player/shared/widgets/action_card_grid.dart';
import 'package:seek_player/shared/widgets/app_logo_leading.dart';

/// 「工具」分頁:集中針對單首曲目加工的功能(製作歌詞、更改封面 …),
/// 不必先播放、進播放頁才找得到。點工具後進選曲頁。
/// 下方接「產出」區(任務、歌詞),見 [OutputCollectionsSection]。
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
          ActionCardGrid(
            children: [
              for (final tool in ToolKind.values)
                ActionCard(
                  icon: Icon(tool.icon),
                  label: tool.label(l10n),
                  // 卡片只放名稱,完整說明改由長按提示。
                  tooltip: tool.description(l10n),
                  onTap: () {
                    // 路由樣板 `/tools/:tool` 分不出工具種類,另記選了哪個工具。
                    logAnalyticsAction(ToolsAction.selectTool, option: tool);
                    context.push('/tools/${tool.name}');
                  },
                ),
            ],
          ),
          // 先用工具才會有產出,產出集合接在工具下方。
          const OutputCollectionsSection(),
        ],
      ),
    );
  }
}
