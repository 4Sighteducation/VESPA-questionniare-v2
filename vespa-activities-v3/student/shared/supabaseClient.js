/**
 * Shared Supabase Client Configuration
 * Used by both student and staff apps
 */

import { createClient } from '@supabase/supabase-js';

// These will be replaced at build time by Vite
const SUPABASE_URL = import.meta.env.VITE_SUPABASE_URL;
const SUPABASE_ANON_KEY = import.meta.env.VITE_SUPABASE_ANON_KEY;

if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
  console.error('❌ Missing Supabase environment variables!');
  console.error('SUPABASE_URL:', SUPABASE_URL ? 'Set' : 'Missing');
  console.error('SUPABASE_ANON_KEY:', SUPABASE_ANON_KEY ? 'Set' : 'Missing');
}

// Create Supabase client
export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: {
    autoRefreshToken: false,
    persistSession: false,
    detectSessionInUrl: false
  },
  realtime: {
    params: {
      eventsPerSecond: 10
    }
  }
});

console.log('✅ Supabase client initialized');

export default supabase;


