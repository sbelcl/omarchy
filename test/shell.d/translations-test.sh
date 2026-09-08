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

// Placeholders, so a translation can move the value to where its own grammar
// wants it rather than being stuck with the call site's word order.
assertEqual(catalogs.format('Start weeks on %1', 'torek'), 'Start weeks on torek', 'a placeholder is filled')
assertEqual(catalogs.format('%2 of %1', [3, 1]), '1 of 3', 'arguments can be reordered by the translation')
assertEqual(catalogs.format('%1 and %1', 'x'), 'x and x', 'a placeholder can be used twice')
assertEqual(catalogs.format('100% sure about %1', 'it'), '100% sure about it', 'a bare percent is not a placeholder')
assertEqual(catalogs.format('Nothing to fill'), 'Nothing to fill', 'no arguments is not an error')
assertEqual(catalogs.format('Missing %1'), 'Missing %1', 'an unfilled placeholder is left visible rather than blanked')

// CLDR plural categories. Slovenian is the reason this exists: it has four,
// and one of them is a dual that no English-shaped rule can produce.
const category = (n, lang) => catalogs.pluralCategory(n, lang)
assertEqual(category(1, 'sl_SI.UTF-8'), 'one', 'Slovenian 1 is singular')
assertEqual(category(2, 'sl_SI.UTF-8'), 'two', 'Slovenian 2 is dual')
assertEqual(category(3, 'sl_SI.UTF-8'), 'few', 'Slovenian 3 is few')
assertEqual(category(5, 'sl_SI.UTF-8'), 'other', 'Slovenian 5 is plural')
assertEqual(category(102, 'sl_SI.UTF-8'), 'two', 'and 102 is dual again')

assertEqual(category(1, 'ru'), 'one', 'Russian 1')
assertEqual(category(11, 'ru'), 'many', 'Russian 11 is not 1')
assertEqual(category(22, 'ru'), 'few', 'Russian 22')
assertEqual(category(5, 'pl'), 'many', 'Polish 5')
assertEqual(category(3, 'cs'), 'few', 'Czech 3')
assertEqual(category(0, 'ar'), 'zero', 'Arabic has a zero form')
assertEqual(category(2, 'ar'), 'two', 'and a dual')
assertEqual(category(1, 'ja'), 'other', 'Japanese does not agree with number')
assertEqual(category(9, 'ja'), 'other', 'at any count')
assertEqual(category(0, 'fr'), 'one', 'French treats zero as singular')
assertEqual(category(1, 'de'), 'one', 'an unlisted language takes the English shape')
assertEqual(category(7, 'de'), 'other', 'at both ends of it')
assertEqual(category(-3, 'sl'), 'few', 'a negative count agrees by its magnitude')

// Picking a form, and every way a catalog can fail to supply one.
const plural = {
  'Merged from %1 device': {
    one: 'Združeno z %1 napravo',
    two: 'Združeno z %1 napravama',
    few: 'Združeno s %1 napravami',
    other: 'Združeno s %1 napravami',
  },
}
const mergedFrom = (n, catalog, lang) =>
  catalogs.translatePlural(catalog, n, 'Merged from %1 device', 'Merged from %1 devices', lang)

assertEqual(mergedFrom(2, plural, 'sl_SI.UTF-8'), 'Združeno z 2 napravama', 'the dual is reachable')
assertEqual(mergedFrom(5, plural, 'sl_SI.UTF-8'), 'Združeno s 5 napravami', 'so is the plural')
assertEqual(mergedFrom(1, {}, 'sl_SI.UTF-8'), 'Merged from 1 device', 'no catalog counts in English')
assertEqual(mergedFrom(4, {}, 'sl_SI.UTF-8'), 'Merged from 4 devices', 'in both English forms')
assertEqual(mergedFrom(2, { 'Merged from %1 device': { other: 'X %1' } }, 'sl_SI.UTF-8'), 'X 2',
  'a category the catalog skipped falls back to other')
assertEqual(mergedFrom(2, { 'Merged from %1 device': 'X %1' }, 'sl_SI.UTF-8'), 'Merged from 2 devices',
  'a plural key translated as a flat string is a catalog mistake, so English wins')

JS
