import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// npm run dev: o Vite serve o React com recarga instantânea e repassa /api
// para o servidor do painel (npm start, na porta 4170).
export default defineConfig({
  plugins: [react()],
  server: { port: 5173, proxy: { '/api': 'http://localhost:4170' } },
  build: { outDir: 'dist', emptyOutDir: true, chunkSizeWarningLimit: 900 },
});
