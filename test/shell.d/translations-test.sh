#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

run_node_test <<'JS'
const catalogs = requireFromRoot('shell/Commons/Translations.js')

// LANG carries a language, usually a region, and often a codeset. Catalogs are
// named for the first two, so both have to come back out of it cleanly.
assertEqual(catalogs.baseLanguage('sl_SI.UTF-8'), 'sl', 'the language is the part before the region')
assertEqual(catalogs.baseLanguage('sl'), 'sl', 'a bare language is already the answer')
assertEqual(catalogs.baseLanguage('be_BY.UTF-8@latin'), 'be', 'a modifier is not part of the language')
assertEqual(catalogs.baseLanguage('C.UTF-8'), 'c', 'C is read as any other name here')
assertEqual(catalogs.baseLanguage(''), '', 'an unset locale names no language')

assertEqual(catalogs.regionLanguage('sl_SI.UTF-8'), 'sl_SI', 'the regional name drops the codeset')
assertEqual(catalogs.regionLanguage('be_BY@latin'), 'be_BY', 'and the modifier')
assertEqual(catalogs.regionLanguage('sl'), '', 'a language without a region has no regional catalog')

// C and POSIX are the absence of a language rather than a language: loading a
// catalog for either would be loading one for "no translation at all".
assertEqual(catalogs.isTranslatable('sl_SI.UTF-8'), true, 'a real locale is translatable')
assertEqual(catalogs.isTranslatable('C.UTF-8'), false, 'C is not')
assertEqual(catalogs.isTranslatable('POSIX'), false, 'neither is POSIX')
assertEqual(catalogs.isTranslatable(''), false, 'nor an unset locale')

// A catalog is data off disk, so every shape it could arrive in has to resolve
// to something the lookup can read rather than throwing inside a binding.
assertEqual(JSON.stringify(catalogs.parseCatalog('{"Battery":"Baterija"}')), '{"Battery":"Baterija"}', 'a catalog parses')
assertEqual(JSON.stringify(catalogs.parseCatalog('not json')), '{}', 'a broken file is empty rather than fatal')
assertEqual(JSON.stringify(catalogs.parseCatalog('[1,2]')), '{}', 'so is an array')
assertEqual(JSON.stringify(catalogs.parseCatalog('')), '{}', 'and a missing file')
assertEqual(JSON.stringify(catalogs.parseCatalog('{"a":"","b":2,"c":"x"}')), '{"c":"x"}',
  'entries that are not a non-empty string are dropped, so they fall back to English')

// Layered shipped < shipped-region < user < user-region, which is what lets a
// user correct one string without copying a whole catalog.
const merged = catalogs.mergeCatalogs([
  { Battery: 'Baterija', Charging: 'Polnjenje' },
  { Charging: 'Polni se' },
  null,
  { Battery: 'Akumulator' },
])
assertEqual(merged.Battery, 'Akumulator', 'the last catalog to carry a key wins')
assertEqual(merged.Charging, 'Polni se', 'and a regional wording overrides the shared one')
assertEqual(JSON.stringify(catalogs.mergeCatalogs([])), '{}', 'no catalogs is not an error')
assertEqual(JSON.stringify(catalogs.mergeCatalogs(undefined)), '{}', 'nor is nothing at all')

// English is the source and the fallback: an untranslated string reads as
// English rather than as a blank or a key.
const catalog = { Battery: 'Baterija' }
assertEqual(catalogs.translate(catalog, 'Battery'), 'Baterija', 'a translated string is translated')
assertEqual(catalogs.translate(catalog, 'Charge cycles'), 'Charge cycles', 'an untranslated one stays English')
assertEqual(catalogs.translate({}, 'Battery'), 'Battery', 'so does one with no catalog behind it')
assertEqual(catalogs.translate(null, 'Battery'), 'Battery', 'and one with no catalog at all')
assertEqual(catalogs.translate(catalog, ''), '', 'an empty string translates to itself')
JS
