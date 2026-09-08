# The originals

Every screenshot the owner posts lands here, dated, under the id of the
screen it shows, and is never edited afterwards:

```
<yyyy-mm-dd>--<screen-id>--<n>.jpg
```

Several files with the same date and screen are captures of one form,
scrolled — `dart run tool/media.dart merge --screen <id>` stitches them
into `docs/wiki/images/<screen>-full.jpg`.

A new screenshot of a screen already documented keeps the same screen id:
the derived image in `docs/wiki/images/` is overwritten, every link in
every language keeps working, and this folder keeps both captures under
their own dates. `.media-workbench/index.md` (not in git) says what each
image shows; `dart run tool/media.dart index` rebuilds it from here.
