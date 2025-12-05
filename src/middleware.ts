import { defineMiddleware } from 'astro:middleware';
import { database } from '@/lib/db';

export const onRequest = defineMiddleware(async (context, next) => {
  // Set up the runtime object to maintain compatibility with the existing code
  // This mimics the Cloudflare Workers runtime structure
  context.locals.runtime = {
    env: {
      DB: database,
      AUTH_KEY: process.env.AUTH_KEY || '',
    },
  };

  return next();
});
