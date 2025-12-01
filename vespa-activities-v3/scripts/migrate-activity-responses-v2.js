/**
 * ACTIVITY RESPONSES MIGRATION V2 - Fix Empty Responses
 * ========================================================
 * 
 * Purpose: Backfill empty responses JSONB in activity_responses table
 * 
 * Issue: ALL activity_responses have responses: {} (empty)
 *        Migration v1 didn't properly copy Knack field_1300
 * 
 * Solution: 
 * 1. Fetch ALL Object_46 (Activity Answers) from Knack
 * 2. For each activity_response in Supabase:
 *    - Match by student_email + activity_name (NOT activity_id!)
 *    - Update responses from Knack field_1300
 *    - Update responses_text from Knack field_2334
 * 
 * Date: December 1, 2025
 */

const { createClient } = require('@supabase/supabase-js');

// ==========================================
// CONFIGURATION
// ==========================================

const SUPABASE_URL = 'https://qcdcdzfanrlvdcagmwmg.supabase.co';
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY;

const KNACK_APP_ID = '5ee90912c38ae7001510c1a9';
const KNACK_API_KEY = '8f733aa5-dd35-4464-8348-64824d1f5f0d';

if (!SUPABASE_SERVICE_KEY) {
  console.error('❌ SUPABASE_SERVICE_KEY environment variable required!');
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

// ==========================================
// KNACK API HELPER
// ==========================================

async function knackAPI(endpoint, page = 1) {
  const url = `https://api.knack.com/v1/${endpoint}${endpoint.includes('?') ? '&' : '?'}page=${page}&rows_per_page=1000`;
  // NOTE: NOT using format=raw - we need both formatted and _raw fields
  
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

async function getAllRecords(objectId, maxPages = 30) {
  console.log(`📥 Fetching all records from ${objectId}...`);
  let allRecords = [];
  let page = 1;
  let hasMore = true;
  
  while (hasMore && page <= maxPages) {
    const data = await knackAPI(`objects/${objectId}/records`, page);
    allRecords = allRecords.concat(data.records);
    
    console.log(`   Page ${page}: ${data.records.length} records (total: ${allRecords.length})`);
    
    hasMore = data.records.length === 1000;
    page++;
    
    await new Promise(resolve => setTimeout(resolve, 500));
  }
  
  console.log(`✅ Loaded ${allRecords.length} total records from ${objectId}\n`);
  return allRecords;
}

// ==========================================
// EMAIL CLEANER
// ==========================================

function cleanEmail(emailField) {
  if (!emailField) return null;
  
  // String with HTML
  if (typeof emailField === 'string') {
    // Remove HTML tags
    const clean = emailField.replace(/<[^>]*>/g, '').trim().toLowerCase();
    return clean || null;
  }
  
  // Array format
  if (Array.isArray(emailField) && emailField.length > 0) {
    const first = emailField[0];
    if (first.identifier) return cleanEmail(first.identifier);
    if (first.email) return cleanEmail(first.email);
    if (typeof first === 'string') return cleanEmail(first);
  }
  
  // Object format
  if (typeof emailField === 'object') {
    if (emailField.identifier) return cleanEmail(emailField.identifier);
    if (emailField.email) return cleanEmail(emailField.email);
  }
  
  return null;
}

function parseKnackDate(dateField) {
  /**
   * Parse Knack date correctly handling UK format (DD/MM/YYYY)
   * Knack returns: {date: "11/12/2025 14:30"} or {date: "11/12/2025"}
   */
  if (!dateField) return null;
  
  try {
    // Handle Knack date object format
    if (dateField.date) {
      const dateStr = dateField.date;
      
      // UK format: DD/MM/YYYY or DD/MM/YYYY HH:MM
      const ukDateMatch = dateStr.match(/^(\d{1,2})\/(\d{1,2})\/(\d{4})(?: (\d{1,2}):(\d{1,2}))?$/);
      
      if (ukDateMatch) {
        const [, day, month, year, hour, minute] = ukDateMatch;
        
        // Create ISO date string: YYYY-MM-DD
        const isoDate = `${year}-${month.padStart(2, '0')}-${day.padStart(2, '0')}`;
        
        if (hour && minute) {
          // Include time
          const isoTime = `${hour.padStart(2, '0')}:${minute.padStart(2, '0')}:00`;
          return `${isoDate}T${isoTime}Z`;
        } else {
          // Date only - use midnight UTC
          return `${isoDate}T00:00:00Z`;
        }
      }
      
      // Fallback: try parsing as-is (risky but better than nothing)
      return new Date(dateStr).toISOString();
    }
    
    // Handle ISO string directly
    if (typeof dateField === 'string') {
      // Check if UK format
      const ukDateMatch = dateField.match(/^(\d{1,2})\/(\d{1,2})\/(\d{4})/);
      if (ukDateMatch) {
        const [, day, month, year] = ukDateMatch;
        const isoDate = `${year}-${month.padStart(2, '0')}-${day.padStart(2, '0')}T00:00:00Z`;
        return isoDate;
      }
      
      return new Date(dateField).toISOString();
    }
    
    return null;
  } catch (e) {
    console.warn(`Failed to parse date: ${JSON.stringify(dateField)}`);
    return null;
  }
}

// ==========================================
// MAIN MIGRATION
// ==========================================

async function migrate(dryRun = true) {
  console.log('=' .repeat(80));
  console.log(`${dryRun ? 'DRY RUN - ' : ''}ACTIVITY RESPONSES MIGRATION V2`);
  console.log('=' .repeat(80));
  
  const stats = {
    supabaseResponses: 0,
    knackAnswers: 0,
    matched: 0,
    updated: 0,
    alreadyHaveData: 0,
    notMatched: 0,
    errors: []
  };
  
  try {
    // Step 1: Load all Knack Object_46 (Activity Answers)
    console.log('\n📖 Step 1: Loading Knack Object_46 (Activity Answers)...');
    const knackAnswers = await getAllRecords('object_46', 30);
    stats.knackAnswers = knackAnswers.length;
    
    // Build lookup map: email_activityname -> answer data
    const answerMap = {};
    const activityNameVariants = new Set();
    
    for (const answer of knackAnswers) {
      const studentEmail = cleanEmail(answer.field_1301_raw?.email || answer.field_1301);
      
      // Extract activity name from _raw field (array format)
      let activityName = '';
      if (answer.field_1302_raw && Array.isArray(answer.field_1302_raw) && answer.field_1302_raw.length > 0) {
        activityName = answer.field_1302_raw[0].identifier || answer.field_1302_raw[0];
      } else if (typeof answer.field_1302 === 'string') {
        activityName = answer.field_1302.trim();
      }
      
      if (studentEmail && activityName) {
        // Store with various key formats to handle matching issues
        const key1 = `${studentEmail}_${activityName.toLowerCase()}`;
        const key2 = `${studentEmail}_${activityName}`;
        
        const answerData = {
          responses: answer.field_1300 || {},
          responses_text: answer.field_2334 || '',
          staff_feedback: answer.field_1734 || null,
          feedback_read_by_student: answer.field_3648 === true || answer.field_3648 === 'Yes',
          staff_feedback_at: parseKnackDate(answer.field_3649),
          feedback_read_at: parseKnackDate(answer.field_3650),
          knack_object_46_id: answer.id
        };
        
        answerMap[key1] = answerData;
        answerMap[key2] = answerData;
        activityNameVariants.add(activityName);
      }
    }
    
    console.log(`✅ Indexed ${Object.keys(answerMap).length} answer records\n`);
    
    // Step 2: Load all Supabase activity_responses
    console.log('📖 Step 2: Loading Supabase activity_responses...');
    
    let offset = 0;
    const limit = 1000;
    let hasMore = true;
    
    while (hasMore) {
      const { data: responses, error } = await supabase
        .from('activity_responses')
        .select(`
          id,
          student_email,
          activity_id,
          responses,
          responses_text,
          activities (
            name
          )
        `)
        .range(offset, offset + limit - 1);
      
      if (error) throw error;
      
      if (!responses || responses.length === 0) {
        hasMore = false;
        break;
      }
      
      stats.supabaseResponses += responses.length;
      console.log(`   Loaded ${offset + responses.length} responses...`);
      
      // Process batch
      for (const response of responses) {
        const studentEmail = cleanEmail(response.student_email);
        const activityName = response.activities?.name || '';
        
        if (!studentEmail || !activityName) {
          continue;
        }
        
        // Check if already has data
        const currentResponses = response.responses || {};
        const hasData = Object.keys(currentResponses).length > 0;
        
        if (hasData) {
          stats.alreadyHaveData++;
          continue;
        }
        
        // Try to find matching Knack answer
        const key1 = `${studentEmail}_${activityName.toLowerCase()}`;
        const key2 = `${studentEmail}_${activityName}`;
        
        const knackAnswer = answerMap[key1] || answerMap[key2];
        
        if (!knackAnswer) {
          stats.notMatched++;
          
          if (stats.notMatched <= 10) {
            console.log(`⚠️  No match: ${studentEmail} → ${activityName}`);
          }
          
          continue;
        }
        
        stats.matched++;
        
        // Parse responses if string
        let responsesData = knackAnswer.responses;
        if (typeof responsesData === 'string') {
          try {
            responsesData = JSON.parse(responsesData);
          } catch (e) {
            // Skip invalid JSON silently (many records have just "." or invalid data)
            continue;
          }
        }
        
        // Check if responses actually has data
        if (!responsesData || Object.keys(responsesData).length === 0) {
          continue; // Skip empty responses in Knack too
        }
        
        const updateData = {
          responses: responsesData,
          responses_text: knackAnswer.responses_text,
          staff_feedback: knackAnswer.staff_feedback,
          feedback_read_by_student: knackAnswer.feedback_read_by_student,
          staff_feedback_at: knackAnswer.staff_feedback_at,
          feedback_read_at: knackAnswer.feedback_read_at
        };
        
        if (dryRun) {
          if (stats.updated < 10) {
            console.log(`✅ [DRY RUN] Would update: ${studentEmail} → ${activityName}`);
            console.log(`   Response keys: ${Object.keys(responsesData).join(', ')}`);
          }
          stats.updated++;
        } else {
          // Apply update
          const { error: updateError } = await supabase
            .from('activity_responses')
            .update(updateData)
            .eq('id', response.id);
          
          if (updateError) {
            stats.errors.push({
              email: studentEmail,
              activity: activityName,
              error: updateError.message
            });
            
            if (stats.errors.length <= 10) {
              console.error(`❌ Update failed: ${studentEmail} → ${activityName}: ${updateError.message}`);
            }
          } else {
            stats.updated++;
            
            if (stats.updated % 50 === 0 || stats.updated <= 10) {
              console.log(`✅ Updated ${stats.updated} responses...`);
            }
          }
        }
      }
      
      offset += limit;
      
      if (responses.length < limit) {
        hasMore = false;
      }
    }
    
    // Print summary
    console.log('\n' + '='.repeat(80));
    console.log(`${dryRun ? 'DRY RUN ' : ''}SUMMARY`);
    console.log('='.repeat(80));
    console.log(`Knack Object_46 answers:        ${stats.knackAnswers}`);
    console.log(`Supabase activity_responses:    ${stats.supabaseResponses}`);
    console.log(`Already have data:              ${stats.alreadyHaveData}`);
    console.log(`Matched to Knack:               ${stats.matched}`);
    console.log(`${dryRun ? 'Would update' : 'Updated'}:                    ${stats.updated}`);
    console.log(`Not matched:                    ${stats.notMatched}`);
    console.log(`Errors:                         ${stats.errors.length}`);
    
    if (stats.errors.length > 0 && stats.errors.length <= 10) {
      console.log('\nErrors:');
      stats.errors.forEach(err => {
        console.log(`  - ${err.email} → ${err.activity}: ${err.error}`);
      });
    }
    
    console.log('='.repeat(80));
    
    if (dryRun) {
      console.log('\n✅ DRY RUN COMPLETE - No changes made');
      console.log('Run with --live flag to apply changes');
    } else {
      console.log('\n✅ MIGRATION COMPLETE');
    }
    
  } catch (error) {
    console.error('\n❌ Migration failed:', error);
    throw error;
  }
}

// ==========================================
// RUN MIGRATION
// ==========================================

const dryRun = !process.argv.includes('--live');

if (dryRun) {
  console.log('🔍 DRY RUN MODE - No changes will be made');
  console.log('Use --live flag to apply changes\n');
}

migrate(dryRun)
  .then(() => process.exit(0))
  .catch(err => {
    console.error('Fatal error:', err);
    process.exit(1);
  });

