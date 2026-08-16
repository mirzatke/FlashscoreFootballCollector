# v45.6 Profile Logs

- Every competition and season profile now writes to its own log file.
- League log path: `Data\Logs\<League>\<Season>\collector.log`.
- World Cup log path: `Data\Logs\WC\WC_<Year>\collector.log`.
- Selecting another competition or season immediately switches `FConfig.LogFile`
  to the selected profile before discovery or collection starts.
- Separate collector instances running different competition/season profiles no
  longer write to the same physical log file.

Examples:

- `Data\Logs\PremierLeague\2025_2026\collector.log`
- `Data\Logs\LaLiga\2024_2025\collector.log`
- `Data\Logs\WC\WC_2022\collector.log`

Not compiled in this environment. Compile with Delphi 12.3 and verify two
simultaneous runs using different profiles.
