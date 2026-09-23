/// Controls which fields are visible in the object editor.
enum ObjectFieldDisplayMode {
  /// All schema fields (present and absent) + all user data fields.
  all,

  /// Only fields present in user data (touched fields).
  userOnly,

  /// User data fields + required schema fields.
  userAndRequired,
}
