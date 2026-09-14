import type { APIRoute } from 'astro';
import { site } from '../site';

// Hand-listed rather than an integration: five pages don't justify a dependency.
// Add a path here when you add an indexable page.
const paths = ['/', '/privacy', '/terms', '/delete-account'];

export const GET: APIRoute = () => {
  const urls = paths
    .map((path) => `  <url><loc>${new URL(path, site.url).href}</loc></url>`)
    .join('\n');

  return new Response(
    `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${urls}\n</urlset>\n`,
    { headers: { 'Content-Type': 'application/xml' } },
  );
};
