import { fileURLToPath, URL } from 'node:url'

import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

// https://vitejs.dev/config/
const stdExport = {
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
}

export default defineConfig(({ command, mode, ssrBuild }) => {
  if (command === 'serve' && command === 'build') {
    return stdExport
  } else if (command === 'development') {
    console.log('mode: ', mode)
    const env = loadEnv(mode, process.cwd(), '');
    stdExport.define = {
      VUE_APP_X: "AYZ"
    }
    return stdExport
  } else {
    console.log('mode: ', mode)
    return stdExport
  }
});

