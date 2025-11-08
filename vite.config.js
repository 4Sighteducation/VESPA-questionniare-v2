import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  plugins: [vue()],
  build: {
    outDir: 'dist',
    assetsDir: 'assets',
    rollupOptions: {
      output: {
        // Generate versioned filenames for CDN cache busting
        entryFileNames: 'questionnaire1j.js',
        chunkFileNames: 'chunks/[name].js',
        assetFileNames: (assetInfo) => {
          if (assetInfo.name.endsWith('.css')) {
            return 'questionnaire1j.css'
          }
          return 'assets/[name].[ext]'
        }
      }
    }
  },
  define: {
    // Expose config at build time
    __DASHBOARD_API_URL__: JSON.stringify(process.env.DASHBOARD_API_URL || 'https://vespa-dashboard-9a1f84ee5341.herokuapp.com'),
    __KNACK_APP_ID__: JSON.stringify('5ee90912c38ae7001510c1a9'),
    __KNACK_API_KEY__: JSON.stringify('8f733aa5-dd35-4464-8348-64824d1f5f0d')
  }
})

