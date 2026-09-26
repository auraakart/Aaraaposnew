# V2.8 — Localization & Accessibility Foundation

## Purpose

V2.8 introduces a real locale framework for AaraaPOS instead of language-specific screen forks.

The first reviewed application-shell languages are:
- English
- Hindi
- Tamil

The user can keep the device/system language or explicitly select one of these reviewed languages.

The explicit preference is stored in the offline local context so it remains available without network connectivity.

## Current translated surface

V2.8 translates the first high-frequency shell:
- bottom navigation
- page titles
- local-storage failure message
- primary Sell search/action labels
- language/accessibility settings

This is the localization foundation, not a claim that every secondary workflow has already been translated.

Remaining screen strings can move into the same catalog incrementally without duplicating business logic.

## Planned languages

The localization catalog reserves product planning for:
- Telugu
- Malayalam
- Kannada
- Marathi
- Bengali
- Gujarati
- Punjabi

These languages are deliberately **not** listed as supported yet.

AaraaPOS will only mark a language supported after:
1. translation is complete,
2. core POS terminology is reviewed,
3. layout/text-overflow regression tests pass,
4. critical receipts/payment/stock terms are validated.

## Accessibility

AaraaPOS does not override the user’s device text scale.

The existing Material 3 UI keeps:
- visible navigation labels
- large primary action targets
- icon tooltips where icons are used alone
- readable selected-state navigation
- no language-specific business logic

The Language & Accessibility screen explains that text scaling follows Android/iOS accessibility settings.

## Architecture

### AppStrings
A lightweight localization catalog owns user-facing translated strings.

### AppLocaleController
Controls either:
- system locale, or
- an explicit reviewed locale.

Unsupported locale codes are rejected rather than silently pretending support.

### AppLocaleScope
Exposes locale selection through the widget tree without introducing a second application-state framework.

### Offline persistence
SQLite local context schema version 11 adds:
- preferred_locale_code

Allowed persisted application locales are currently:
- en
- hi
- ta

Null means follow the system locale.

## Testing

Tests cover:
- Hindi/Tamil translation values
- reviewed-locale validation
- planned-vs-supported locale separation
- offline preference persistence/reset
- unsupported locale rejection
- persisted Hindi preference reaching the rendered navigation shell

## Boundary

Not claimed in V2.8:
- complete translation of every secondary screen
- Telugu/Malayalam/Kannada/Marathi/Bengali/Gujarati/Punjabi support
- professional linguistic certification
- screen-reader certification on physical Android/iOS devices
- WCAG conformance certification

Those require continued translation review and device-level accessibility validation.
