import { defineConfig, loadEnv } from 'vite';
import vue from '@vitejs/plugin-vue';
import path from 'path';

export default defineConfig(({ mode }) => {
  // Load env file (optional - can also hardcode below)
  const env = loadEnv(mode, process.cwd(), '');
  
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
  
  // Option 1: Use .env file (gitignored, good for local dev)
  // Option 2: Hardcode directly below (anon key is PUBLIC, safe to commit)
  
  const SUPABASE_URL = env.VITE_SUPABASE_URL || 'https://qcdcdzfanrlvdcagmwmg.supabase.co';
  const SUPABASE_ANON_KEY = env.VITE_SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFjZGNkemZhbnJsdmRjYWdtd21nIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MjU3MjY5MDAsImV4cCI6MjA0MTMwMjkwMH0.placeholder';
  const API_URL = env.VITE_API_URL || 'https://vespa-dashboard-9a1f84ee5341.herokuapp.com';
  
  // Validate that credentials are set (warn but don't fail if using .env)
  if (!SUPABASE_URL || SUPABASE_URL === 'YOUR_SUPABASE_URL_HERE' || 
      !SUPABASE_ANON_KEY || SUPABASE_ANON_KEY === 'YOUR_SUPABASE_ANON_KEY_HERE' || 
      SUPABASE_ANON_KEY.includes('placeholder')) {
    console.warn('⚠️ WARNING: Supabase credentials may not be set!');
    console.warn('⚠️ Check .env file or hardcode values in vite.config.js');
    // Don't throw - let build continue if .env has values
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
          entryFileNames: 'student-activities1c.js',
          chunkFileNames: 'student-activities1c-[hash].js',
          assetFileNames: (assetInfo) => {
            if (assetInfo.name.endsWith('.css')) {
              return 'student-activities1c.css';
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
      // These values are REPLACED at build time with the actual strings above
      // In the final built JS file, you'll see: const SUPABASE_URL = "https://xxx.supabase.co";
      'import.meta.env.VITE_SUPABASE_URL': JSON.stringify(SUPABASE_URL),
      'import.meta.env.VITE_SUPABASE_ANON_KEY': JSON.stringify(SUPABASE_ANON_KEY),
      'import.meta.env.VITE_API_URL': JSON.stringify(API_URL)
    }
  };
});

