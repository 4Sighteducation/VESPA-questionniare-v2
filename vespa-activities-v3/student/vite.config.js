import { defineConfig, loadEnv } from 'vite';
import vue from '@vitejs/plugin-vue';
import path from 'path';

export default defineConfig(({ mode }) => {
  // Load env file based on `mode` in the current working directory.
  // Set the third parameter to '' to load all env regardless of the `VITE_` prefix.
  const env = loadEnv(mode, process.cwd(), '');
  
  return {
    plugins: [vue()],
    resolve: {
      alias: {
        '@': path.resolve(__dirname, './src')
      }
    },
    build: {
      outDir: 'dist',
      assetsDir: '',
      rollupOptions: {
        input: {
          main: path.resolve(__dirname, 'index.html')
        },
        output: {
          // IIFE format to prevent DOM conflicts when loading multiple apps
          format: 'iife',
          name: 'VESPAStudentActivities',
          // Version suffix for CDN cache busting - INCREMENT FOR EACH BUILD
          entryFileNames: 'student-activities1b.js',
          chunkFileNames: 'student-activities1b-[hash].js',
          assetFileNames: (assetInfo) => {
            if (assetInfo.name.endsWith('.css')) {
              return 'student-activities1b.css';
            }
            return 'assets/[name]-[hash][extname]';
          }
        }
      },
      cssCodeSplit: false,
      minify: 'terser',
      terserOptions: {
        compress: {
          drop_console: true,  // Remove console.logs in production
          drop_debugger: true
        }
      }
    },
    define: {
      // Embed env variables at build time from .env file
      'import.meta.env.VITE_SUPABASE_URL': JSON.stringify(env.VITE_SUPABASE_URL || ''),
      'import.meta.env.VITE_SUPABASE_ANON_KEY': JSON.stringify(env.VITE_SUPABASE_ANON_KEY || ''),
      'import.meta.env.VITE_API_URL': JSON.stringify(env.VITE_API_URL || 'https://vespa-dashboard-9a1f84ee5341.herokuapp.com')
    }
  };
});

