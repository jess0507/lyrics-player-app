import 'package:flutter_test/flutter_test.dart';
import 'package:seek_player/core/analytics/analytics_events.dart';
import 'package:seek_player/features/player/widgets/lyrics_menu_action.dart';

void main() {
  test('事件 / 參數 / 登入方式的 GA 名稱為 snake_case', () {
    expect(AnalyticsEvent.lyricsAction.gaName, 'lyrics_action');
    expect(AnalyticsParam.action.gaName, 'action');
    expect(AnalyticsSignInMethod.google.gaName, 'google');
  });

  test('toGaParameters:enum 值轉 snake_case,其他值原樣保留', () {
    expect(
      toGaParameters({AnalyticsParam.action: LyricsMenuAction.autoAlignAeneas}),
      {'action': 'auto_align_aeneas'},
    );
    expect(toGaParameters({AnalyticsParam.action: 3}), {'action': 3});
  });

  test('toGaParameters:bool 轉成字串(GA 不收 bool)', () {
    expect(toGaParameters({AnalyticsParam.option: true}), {'option': 'true'});
  });

  test('actionParameters:帶 action,null 的 source / option / result 不送', () {
    expect(actionParameters(PlayerAction.share), {'action': 'share'});
    expect(
      actionParameters(
        PlaylistAction.playTrack,
        source: AnalyticsSource.recentlyPlayed,
        option: 1.5,
        result: AnalyticsResult.success,
      ),
      {
        'action': 'play_track',
        'source': 'recently_played',
        'option': 1.5,
        'result': 'success',
      },
    );
  });

  test('各動作 enum 指向所屬功能事件', () {
    expect(LyricsMenuAction.paste.analyticsEvent, AnalyticsEvent.lyricsAction);
    expect(LyricsAction.cancelJob.analyticsEvent, AnalyticsEvent.lyricsAction);
    expect(
      MiniPlayerAction.openPlayer.analyticsEvent.gaName,
      'mini_player_action',
    );
  });

  test('所有 GA 名稱符合規則(字母開頭、英數底線、≤ 40 字)', () {
    final valid = RegExp(r'^[a-z][a-z0-9_]{0,39}$');
    for (final name in [
      ...AnalyticsEvent.values.map((e) => e.gaName),
      ...AnalyticsParam.values.map((e) => e.gaName),
      ...AnalyticsSignInMethod.values.map((e) => e.gaName),
      ...AnalyticsSource.values.map(
        (e) => toGaParameters({AnalyticsParam.source: e})['source']! as String,
      ),
    ]) {
      expect(valid.hasMatch(name), isTrue, reason: name);
    }
  });
}
