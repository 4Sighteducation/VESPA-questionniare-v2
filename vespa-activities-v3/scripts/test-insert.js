/**
 * Test inserting with different selected_via values
 */

const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL = 'https://qcdcdzfanrlvdcagmwmg.supabase.co';
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY;

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

async function test() {
  console.log('Testing different selected_via values...\n');
  
  const values = ['student_choice', 'questionnaire', 'staff_assigned', 'prescribed'];
  
  for (const val of values) {
    const testData = {
      student_email: 'test@example.com',
      activity_id: '0193d06b-4d82-7ad3-a21d-fdc1bda3d8b4', // Use first activity UUID
      cycle_number: 99,
      academic_year: '2025/2026',
      status: 'in_progress',
      selected_via: val
    };
    
    const { error } = await supabase
      .from('activity_responses')
      .insert(testData);
    
    if (error) {
      console.log(`❌ "${val}": ${error.message}`);
    } else {
      console.log(`✅ "${val}": Success`);
      // Clean up
      await supabase
        .from('activity_responses')
        .delete()
        .eq('student_email', 'test@example.com')
        .eq('cycle_number', 99);
    }
  }
}

test();

