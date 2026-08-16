# v43 Discovery JavaScript Fix

- Fixed `ReferenceError: eventNode is not defined` in `BuildMatchDiscoveryScript`.
- `eventNode` is now declared once per anchor iteration before match-id extraction.
- The same resolved node is used for date filtering, text extraction, and queue insertion.
- No schema or collection-phase behavior changed.
