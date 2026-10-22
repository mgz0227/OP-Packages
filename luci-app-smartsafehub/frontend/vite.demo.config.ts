import { fileURLToPath, URL } from 'node:url';

import preact from '@preact/preset-vite';
import tailwindcss from '@tailwindcss/vite';
import { defineConfig } from 'vite';

// Separate public website bundle: never include LuCI authentication or RPC entry code.
export default defineConfig({
  base: '/static/router-demo/',
  publicDir: false,
  plugins: [preact(), tailwindcss()],
  build: {
    target: 'es2020',
    outDir: fileURLToPath(new URL('./demo-dist', import.meta.url)),
    emptyOutDir: true,
    cssCodeSplit: false,
    sourcemap: false,
    rollupOptions: {
      input: fileURLToPath(new URL('./src/demo/main.tsx', import.meta.url)),
      output: {
        entryFileNames: 'demo.js',
        chunkFileNames: 'chunks/[name]-[hash].js',
        assetFileNames: (asset) => asset.name?.endsWith('.css') ? 'demo.css' : 'assets/[name]-[hash][extname]',
      },
    },
  },
});
