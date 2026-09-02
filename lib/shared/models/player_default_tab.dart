enum PlayerDefaultTab {
  artwork,

  embeddedLyrics,

  fullScreenLyrics;

  static PlayerDefaultTab fromName(String? name) => values.firstWhere(
    (tab) => tab.name == name,
    orElse: () => PlayerDefaultTab.artwork,
  );
}
