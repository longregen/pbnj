/// <reference types="astro/client" />

interface Runtime {
  env: {
    DB: import('@/lib/db').typeof database;
    AUTH_KEY: string;
  };
}

declare namespace App {
  interface Locals {
    runtime: Runtime;
  }
}
