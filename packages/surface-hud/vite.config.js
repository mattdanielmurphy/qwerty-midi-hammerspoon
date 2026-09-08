import { defineConfig } from 'vite';
import { resolve } from 'path';

export default defineConfig({
  root: resolve(__dirname, 'src/web'),
  server: {
    port: 5173,
    strictPort: true,
    hmr: true,
  },
});
