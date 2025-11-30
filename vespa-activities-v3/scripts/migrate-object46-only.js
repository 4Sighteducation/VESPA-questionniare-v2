/**
 * MIGRATE OBJECT_46 ONLY
 * 
 * Object_126 has no student connections (orphaned data)
 * Object_46 has 16,186 real completion records
 * Let's migrate those instead!
 */

const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL = 'https://qcdcdzfanrlvdcagmwmg.supabase.co';
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY;
const KNACK_APP_ID = '5ee90912c38ae7001510c1a9';
const KNACK_API_KEY = '8f733aa5-dd35-4464-8348-64824d1f5f0d';

if (!SUPABASE_SERVICE_KEY) {
  console.error('❌ SUPABASE_SERVICE_KEY required!');
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

async function migrate() {
  console.log('🚀 Migrating Object_46 (Activity Answers) to Supabase...\n');
  
  const stats = { processed: 0, migrated: 0, skipped: 0, errors: [] };
  
  try {
    // Load activity name → UUID map
    const { data: activities } = await supabase.from('activities').select('id, name, knack_id');
    const nameMap = {};
    const knackIdMap = {};
    activities.forEach(a => {
      if (a.name) nameMap[a.name] = a.id;
      if (a.knack_id) knackIdMap[a.knack_id] = a.id;
    });
    console.log(`✅ Loaded ${activities.length} activities\n`);
    
    // Fetch Object_46 records in batches
    let page = 1;
    let hasMore = true;
    
    while (hasMore && page <= 20) {
      console.log(`📥 Fetching Object_46 page ${page}...`);
      
      const response = await fetch(`https://api.knack.com/v1/objects/object_46/records?page=${page}&rows_per_page=1000`, {
        headers: {
          'X-Knack-Application-Id': KNACK_APP_ID,
          'X-Knack-REST-API-Key': KNACK_API_KEY
        }
      });
      
      const data = await response.json();
      hasMore = data.records.length === 1000;
      
      for (const record of data.records) {
        stats.processed++;
        
        try {
          // Extract student email from field_1301
          const studentField = record.field_1301;
          let studentEmail = null;
          
          if (typeof studentField === 'string') {
            studentEmail = studentField.replace(/<[^>]*>/g, '').trim();
            if (studentEmail.includes('@')) {
              // It's an email
            } else {
              // It's probably a Knack ID, skip
              stats.skipped++;
              continue;
            }
          }
          
          if (!studentEmail || !studentEmail.includes('@')) {
            stats.skipped++;
            continue;
          }
          
          // Extract activity name from field_1302
          const activityField = record.field_1302;
          let activityName = null;
          
          if (typeof activityField === 'string' && activityField.includes('<span')) {
            const match = activityField.match(/>([^<]+)</);
            activityName = match ? match[1].trim() : null;
          } else if (typeof activityField === 'string') {
            activityName = activityField.trim();
          }
          
          if (!activityName) {
            stats.skipped++;
            continue;
          }
          
          // Map to Supabase UUID
          const activityId = nameMap[activityName] || knackIdMap[record.field_1302];
          if (!activityId) {
            stats.skipped++;
            continue;
          }
          
          // Build response data
          const responseData = {
            student_email: studentEmail,
            activity_id: activityId,
            cycle_number: 1, // Default
            academic_year: '2025/2026',
            status: record.field_1870 ? 'completed' : 'in_progress',
            completed_at: record.field_1870 || null,
            responses: record.field_1300 ? (typeof record.field_1300 === 'string' ? JSON.parse(record.field_1300) : record.field_1300) : {},
            responses_text: record.field_2334 || '',
            staff_feedback: record.field_1734 || null,
            selected_via: 'student_choice', // Default
            knack_id: record.id
          };
          
          // Upsert
          const { error } = await supabase
            .from('activity_responses')
            .upsert(responseData, { onConflict: 'student_email,activity_id,cycle_number' });
          
          if (error) {
            stats.errors.push({ record: record.id, error: error.message });
          } else {
            stats.migrated++;
            if (stats.migrated % 100 === 0) {
              console.log(`   ✅ Migrated ${stats.migrated}...`);
            }
          }
          
        } catch (err) {
          stats.errors.push({ record: record.id, error: err.message });
        }
      }
      
      page++;
      await new Promise(r => setTimeout(r, 500)); // Rate limit
    }
    
    console.log('\n' + '='.repeat(60));
    console.log(`✅ Processed: ${stats.processed}`);
    console.log(`✅ Migrated: ${stats.migrated}`);
    console.log(`⚠️  Skipped: ${stats.skipped}`);
    console.log(`❌ Errors: ${stats.errors.length}`);
    
    // Check result
    const { count } = await supabase
      .from('activity_responses')
      .select('*', { count: 'exact', head: true })
      .like('student_email', '%@vespa.academy');
    
    console.log(`\n✅ VESPA ACADEMY responses: ${count}`);
    
  } catch (error) {
    console.error('❌ Migration failed:', error);
  }
}

migrate().then(() => process.exit(0)).catch(err => { console.error(err); process.exit(1); });

