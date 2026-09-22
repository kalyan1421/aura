-- Storage: one PRIVATE bucket for user media (voice notes, capsule attachments).
-- DS-1: objects are client-encrypted ciphertext, so no mime-type allow-list (it would only ever see
-- application/octet-stream). Size limit falls back to [storage].file_size_limit.
--
-- Access model: NO storage.objects policies for anon/authenticated — not select, not insert.
-- NestJS (service role) issues signed upload URLs (createSignedUploadUrl) and signed download URLs;
-- the storage API authorises those via the signed token, not via RLS. Clients therefore can never
-- list, read, write or delete objects in this bucket directly.
insert into storage.buckets (id, name, public)
values ('private-media', 'private-media', false)
on conflict (id) do update set public = false;
