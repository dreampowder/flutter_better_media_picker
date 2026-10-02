/// Overrides for the picker's built-in English texts. `null` keeps the default.
class MediaPickerStrings {
  final String? ok;
  final String? cancel;

  /// "Add" button for multi-selection.
  final String? add;

  /// Album picker title.
  final String? albums;
  final String? alertTitleDownloading;

  /// Shown when the album list fails to load.
  final String? alertTitleError;
  final String? noPermissionTitle;
  final String? noPermissionDescription;
  final String? openSettings;

  const MediaPickerStrings({
    this.ok,
    this.cancel,
    this.add,
    this.albums,
    this.alertTitleDownloading,
    this.alertTitleError,
    this.noPermissionDescription,
    this.noPermissionTitle,
    this.openSettings,
  });
}
