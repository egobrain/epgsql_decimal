epgsql decimal codec
=====

Codec for decimal (numeric) data type for epgsql 4+

Usage
---

You need to add epgsql dep in your project before epgsql_decimal, to provide behaviour module.

Add `{codecs, [{epgsql_decimal, []}]}` to epgsql connection params.