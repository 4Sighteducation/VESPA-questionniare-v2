/**
 * COMPREHENSIVE ACTIVITY MIGRATION SCRIPT
 * 
 * Migrates ALL activity data from Knack to Supabase:
 * - Object_126 (Activity Progress) - 1,095 records
 * - Object_46 (Activity Answers) - 16,186 records
 * - Object_10 (VESPA Results) - for cycle numbers and scores
 * 
 * Merges both sources into activity_responses table
 * Determines prescribed vs student_choice using threshold logic
 * 
 * Run with: node migrate-activities-complete.js
 */

const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const path = require('path');

// ==========================================
// CONFIGURATION
// ==========================================

const SUPABASE_URL = 'https://qcdcdzfanrlvdcagmwmg.supabase.co';
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY;

const KNACK_APP_ID = '5ee90912c38ae7001510c1a9';
const KNACK_API_KEY = '8f733aa5-dd35-4464-8348-64824d1f5f0d';

if (!SUPABASE_SERVICE_KEY) {
  console.error('❌ SUPABASE_SERVICE_KEY environment variable required!');
  console.error('Set it with: export SUPABASE_SERVICE_KEY="your-service-key"');
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

// ==========================================
// KNACK API HELPER
// ==========================================

async function knackAPI(endpoint, page = 1) {
  const url = `https://api.knack.com/v1/${endpoint}${endpoint.includes('?') ? '&' : '?'}page=${page}&rows_per_page=1000`;
  
  const response = await fetch(url, {
    headers: {
      'X-Knack-Application-Id': KNACK_APP_ID,
      'X-Knack-REST-API-Key': KNACK_API_KEY
    }
  });
  
  if (!response.ok) {
    throw new Error(`Knack API error: ${response.status}`);
  }
  
  return await response.json();
}

async function getAllRecords(objectId, maxPages = 20) {
  console.log(`📥 Fetching all records from ${objectId}...`);
  let allRecords = [];
  let page = 1;
  let hasMore = true;
  
  while (hasMore && page <= maxPages) {
    const data = await knackAPI(`objects/${objectId}/records`, page);
    allRecords = allRecords.concat(data.records);
    
    console.log(`   Page ${page}: ${data.records.length} records (total: ${allRecords.length})`);
    
    hasMore = data.records.length === 1000; // More pages if we got max
    page++;
    
    // Rate limiting
    await new Promise(resolve => setTimeout(resolve, 500));
  }
  
  console.log(`✅ Loaded ${allRecords.length} total records from ${objectId}\n`);
  return allRecords;
}

// ==========================================
// HELPER FUNCTIONS
// ==========================================

function extractEmail(emailField) {
  if (!emailField) return null;
  if (typeof emailField === 'string') {
    // Remove HTML tags if present
    const cleaned = emailField.replace(/<[^>]*>/g, '').trim();
    return cleaned || null;
  }
  if (Array.isArray(emailField) && emailField.length > 0) {
    if (emailField[0].email) return emailField[0].email;
    return emailField[0];
  }
  if (emailField.email) return emailField.email;
  return null;
}

function extractActivityName(activityField) {
  if (!activityField) return null;
  
  // Handle HTML format: <span class="..." data-kn="connection-value">Activity Name</span>
  if (typeof activityField === 'string' && activityField.includes('<span')) {
    const match = activityField.match(/>([^<]+)</);
    if (match && match[1]) {
      return match[1].trim();
    }
    // Fallback: remove all HTML tags
    return activityField.replace(/<[^>]*>/g, '').trim();
  }
  
  // Handle _raw format with identifier
  if (Array.isArray(activityField) && activityField.length > 0) {
    if (activityField[0].identifier) return activityField[0].identifier;
    if (activityField[0].name) return activityField[0].name;
  }
  
  if (typeof activityField === 'object' && activityField.identifier) {
    return activityField.identifier;
  }
  
  if (typeof activityField === 'string') {
    return activityField.trim();
  }
  
  return null;
}

function extractConnectionId(connectionField) {
  if (!connectionField) return null;
  if (typeof connectionField === 'string' && connectionField.length === 24) return connectionField;
  if (Array.isArray(connectionField) && connectionField[0]) {
    if (typeof connectionField[0] === 'string') return connectionField[0];
    if (connectionField[0].id) return connectionField[0].id;
  }
  if (connectionField.id) return connectionField.id;
  return null;
}

function parseKnackDate(dateField) {
  if (!dateField) return null;
  
  // Handle Knack date object format
  if (dateField.date) {
    try {
      return new Date(dateField.date).toISOString();
    } catch (e) {
      return null;
    }
  }
  
  // Handle ISO string
  if (typeof dateField === 'string') {
    try {
      return new Date(dateField).toISOString();
    } catch (e) {
      return null;
    }
  }
  
  return null;
}

// ==========================================
// MAIN MIGRATION LOGIC
// ==========================================

async function migrate() {
  console.log('🚀 VESPA Activities Migration - Starting...\n');
  console.log('=' .repeat(60));
  
  const stats = {
    object126Processed: 0,
    object126Migrated: 0,
    object46Backfilled: 0,
    errors: [],
    skipped: []
  };
  
  try {
    // Step 1: Load activity threshold mappings
    console.log('\n📖 Step 1: Loading activity thresholds from JSON...');
    const thresholdsPath = path.join(__dirname, '../../../vespa-activities-v2/shared/utils/activitiesjsonwithfields1c.json');
    const thresholdActivities = JSON.parse(fs.readFileSync(thresholdsPath, 'utf8'));
    
    // Create lookup map: activity name → thresholds
    const thresholdMap = {};
    thresholdActivities.forEach(act => {
      const name = act.activity_name?.value;
      const minScore = act.thresholds?.show_if_score_more_than?.value;
      const maxScore = act.thresholds?.show_if_score_less_or_equal?.value;
      
      if (name && (minScore !== undefined || maxScore !== undefined)) {
        thresholdMap[name] = {
          min: minScore,
          max: maxScore,
          category: act.category?.name
        };
      }
    });
    console.log(`✅ Loaded ${Object.keys(thresholdMap).length} activity threshold mappings\n`);
    
    // Step 2: Get all activities from Supabase (need UUID mapping)
    console.log('📖 Step 2: Loading activities from Supabase...');
    const { data: sbActivities, error: actError } = await supabase
      .from('activities')
      .select('id, knack_id, name, vespa_category');
    
    if (actError) throw actError;
    
    // Create lookup: Knack ID → Supabase UUID
    const activityIdMap = {};
    const activityNameMap = {};
    sbActivities.forEach(act => {
      if (act.knack_id) activityIdMap[act.knack_id] = act.id;
      if (act.name) activityNameMap[act.name] = act.id;
    });
    console.log(`✅ Loaded ${sbActivities.length} activities from Supabase\n`);
    
    // Step 3: Get all students from Supabase (need email → account_id)
    console.log('📖 Step 3: Loading students from Supabase...');
    const { data: sbStudents, error: studentError } = await supabase
      .from('vespa_students')
      .select('email, account_id, id');
    
    if (studentError) throw studentError;
    
    const studentEmailMap = {};
    sbStudents.forEach(s => {
      if (s.email) studentEmailMap[s.email.toLowerCase()] = s;
    });
    console.log(`✅ Loaded ${sbStudents.length} students from Supabase\n`);
    
    // Step 4: Fetch Object_126 (Activity Progress)
    console.log('📖 Step 4: Fetching Object_126 (Activity Progress) from Knack...');
    const progress126 = await getAllRecords('object_126', 5); // ~1,095 records
    
    // Step 5: Fetch Object_46 (Activity Answers)  
    console.log('📖 Step 5: Fetching Object_46 (Activity Answers) from Knack...');
    const answers46 = await getAllRecords('object_46', 20); // ~16,186 records
    
    // Create lookup: student email + activity name → Object_46 record
    const answersMap = {};
    answers46.forEach(answer => {
      const studentEmail = extractEmail(answer.field_1301);
      const activityName = answer.field_1302; // Activity name directly
      if (studentEmail && activityName) {
        const key = `${studentEmail.toLowerCase()}_${activityName}`;
        answersMap[key] = answer;
      }
    });
    console.log(`✅ Indexed ${Object.keys(answersMap).length} answer records\n`);
    
    // Step 6: Fetch Object_10 (VESPA Results) for cycle numbers
    console.log('📖 Step 6: Fetching Object_10 (VESPA Results) for cycle data...');
    const vespaResults = await getAllRecords('object_10', 30); // ~23k students
    
    // Create lookup: student email → VESPA data
    const vespaMap = {};
    vespaResults.forEach(result => {
      const email = extractEmail(result.field_197);
      if (email) {
        vespaMap[email.toLowerCase()] = {
          cycle: parseInt(result.field_146) || 1,
          scores: {
            vision: parseInt(result.field_147) || 5,
            effort: parseInt(result.field_148) || 5,
            systems: parseInt(result.field_149) || 5,
            practice: parseInt(result.field_150) || 5,
            attitude: parseInt(result.field_151) || 5
          }
        };
      }
    });
    console.log(`✅ Indexed ${Object.keys(vespaMap).length} VESPA score records\n`);
    
    // Step 7: Migrate Object_126 records (Priority 1)
    console.log('📖 Step 7: Migrating Object_126 (Activity Progress) records...');
    console.log('='.repeat(60) + '\n');
    
    for (const progressRecord of progress126) {
      stats.object126Processed++;
      
      try {
        // TRY BOTH field_3536 and field_3536_raw for student
        let studentEmail = extractEmail(progressRecord.field_3536);
        
        // If empty, try the _raw field which might have connection data
        if (!studentEmail && progressRecord.field_3536_raw) {
          if (Array.isArray(progressRecord.field_3536_raw) && progressRecord.field_3536_raw.length > 0) {
            // Extract email from connection object
            const conn = progressRecord.field_3536_raw[0];
            studentEmail = conn.email || conn.identifier || null;
          }
        }
        
        if (!studentEmail) {
          stats.skipped.push({ 
            reason: 'No student email', 
            record: progressRecord.id,
            field_3536: progressRecord.field_3536,
            field_3536_raw: progressRecord.field_3536_raw 
          });
          if (stats.skipped.length <= 3) {
            console.log('SKIP #' + stats.skipped.length + ': No student connection');
            console.log('  field_3536:', progressRecord.field_3536);
            console.log('  field_3536_raw:', progressRecord.field_3536_raw);
          }
          continue;
        }
        
        // FIXED: field_3537 contains ACTIVITY NAME (with HTML wrapper!)
        const activityName = extractActivityName(progressRecord.field_3537);
        if (!activityName) {
          stats.skipped.push({ 
            reason: 'No activity name', 
            record: progressRecord.id,
            field: progressRecord.field_3537 
          });
          if (stats.skipped.length <= 3) {
            console.log('SKIP #' + stats.skipped.length + ':', progressRecord);
          }
          continue;
        }
        
        // Resolve activity name to Supabase UUID
        const activityUuid = activityNameMap[activityName];
        if (!activityUuid) {
          stats.skipped.push({ 
            reason: 'Activity not in Supabase', 
            activityName,
            availableActivities: Object.keys(activityNameMap).slice(0, 5) 
          });
          if (stats.skipped.length <= 3) {
            console.log('SKIP #' + stats.skipped.length + ': Activity "' + activityName + '" not found');
            console.log('Available activities sample:', Object.keys(activityNameMap).slice(0, 5));
          }
          continue;
        }
        
        if (!studentEmail) {
          stats.skipped.push({ reason: 'No student email', studentId: studentKnackId });
          continue;
        }
        
        // Get VESPA data for cycle and scores
        const vespaData = vespaMap[studentEmail.toLowerCase()] || { cycle: 1, scores: {} };
        
        // Find matching Object_46 record
        const answerKey = `${studentEmail.toLowerCase()}_${activityName}`;
        const answerRecord = answersMap[answerKey];
        
        // Determine if prescribed using threshold logic
        let selectedVia = 'student_choice'; // Default
        
        // Activity name already extracted above, use it for threshold lookup
        if (activityName && thresholdMap[activityName] && vespaData.scores) {
          const threshold = thresholdMap[activityName];
          const category = (threshold.category || '').toLowerCase();
          const studentScore = vespaData.scores[category] || 0;
          
          // Check if student's score falls within threshold
          if (studentScore >= threshold.min && studentScore <= threshold.max) {
            selectedVia = 'questionnaire'; // Was prescribed!
          }
        }
        
        // Build activity_responses record
        const responseData = {
          student_email: studentEmail,
          activity_id: activityUuid,
          cycle_number: vespaData.cycle,
          academic_year: '2025/2026', // TODO: Determine from dates
          
          // From Object_126
          status: progressRecord.field_3543 || 'in_progress',
          started_at: parseKnackDate(progressRecord.field_3539),
          completed_at: parseKnackDate(progressRecord.field_3541),
          time_spent_minutes: parseInt(progressRecord.field_3542) || 0,
          word_count: parseInt(progressRecord.field_3549) || 0,
          selected_via: selectedVia,
          
          // From Object_46 (if exists)
          responses: answerRecord?.field_1300 ? 
            (typeof answerRecord.field_1300 === 'string' ? JSON.parse(answerRecord.field_1300) : answerRecord.field_1300) : 
            {},
          responses_text: answerRecord?.field_2334 || '',
          staff_feedback: answerRecord?.field_1734 || null,
          feedback_read_by_student: answerRecord?.field_3648 === true || answerRecord?.field_3648 === 'Yes',
          staff_feedback_at: parseKnackDate(answerRecord?.field_3649),
          feedback_read_at: parseKnackDate(answerRecord?.field_3650),
          
          // Metadata
          year_group: progressRecord.field_2331 || answerRecord?.field_2331 || null,
          student_group: progressRecord.field_2332 || answerRecord?.field_2332 || null,
          knack_id: progressRecord.id
        };
        
        // Upsert to Supabase (handles duplicates)
        const { error } = await supabase
          .from('activity_responses')
          .upsert(responseData, {
            onConflict: 'student_email,activity_id,cycle_number'
          });
        
        if (error) {
          stats.errors.push({ 
            student: studentEmail, 
            activity: activityName, 
            error: error.message 
          });
        } else {
          stats.object126Migrated++;
          
          if (stats.object126Migrated % 50 === 0) {
            console.log(`   ✅ Migrated ${stats.object126Migrated}/${progress126.length} records...`);
          }
        }
        
        // Rate limiting
        if (stats.object126Processed % 10 === 0) {
          await new Promise(resolve => setTimeout(resolve, 100));
        }
        
      } catch (err) {
        stats.errors.push({ 
          record: progressRecord.id, 
          error: err.message 
        });
      }
    }
    
    console.log('\n✅ Object_126 migration complete!\n');
    
    // Step 8: Backfill Object_46 orphans (records not in Object_126)
    console.log('📖 Step 8: Backfilling Object_46 (Activity Answers) orphans...');
    console.log('='.repeat(60) + '\n');
    
    // TODO: This would check each Object_46 record and only import if not already in Supabase
    // Skipping for now as Object_126 has the current/active data
    console.log('⏭️  Skipping Object_46 backfill (can add later if needed)\n');
    
    // Print summary
    console.log('\n' + '='.repeat(60));
    console.log('📊 MIGRATION SUMMARY');
    console.log('='.repeat(60));
    console.log(`✅ Object_126 processed: ${stats.object126Processed}`);
    console.log(`✅ Successfully migrated: ${stats.object126Migrated}`);
    console.log(`⚠️  Skipped: ${stats.skipped.length}`);
    console.log(`❌ Errors: ${stats.errors.length}`);
    
    // Show skip reasons breakdown
    if (stats.skipped.length > 0) {
      console.log('\n📋 Skip Reasons:');
      const reasons = {};
      stats.skipped.forEach(s => {
        reasons[s.reason] = (reasons[s.reason] || 0) + 1;
      });
      Object.entries(reasons).forEach(([reason, count]) => {
        console.log(`  ${reason}: ${count}`);
      });
      
      console.log('\nFirst 5 skipped records:');
      stats.skipped.slice(0, 5).forEach((s, i) => {
        console.log(`  ${i+1}. ${s.reason}`);
        if (s.activityName) console.log(`     Activity: "${s.activityName}"`);
        if (s.field) console.log(`     Field value: "${s.field}"`);
      });
    }
    
    if (stats.errors.length > 0 && stats.errors.length <= 10) {
      console.log('\nFirst 10 errors:');
      stats.errors.slice(0, 10).forEach(err => {
        console.log(`  - ${err.student || err.record}: ${err.error}`);
      });
    }
    
    // Verify in Supabase
    console.log('\n🔍 Verifying migration...');
    const { count: totalCount } = await supabase
      .from('activity_responses')
      .select('*', { count: 'exact', head: true });
    
    console.log(`✅ Total activity_responses in Supabase: ${totalCount}`);
    
    // Check VESPA ACADEMY specifically
    const { count: vespaCount } = await supabase
      .from('activity_responses')
      .select('*', { count: 'exact', head: true })
      .like('student_email', '%@vespa.academy');
    
    console.log(`✅ VESPA ACADEMY responses: ${vespaCount}`);
    
    console.log('\n🎉 Migration complete!');
    
  } catch (error) {
    console.error('\n❌ Migration failed:', error);
    throw error;
  }
}

// ==========================================
// RUN MIGRATION
// ==========================================

migrate()
  .then(() => process.exit(0))
  .catch(err => {
    console.error('Fatal error:', err);
    process.exit(1);
  });

