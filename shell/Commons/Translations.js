// Catalog lookup for the shell's user-visible strings. Kept Qt-free so the
// resolution rules can be unit tested under node (test/shell.d/translations-test.sh).
//
// Keys are the English source strings, not symbolic ids. A missing catalog,
// a missing key, or a key whose value is empty all resolve to the English
// source, so an untranslated string is a readable string rather than a blank
// or a "power.profile.header" leaking into the UI.

// LANG carries more than the language: sl_SI.UTF-8 names a region and a
// codeset too. Catalogs are looked up under both the region name and the bare
// language, so pt_BR.UTF-8 can carry Brazilian wording over a shared pt file
// without either having to repeat the other.
function baseLanguage(locale) {
  var value = String(locale || "").trim()
  if (value === "") return ""
  var cut = value.search(/[_.@]/)
  if (cut !== -1) value = value.substring(0, cut)
  return value.toLowerCase()
}

function regionLanguage(locale) {
  var value = String(locale || "").trim()
  if (value === "") return ""
  var at = value.indexOf("@")
  if (at !== -1) value = value.substring(0, at)
  var dot = value.indexOf(".")
  if (dot !== -1) value = value.substring(0, dot)
  if (value.indexOf("_") === -1) return ""
  return value
}

// C and POSIX are the absence of a language rather than a language, and a
// catalog named for either would be a mistake to load.
function isTranslatable(locale) {
  var base = baseLanguage(locale)
  return base !== "" && base !== "c" && base !== "posix"
}

function parseCatalog(text) {
  var parsed
  try {
    parsed = JSON.parse(String(text || ""))
  } catch (e) {
    return {}
  }
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) return {}
  var out = {}
  for (var key in parsed) {
    if (typeof parsed[key] === "string" && parsed[key] !== "") out[key] = parsed[key]
  }
  return out
}

// Later catalogs win. Callers layer them shipped-then-user and bare-language
// -then-region, so a user's own file overrides what Omarchy ships and a
// regional wording overrides the shared one.
function mergeCatalogs(catalogs) {
  var out = {}
  for (var i = 0; i < (catalogs || []).length; i++) {
    var catalog = catalogs[i]
    if (!catalog) continue
    for (var key in catalog) out[key] = catalog[key]
  }
  return out
}

function translate(catalog, source) {
  var key = String(source === undefined || source === null ? "" : source)
  if (!catalog) return key
  var value = catalog[key]
  return typeof value === "string" && value !== "" ? value : key
}

// QML imports this file as a plain script; node needs the exports to test it.
// The guard is what keeps the same file usable from both.
if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    baseLanguage: baseLanguage,
    regionLanguage: regionLanguage,
    isTranslatable: isTranslatable,
    parseCatalog: parseCatalog,
    mergeCatalogs: mergeCatalogs,
    translate: translate
  }
}
