/**
 * Check what values are currently in selected_via column
 * to understand what the constraint allows
 */

const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL = 'https://qcdcdzfanrlvdcagmwmg.supabase.co';
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY;

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

async function check() {
  // Get distinct selected_via values
  const { data, error } = await supabase
    .from('activity_responses')
    .select('selected_via')
    .limit(1000);
  
  if (error) {
    console.error('Error:', error);
    return;
  }
  
  const uniqueValues = [...new Set(data.map(r => r.selected_via))];
  console.log('Existing selected_via values in database:');
  uniqueValues.forEach(v => console.log(`  - "${v}"`));
  
  console.log('\nCount by value:');
  const counts = {};
  data.forEach(r => {
    counts[r.selected_via] = (counts[r.selected_via] || 0) + 1;
  });
  Object.entries(counts).forEach(([v, c]) => {
    console.log(`  "${v}": ${c} records`);
  });
}

check();

