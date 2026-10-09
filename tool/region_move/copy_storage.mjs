// Copies every Storage file from the old project to the new one, keeping each
// file's path, content type and cache setting. See docs/REGION_MOVE.md.
//
//   node tool/region_move/copy_storage.mjs
//
// Run it after restore.sh: the restore brings the buckets and the files'
// metadata, this brings the bytes. Uploads overwrite (x-upsert), so it is
// safe to run again after a failure. No dependencies: Node 18+ has fetch.
//
// Follows Supabase's own migration script (docs: "Migrating storage objects"),
// written against the Storage REST API instead of supabase-js.

import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));

function readEnv() {
  const env = {};
  for (const line of readFileSync(join(here, '.env'), 'utf8').split(/\r?\n/)) {
    const match = line.match(/^\s*([A-Z_]+)\s*=\s*(.*)\s*$/);
    if (match) env[match[1]] = match[2].replace(/^["']|["']$/g, '');
  }
  for (const key of ['OLD_REF', 'OLD_SERVICE_KEY', 'NEW_REF', 'NEW_SERVICE_KEY']) {
    if (!env[key]) throw new Error(`Set ${key} in tool/region_move/.env`);
  }
  return env;
}

const env = readEnv();
const OLD = { url: `https://${env.OLD_REF}.supabase.co`, key: env.OLD_SERVICE_KEY };
const NEW = { url: `https://${env.NEW_REF}.supabase.co`, key: env.NEW_SERVICE_KEY };

/// A legacy service_role key is a JWT and goes in both headers. A new secret
/// key (sb_secret_...) is not a JWT: it goes in `apikey` only, and the gateway
/// turns it into service-role access itself.
function auth(project, extra = {}) {
  const headers = { apikey: project.key, ...extra };
  if (!project.key.startsWith('sb_')) headers.Authorization = `Bearer ${project.key}`;
  return headers;
}

/// fetch, retried when the connection drops ("fetch failed": ECONNRESET and
/// the like). On a patchy line one reset otherwise fails every file after it.
async function fetchRetry(url, init, attempts = 5) {
  for (let i = 1; ; i++) {
    try {
      return await fetch(url, init);
    } catch (e) {
      if (i >= attempts) throw e;
      const wait = 2000 * 2 ** (i - 1);
      console.log(`  (connection dropped: ${e.cause?.code ?? e.message}; retrying in ${wait / 1000}s)`);
      await new Promise((r) => setTimeout(r, wait));
    }
  }
}

async function call(project, path, init = {}) {
  const res = await fetchRetry(`${project.url}/storage/v1/${path}`, {
    ...init,
    headers: auth(project, init.headers),
  });
  if (!res.ok) {
    throw new Error(`${init.method ?? 'GET'} ${path}: ${res.status} ${await res.text()}`);
  }
  return res;
}

const objectPath = (bucket, name) =>
  `object/${encodeURIComponent(bucket)}/${name.split('/').map(encodeURIComponent).join('/')}`;

/// Every file in a bucket, walking folders. A folder comes back with a null id.
async function listFiles(bucket, prefix = '') {
  const files = [];
  for (let offset = 0; ; offset += 1000) {
    const res = await call(OLD, `object/list/${encodeURIComponent(bucket)}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ prefix, limit: 1000, offset, sortBy: { column: 'name', order: 'asc' } }),
    });
    const items = await res.json();
    for (const item of items) {
      const name = prefix ? `${prefix}/${item.name}` : item.name;
      if (item.id === null) files.push(...(await listFiles(bucket, name)));
      else files.push({ name, metadata: item.metadata ?? {} });
    }
    if (items.length < 1000) return files;
  }
}

/// The restore normally brings the buckets; this covers running out of order.
async function ensureBucket(bucket) {
  const res = await fetchRetry(`${NEW.url}/storage/v1/bucket/${encodeURIComponent(bucket.id)}`, {
    headers: auth(NEW),
  });
  if (res.ok) return;
  await call(NEW, 'bucket', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      id: bucket.id,
      name: bucket.name,
      public: bucket.public,
      file_size_limit: bucket.file_size_limit,
      allowed_mime_types: bucket.allowed_mime_types,
    }),
  });
  console.log(`  created bucket ${bucket.id}`);
}

async function copyFile(bucket, file) {
  const download = await call(OLD, objectPath(bucket, file.name));
  const body = Buffer.from(await download.arrayBuffer());
  const contentType =
    file.metadata.mimetype ?? download.headers.get('content-type') ?? 'application/octet-stream';

  await call(NEW, objectPath(bucket, file.name), {
    method: 'POST',
    headers: {
      'Content-Type': contentType,
      'x-upsert': 'true',
      ...(file.metadata.cacheControl ? { 'Cache-Control': file.metadata.cacheControl } : {}),
    },
    body,
  });

  const expected = file.metadata.size;
  if (expected != null && expected !== body.length) {
    throw new Error(`size ${body.length}, expected ${expected}`);
  }
  return body.length;
}

console.log(`Copying Storage from ${OLD.url}\n                  to ${NEW.url}\n`);

const buckets = await (await call(OLD, 'bucket')).json();
let copied = 0;
let bytes = 0;
const failed = [];

for (const bucket of buckets) {
  await ensureBucket(bucket);
  const files = await listFiles(bucket.id);
  console.log(`${bucket.id}: ${files.length} files`);
  for (const file of files) {
    // A drop while a video's bytes are streaming surfaces outside fetch, so
    // the whole file is retried too.
    for (let attempt = 1; ; attempt++) {
      try {
        bytes += await copyFile(bucket.id, file);
        copied++;
        console.log(`  ok  ${file.name}`);
        break;
      } catch (e) {
        if (attempt < 3) {
          console.log(`  (${file.name}: ${e.message}; trying again)`);
          continue;
        }
        failed.push(`${bucket.id}/${file.name}: ${e.message}`);
        console.log(`  ERR ${file.name}: ${e.message}`);
        break;
      }
    }
  }
}

console.log(`\nCopied ${copied} files, ${(bytes / 1024 / 1024).toFixed(1)} MB.`);
if (failed.length) {
  console.log(`\n${failed.length} failed; run the script again to retry:`);
  for (const f of failed) console.log(`  ${f}`);
  process.exit(1);
}
