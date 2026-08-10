class_name SettingsKeys
extends RefCounted
## Shared [autoload Settings] key names. Both the setting's UI (which
## writes) and whatever gameplay code reads it back need to agree on the
## exact key string; keeping them here instead of duplicating the literal
## in both places means they can't quietly drift apart.

## Number of cards on the board. Written by ParentSettings, read by
## [method Main._ready] to override [member Main.image_count] at startup.
const CARD_COUNT := "card_count"

## Which word categories (see [method WordDatabase.get_all_categories]) the
## game draws words from, as an Array[String]. Written by ParentSettings,
## read by [method Main._apply_stored_enabled_categories] at startup.
const ENABLED_CATEGORIES := "enabled_categories"
