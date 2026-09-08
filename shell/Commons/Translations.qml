pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import "Translations.js" as Catalogs

// The shell's translation table.
//
// Every user-visible string in the shell is written in English at its use
// site and passed through `T.t(...)`, which swaps it for the system
// language's wording when there is one and hands the English back when there
// is not. English is therefore always the source of truth and always the
// fallback: nothing has to be translated for the shell to read correctly, and
// a catalog that falls behind degrades one string at a time.
//
// Catalogs are JSON objects of English -> translation:
//
//   $OMARCHY_PATH/default/locales/<lang>.json   shipped with Omarchy
//   ~/.config/omarchy/locales/<lang>.json       the user's own, survives updates
//
// Both are read for the bare language and for the regional variant, layered
// shipped < shipped-region < user < user-region, so a user can correct a
// single string without copying a catalog. All four are watched, so an edit
// shows up in the running shell.
//
// Language comes from LANG, which is what the rest of the desktop follows.
// OMARCHY_LANGUAGE overrides it, for translating without changing the
// session's locale.
QtObject {
  id: root

  readonly property string locale: Quickshell.env("OMARCHY_LANGUAGE") || Quickshell.env("LANG") || ""
  readonly property bool active: Catalogs.isTranslatable(locale)
  readonly property string language: active ? Catalogs.baseLanguage(locale) : ""
  readonly property string region: active ? Catalogs.regionLanguage(locale) : ""

  readonly property string shippedDir: Quickshell.env("OMARCHY_PATH") + "/default/locales/"
  readonly property string userDir: Quickshell.env("HOME") + "/.config/omarchy/locales/"

  // Reading `catalog` inside t() is what makes every call site a binding on
  // it: when a file lands or changes, the strings re-resolve on their own.
  readonly property var catalog: Catalogs.mergeCatalogs([
    shippedLanguage.entries, shippedRegion.entries,
    userLanguage.entries, userRegion.entries
  ])

  function t(source) {
    return Catalogs.translate(root.catalog, source)
  }

  component Catalog: FileView {
    property var entries: ({})
    // A catalog that does not exist is the normal case, not an error: most
    // languages have no file, and neither does any user who has not written
    // one.
    property string language: ""
    property string directory: ""
    path: language === "" ? "" : directory + language + ".json"
    watchChanges: true
    printErrors: false
    onLoaded: entries = Catalogs.parseCatalog(text())
    onLoadFailed: entries = ({})
    onFileChanged: reload()
  }

  readonly property Catalog shippedLanguage: Catalog { directory: root.shippedDir; language: root.language }
  readonly property Catalog shippedRegion: Catalog { directory: root.shippedDir; language: root.region }
  readonly property Catalog userLanguage: Catalog { directory: root.userDir; language: root.language }
  readonly property Catalog userRegion: Catalog { directory: root.userDir; language: root.region }
}
