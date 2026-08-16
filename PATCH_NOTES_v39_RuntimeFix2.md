# v39 Runtime Fix 2

Schema remains `3.19`.

This package includes all changes from `v39_RuntimeFix` plus the following
Delphi compile-warning cleanup.

## Changed in Runtime Fix 2

### Source/Collector.StructuredEvents.pas

1. `RosterIndex` and the other roster-array temporaries are now local to the
   nested `AddArray` procedure. This fixes:

   `E1019 For loop control variable must be simple local variable`

2. Deprecated `TCharacter.IsLetterOrDigit` calls were replaced with
   `TCharHelper` instance calls:

   `CharacterValue.IsLetterOrDigit`

3. The initial assignments to `UnlinkedVarEventCount` and
   `UnlinkedOverturnedCardCount` were removed because both variables are
   unconditionally calculated before their first read. This removes H2077
   hints without changing runtime behavior.

### Source/MainFormUnit.pas

1. Deprecated `TCharacter` calls were replaced with `TCharHelper` calls:

   - `CharacterValue.IsLetterOrDigit`
   - `CharacterValue.ToLower`

2. The redundant initial `Result := False` assignment in
   `ResolveRedCardEvent` was removed. The function result is assigned from the
   final matching expression on every normal execution path. This removes the
   H2077 hint.

3. `System.Character` was removed from the uses lists because the deprecated
   `TCharacter` type is no longer used.

## Compilation status

No Delphi compilation is claimed. Compile this package using the real Delphi
compiler, then provide the resulting build output and regenerated JSON files.
