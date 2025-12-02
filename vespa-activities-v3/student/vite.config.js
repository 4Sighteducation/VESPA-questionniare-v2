import { defineConfig, loadEnv } from 'vite';
import vue from '@vitejs/plugin-vue';
import path from 'path';

export default defineConfig(({ mode }) => {
  // Load env file from the student directory (where vite.config.js is located)
  // loadEnv searches for .env files starting from the rootDir (second param)
  // The third param '' means load ALL env vars (not just VITE_ prefixed)
  // But Vite only exposes VITE_ prefixed vars to client code anyway
  const rootDir = path.resolve(__dirname);
  const env = loadEnv(mode, rootDir, '');
  
  // Debug: Log what we loaded (only in dev mode)
  if (mode === 'development') {
    console.log('🔍 Loading env from:', rootDir);
    console.log('🔍 VITE_SUPABASE_URL:', env.VITE_SUPABASE_URL ? '✅ Found' : '❌ Missing');
    console.log('🔍 VITE_SUPABASE_ANON_KEY:', env.VITE_SUPABASE_ANON_KEY ? '✅ Found (' + env.VITE_SUPABASE_ANON_KEY.substring(0, 20) + '...)' : '❌ Missing');
  }
  
  // ============================================
  // SUPABASE CREDENTIALS - HARDCODED HERE
  // These values are EMBEDDED into the built JS file at build time
  // The .env file is ONLY used during build - values are baked into the final JS
  // 
  // HOW IT WORKS:
  // 1. During build, Vite replaces import.meta.env.VITE_SUPABASE_URL with the actual string
  // 2. The built JS file contains: const SUPABASE_URL = "https://xxx.supabase.co";
  // 3. When loaded from CDN, the values are already hardcoded in the JS file
  // 4. No .env file is needed at runtime - everything is embedded!
  //
  // 🔒 SECURITY NOTE:
  // - ANON KEY is PUBLIC and SAFE to expose (designed for frontend use)
  // - Security comes from Row Level Security (RLS) policies in Supabase
  // - This is STANDARD PRACTICE (Firebase, Stripe, etc. all do this)
  // - SERVICE KEY stays on backend only (never exposed)
  // See SECURITY_EXPLANATION.md for details
  // ============================================
  
  // Load from .env file, with fallback to hardcoded values
  const SUPABASE_URL = env.VITE_SUPABASE_URL || 'https://qcdcdzfanrlvdcagmwmg.supabase.co';
  const SUPABASE_ANON_KEY = env.VITE_SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFjZGNkemZhbnJsdmRjYWdtd21nIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTM5MDc4MjYsImV4cCI6MjA2OTQ4MzgyNn0.ahntO4OGSBfR2vnP_gMxfaRggP4eD5mejzq5sZegmME';
  const API_URL = env.VITE_API_URL || 'https://vespa-dashboard-9a1f84ee5341.herokuapp.com';
  
  // Validate that credentials are set
  if (!SUPABASE_URL || !SUPABASE_ANON_KEY || SUPABASE_ANON_KEY.includes('placeholder')) {
    console.error('❌ ERROR: Supabase ANON key not properly loaded!');
    console.error('❌ Check .env file has VITE_SUPABASE_ANON_KEY set');
    throw new Error('Supabase credentials must be set before building');
  }
  
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
          entryFileNames: 'student-activities1x.js',
          chunkFileNames: 'student-activities1x-[hash].js',
          assetFileNames: (assetInfo) => {
            if (assetInfo.name.endsWith('.css')) {
              return 'student-activities1x.css';
            }
            return 'assets/[name]-[hash][extname]';
          }
        }
      },
      cssCodeSplit: false,
      minify: 'terser',
      terserOptions: {
        compress: {
          drop_console: false,  // KEEP console.logs for debugging
          drop_debugger: true
        }
      }
    },
    define: {
      // These values are REPLACED at build time with the actual strings above
      // In the final built JS file, you'll see: const SUPABASE_URL = "https://xxx.supabase.co";
      'import.meta.env.VITE_SUPABASE_URL': JSON.stringify(SUPABASE_URL),
      'import.meta.env.VITE_SUPABASE_ANON_KEY': JSON.stringify(SUPABASE_ANON_KEY),
      'import.meta.env.VITE_API_URL': JSON.stringify(API_URL)
    }
  };
});

