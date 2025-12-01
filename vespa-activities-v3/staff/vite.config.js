import { defineConfig, loadEnv } from 'vite';
import vue from '@vitejs/plugin-vue';
import path from 'path';

export default defineConfig(({ mode }) => {
  const rootDir = path.resolve(__dirname);
  const env = loadEnv(mode, rootDir, '');
  
  // Load Supabase credentials
  const SUPABASE_URL = env.VITE_SUPABASE_URL || 'https://qcdcdzfanrlvdcagmwmg.supabase.co';
  const SUPABASE_ANON_KEY = env.VITE_SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFjZGNkemZhbnJsdmRjYWdtd21nIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTM5MDc4MjYsImV4cCI6MjA2OTQ4MzgyNn0.ahntO4OGSBfR2vnP_gMxfaRggP4eD5mejzq5sZegmME';
  const ACCOUNT_API_URL = env.VITE_ACCOUNT_API_URL || 'https://vespa-upload-api-07e11c285370.herokuapp.com';
  
  return {
    plugins: [vue()],
    resolve: {
      alias: {
        '@': path.resolve(__dirname, './src')
      }
    },
    server: {
      port: 3001,
      open: true
    },
    build: {
      outDir: 'dist',
      assetsDir: '',  // No assets subfolder
      rollupOptions: {
        input: {
          main: path.resolve(__dirname, 'index.html')
        },
        output: {
          format: 'iife',  // Back to IIFE for Knack
          name: 'VESPAStaffActivities',
          entryFileNames: 'activity-dashboard-2m.js',  // Version 2m - Use RPC for removal (bypasses RLS)
          chunkFileNames: 'activity-dashboard-2m-[hash].js',
          assetFileNames: (assetInfo) => {
            if (assetInfo.name.endsWith('.css')) {
              return 'activity-dashboard-2m.css';
            }
            return 'assets/[name]-[hash][extname]';
          }
        }
      },
      cssCodeSplit: false,
      minify: 'terser',
      terserOptions: {
        compress: {
          drop_console: false,  // Keep console logs for debugging
          drop_debugger: true
        }
      }
    },
    define: {
      'import.meta.env.VITE_SUPABASE_URL': JSON.stringify(SUPABASE_URL),
      'import.meta.env.VITE_SUPABASE_ANON_KEY': JSON.stringify(SUPABASE_ANON_KEY),
      'import.meta.env.VITE_ACCOUNT_API_URL': JSON.stringify(ACCOUNT_API_URL)
    }
  };
});