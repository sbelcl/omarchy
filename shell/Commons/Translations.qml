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

  // t("Battery")                        a plain string
  // t("Start weeks on %1", day)         a string with a value in it
  //
  // Placeholders rather than concatenation at the call site: a translation
  // has to be able to put the value where its own grammar wants it.
  function t(source, args) {
    var translated = Catalogs.translate(root.catalog, source)
    return args === undefined ? translated : Catalogs.format(translated, args)
  }

  // plural(n, "%1 device", "%1 devices")
  //
  // Both English forms stay at the call site, so an untranslated shell counts
  // correctly in English. A catalog translates the singular to an object of
  // CLDR categories, which is the only way to say this in a language with
  // more forms than English has -- Slovenian has four, and a dual among them:
  //
  //   "%1 device": { "one": "%1 naprava", "two": "%1 napravi",
  //                  "few": "%1 naprave", "other": "%1 naprav" }
  function plural(count, singular, other) {
    return Catalogs.translatePlural(root.catalog, count, singular, other, root.locale)
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
