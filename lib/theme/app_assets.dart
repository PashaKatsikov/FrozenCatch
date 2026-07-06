/// Centralized references to every bundled image asset so screens never
/// hardcode raw string paths.
class AppAssets {
  AppAssets._();

  static const String _gameplay = 'assets/Frozen_Catch_gameplay_assets';
  static const String _extra = 'assets/Frozen_Catch_additional_assets';

  // Branding
  static const String gameLogo = '$_extra/Game_Name.webp';
  static const String icon = '$_extra/Icon.png';

  // Loading / system screens
  static const String loadingVertical = '$_extra/Vertical_Loading_Screen.webp';
  static const String loadingHorizontal =
      '$_extra/Horizontal_Loading_Screen.webp';
  static const String nowifiVertical = '$_extra/Vertical_Nowifi_Screen.webp';
  static const String nowifiHorizontal =
      '$_extra/Horizontal_Nowifi_Screen.webp';
  static const String notificationsVertical =
      '$_extra/Vertical_Notifications_Screen.webp';
  static const String notificationsHorizontal =
      '$_extra/Horizontal_Notifications_Screen.webp';

  // Backgrounds / locations
  static const String bgAurora = '$_gameplay/bg1_asset.webp';
  static const String bgNorthernLights = '$_gameplay/bg2_asset.webp';
  static const String bgSnowValley = '$_gameplay/bg3_asset.webp';

  static const List<String> backgrounds = [bgAurora, bgNorthernLights, bgSnowValley];

  // Frozen lake platforms (decorative)
  static const String lakeSmall = '$_gameplay/small_frozen_lake_asset.webp';
  static const String lakeMedium = '$_gameplay/medium_frozen_lake_asset.webp';
  static const String lakeLarge = '$_gameplay/large_deep_lake_asset.webp';

  // Anglers - standing pose
  static const String fishermanStanding = '$_gameplay/fisherman_asset.webp';
  static const String fishermanAgedStanding =
      '$_gameplay/aged_northern_fisherman_asset.webp';
  static const String fisherFemaleStanding =
      '$_gameplay/female_fisher_asset.webp';

  // Anglers - seated pose (used in gameplay, near the ice hole)
  static const String fishermanSeated = '$_gameplay/fisherman2_asset.webp';
  static const String fishermanAgedSeated =
      '$_gameplay/aged_northern_fisherman2_asset.webp';
  static const String fisherFemaleSeated =
      '$_gameplay/female_fisher2_asset.webp';

  // Fish, ordered from smallest (index 0) to legendary (index 9)
  static const List<String> fish = [
    '$_gameplay/fish1_asset.webp',
    '$_gameplay/fish2_asset.webp',
    '$_gameplay/fish3_asset.webp',
    '$_gameplay/fish4_asset.webp',
    '$_gameplay/fish5_asset.webp',
    '$_gameplay/fish6_asset.webp',
    '$_gameplay/fish7_asset.webp',
    '$_gameplay/fish8_asset.webp',
    '$_gameplay/fish9_asset.webp',
    '$_gameplay/fish10_asset.webp',
  ];
}
