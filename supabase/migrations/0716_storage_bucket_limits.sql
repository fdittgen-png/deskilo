-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- (two storage buckets gain a size limit and a list of accepted types; no
-- stored object is touched)
--
-- GHSA-4xwv-f96x-7mrq -- every bucket a migration declares has a size limit
-- and the types it accepts:
--
--  * avatars          5 MB, JPEG, PNG or WebP (what the photo picker offers);
--  * bank-statements  5 MB (already), the bytes the importer uploads.

update storage.buckets
   set file_size_limit = 5242880,
       allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp']
 where id = 'avatars';

update storage.buckets
   set allowed_mime_types = array['application/octet-stream']
 where id = 'bank-statements';

select public.set_deskilo_schema_version(716);
