/// Global, synchronously-readable app settings.
///
/// Kept deliberately tiny and free of any Flutter/web imports so it can be read
/// from pure serialization code (e.g. [ImageNode.toJson]) without a BuildContext.
/// The UI that mutates these values is responsible for mirroring them to
/// localStorage (see `storage.dart`).
class PackerSettings {
  /// When true, picked image bytes are base64-embedded in the saved graph so a
  /// reloaded config fully restores. Off by default: graphs stay small and fit
  /// comfortably in localStorage (which has a ~5 MB quota).
  static bool embedImages = false;
}
