import { defineConfig } from "vite";

// In sviluppo Vite serve il client sulla porta 5173 e inoltra
// le connessioni Socket.IO al server di gioco sulla 3000.
export default defineConfig({
  server: {
    host: true,
    proxy: {
      "/socket.io": { target: "http://localhost:3000", ws: true },
    },
  },
  build: { outDir: "dist", chunkSizeWarningLimit: 2000 }, // Phaser da solo pesa ~1.5 MB
});
