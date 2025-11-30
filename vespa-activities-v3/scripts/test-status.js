/**
 * Test which status values are allowed
 */

const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL = 'https://qcdcdzfanrlvdcagmwmg.supabase.co';
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY;

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

async function test() {
  console.log('Testing different status values...\n');
  
  const values = ['in_progress', 'completed', 'assigned', 'removed', 'cancelled'];
  
  for (const val of values) {
    const testData = {
      student_email: 'test123@example.com',
      activity_id: '0193d06b-4d82-7ad3-a21d-fdc1bda3d8b4',
      cycle_number: 98,
      academic_year: '2025/2026',
      status: val,
      selected_via: 'student_choice'
    };
    
    const { error } = await supabase
      .from('activity_responses')
      .insert(testData);
    
    if (error) {
      console.log(`❌ "${val}": ${error.message.substring(0, 80)}`);
    } else {
      console.log(`✅ "${val}": Success`);
      // Clean up
      await supabase
        .from('activity_responses')
        .delete()
        .eq('student_email', 'test123@example.com')
        .eq('cycle_number', 98);
    }
  }
}

test();

