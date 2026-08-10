class_name BoardLayout
extends RefCounted
## Shared card-count <-> grid-columns mapping for the parent-configurable
## board size. Kept in one place so [Main] (which lays out the actual grid)
## and [ParentSettings] (which offers the choice, labeled by its real RxC
## shape) can't drift apart. Rows always follow as count / columns -- there
## is no independent "rows" setting.

## Each supported board size, in the order offered to the parent.
const OPTIONS: Array[Dictionary] = [
	{"count": 9, "columns": 3},
	{"count": 12, "columns": 4},
	{"count": 15, "columns": 5},
]
const DEFAULT_COUNT := 12


## Columns for [param count]. Falls back to [param fallback_columns] (e.g.
## [member Main.columns]'s own @export default) if [param count] isn't one
## of [constant OPTIONS] -- keeps a manually-tuned [member Main.image_count]
## outside the parent-offered choices from breaking instead of erroring.
static func columns_for(count: int, fallback_columns: int) -> int:
	for option: Dictionary in OPTIONS:
		if option.count == count:
			return option.columns
	return fallback_columns


## "RxC" (rows x columns) label for one of [constant OPTIONS]'s counts,
## e.g. 9 -> "3x3", 12 -> "3x4", 15 -> "3x5" -- what the parent actually
## sees instead of a bare card count. Falls back to the plain number for a
## count outside the known options.
static func label_for(count: int) -> String:
	var cols := columns_for(count, 0)
	if cols <= 0:
		return str(count)
	return "%dx%d" % [count / cols, cols]
