-- SPDX-License-Identifier: AGPL-3.0-or-later
-- GHSA-4xwv-f96x-7mrq: every bucket the migrations declare is private, has a
-- size limit and a list of accepted types.
begin;
select plan(4);

select is((select array_agg(id order by id) from storage.buckets
            where id in ('avatars','bank-statements','floor-plans') and not public),
          array['avatars','bank-statements','floor-plans'],
          'the declared buckets are private');
select is((select count(*)::int from storage.buckets
            where id in ('avatars','bank-statements','floor-plans')
              and (file_size_limit is null or allowed_mime_types is null)), 0,
          'each has a size limit and a list of accepted types');
select is((select allowed_mime_types from storage.buckets where id = 'avatars'),
          array['image/jpeg','image/png','image/webp'],
          'a photo is a JPEG, PNG or WebP');
select ok((select file_size_limit from storage.buckets where id = 'avatars') <= 5242880,
          'a photo is at most 5 MB');

select * from finish();
rollback;
