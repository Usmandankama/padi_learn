// @ts-check
import { defineConfig } from 'astro/config';

// A fully static build: Cloudflare Pages serves `dist/` as plain files.
// `site` is used for canonical URLs and the sitemap.
export default defineConfig({
  site: 'https://padilearn.com',
  trailingSlash: 'never',
  build: {
    // /privacy.html is served at /privacy on Cloudflare Pages, so links never
    // need a trailing slash.
    format: 'file',
  },
});
