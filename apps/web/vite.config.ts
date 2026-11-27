import path from 'node:path'
import tailwindcss from '@tailwindcss/vite'
import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'
import { moongladeDocsPlugin } from './vite-plugins/moongladeDocsPlugin'

export default defineConfig({
  plugins: [tailwindcss(), react(), moongladeDocsPlugin()],
  server: {
    host: '0.0.0.0',
    port: 5173,
    fs: {
      allow: [path.resolve(__dirname, '../..')],
    },
  },
  preview: { host: '0.0.0.0', port: 4173 },
})
