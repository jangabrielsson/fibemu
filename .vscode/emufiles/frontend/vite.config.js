import { fileURLToPath, URL } from 'node:url'

import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [
    vue(),
  ],
  // base: '/frontend',
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url))
    }
  },
  server: {
    hmr: {
      overlay: false
    }
  },
  // transpileDependencies: true,    //Transpile your dependencies
  // publicPath: "/static",          //Path of static directory
  //outputDir: path.resolve(__dirname, '../static'),   // Output path for the static files

})
