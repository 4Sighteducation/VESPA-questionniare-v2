/**
 * Migrate Object_46 (Activity Answers) for students with no activity_responses
 * 
 * Specifically for Coffs Harbour and other schools where students only have
 * Object_46 records (answers) but not Object_126 (progress tracking)
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

async function knackAPI(endpoint, page = 1) {
  const url = `https://api.knack.com/v1/${endpoint}${endpoint.includes('?') ? '&' : '?'}page=${page}&rows_per_page=1000`;
  
  const response = await fetch(url, {
    headers: {
      'X-Knack-Application-Id': KNACK_APP_ID,
      'X-Knack-REST-API-Key': KNACK_API_KEY
    }
  });
  
  if (!response.ok) throw new Error(`Knack error: ${response.status}`);
  return await response.json();
}

async function getAllRecords(objectId, maxPages = 30) {
  console.log(`📥 Fetching ${objectId}...`);
  let all = [];
  let page = 1;
  
  while (page <= maxPages) {
    const data = await knackAPI(`objects/${objectId}/records`, page);
    all = all.concat(data.records);
    console.log(`   Page ${page}: ${data.records.length} (total: ${all.length})`);
    if (data.records.length < 1000) break;
    page++;
    await new Promise(r => setTimeout(r, 500));
  }
  
  console.log(`✅ Loaded ${all.length}\n`);
  return all;
}

function cleanEmail(field) {
  if (!field) return null;
  if (typeof field === 'string') return field.replace(/<[^>]*>/g, '').trim().toLowerCase();
  if (field.email) return field.email.toLowerCase();
  if (Array.isArray(field) && field[0]?.identifier) return field[0].identifier.toLowerCase();
  return null;
}

async function migrate(dryRun = true) {
  console.log(`${dryRun ? 'DRY RUN - ' : ''}MIGRATE OBJECT_46 FOR MISSING STUDENTS`);
  
  const stats = { processed: 0, created: 0, skipped: 0, errors: [] };
  
  // Load activities mapping
  const { data: activities } = await supabase.from('activities').select('id, name, knack_id');
  const activityMap = {};
  activities.forEach(a => {
    if (a.name) activityMap[a.name.toLowerCase()] = a.id;
  });
  
  // Load ALL students (paginate to get all 21k+)
  console.log('Loading ALL students from Supabase...');
  let students = [];
  let page = 0;
  const pageSize = 1000;
  
  while (true) {
    const { data, error } = await supabase.from('vespa_students')
      .select('email, school_id, school_name')
      .not('school_id', 'is', null)
      .range(page * pageSize, (page + 1) * pageSize - 1);
    
    if (error) throw error;
    if (!data || data.length === 0) break;
    
    students = students.concat(data);
    page++;
    
    if (data.length < pageSize) break;
  }
  
  console.log(`✅ Loaded ${students.length} students\n`);
  
  const studentSet = new Set(students.map(s => s.email.toLowerCase()));
  
  // Debug: Check if Darion is in the set
  const darionEmail = 'darion.holzhauser@education.nsw.gov.au';
  console.log(`DEBUG: Is Darion in studentSet? ${studentSet.has(darionEmail)}`);
  console.log(`DEBUG: Sample Coffs emails in set:`, 
    [...studentSet].filter(e => e.includes('education.nsw.gov.au')).slice(0, 5));
  
  // Fetch Object_46
  const object46 = await getAllRecords('object_46', 30);
  
  let debugCount = 0;
  
  for (const record of object46) {
    stats.processed++;
    
    // Extract email from array format with HTML cleaning
    const studentEmail = cleanEmail(
      record.field_1301_raw?.[0]?.identifier || 
      record.field_1301_raw?.[0]?.email || 
      record.field_1301
    );
    const activityName = record.field_1302_raw?.[0]?.identifier || record.field_1302;
    
    // Debug Coffs records
    if (debugCount < 5 && studentEmail && studentEmail.includes('education.nsw.gov.au')) {
      console.log(`\n[DEBUG Coffs #${++debugCount}]`);
      console.log(`  Email: ${studentEmail}`);
      console.log(`  Activity: ${activityName}`);
      console.log(`  Student exists: ${studentSet.has(studentEmail)}`);
      console.log(`  Activity ID: ${activityMap[activityName?.toLowerCase()]}`);
    }
    
    if (!studentEmail || !activityName) continue;
    if (!studentSet.has(studentEmail)) continue; // Student doesn't exist
    
    const activityId = activityMap[activityName.toLowerCase()];
    if (!activityId) continue;
    
    // Check if already exists
    const { data: existing } = await supabase
      .from('activity_responses')
      .select('id')
      .eq('student_email', studentEmail)
      .eq('activity_id', activityId)
      .limit(1);
    
    if (existing && existing.length > 0) {
      stats.skipped++;
      continue;
    }
    
    // Parse responses
    let responses = record.field_1300 || {};
    if (typeof responses === 'string') {
      try {
        responses = JSON.parse(responses);
      } catch (e) {
        responses = {};
      }
    }
    
    if (dryRun) {
      if (stats.created < 10) {
        console.log(`Would create: ${studentEmail} → ${activityName}`);
      }
      stats.created++;
    } else {
      const { error } = await supabase.from('activity_responses').insert({
        student_email: studentEmail,
        activity_id: activityId,
        cycle_number: 1,
        academic_year: '2025/2026',
        status: 'completed',
        responses: responses,
        responses_text: record.field_2334 || '',
        completed_at: new Date().toISOString()
      });
      
      if (error) {
        stats.errors.push({ studentEmail, activityName, error: error.message });
      } else {
        stats.created++;
        if (stats.created % 50 === 0) console.log(`Created ${stats.created}...`);
      }
    }
  }
  
  console.log(`\n${'='.repeat(60)}`);
  console.log(`Processed: ${stats.processed}`);
  console.log(`${dryRun ? 'Would create' : 'Created'}: ${stats.created}`);
  console.log(`Skipped (exists): ${stats.skipped}`);
  console.log(`Errors: ${stats.errors.length}`);
  console.log(`${'='.repeat(60)}`);
}

const dryRun = !process.argv.includes('--live');
migrate(dryRun).then(() => process.exit(0)).catch(err => {
  console.error(err);
  process.exit(1);
});

