/**
 * Populate Activity Thresholds from JSON to Supabase
 * 
 * Reads structured_activities_with_thresholds.json and updates
 * activities table with score_threshold_min and score_threshold_max
 */

const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const path = require('path');

// Supabase credentials
const SUPABASE_URL = 'https://qcdcdzfanrlvdcagmwmg.supabase.co';
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY || 'YOUR_SERVICE_KEY_HERE';

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

async function populateThresholds() {
  console.log('🎯 Starting threshold population...\n');
  
  try {
    // Read the JSON file
    const jsonPath = path.join(__dirname, '../../../vespa-activities-v2/shared/utils/structured_activities_with_thresholds.json');
    console.log('📖 Reading JSON from:', jsonPath);
    
    const jsonData = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));
    console.log(`✅ Loaded ${jsonData.length} activities from JSON\n`);
    
    let updated = 0;
    let notFound = 0;
    let errors = 0;
    
    for (const activity of jsonData) {
      try {
        const { name, thresholds } = activity;
        
        if (!thresholds || !thresholds.lower || !thresholds.upper) {
          console.log(`⚠️  Skipping "${name}" - no thresholds defined`);
          continue;
        }
        
        // Update in Supabase by name match
        const { data, error, count } = await supabase
          .from('activities')
          .update({
            score_threshold_min: thresholds.lower,
            score_threshold_max: thresholds.upper
          })
          .eq('name', name)
          .select('id, name');
        
        if (error) {
          console.error(`❌ Error updating "${name}":`, error.message);
          errors++;
        } else if (!data || data.length === 0) {
          console.log(`⚠️  Activity not found in Supabase: "${name}"`);
          notFound++;
        } else {
          console.log(`✅ Updated "${name}" → min: ${thresholds.lower}, max: ${thresholds.upper}`);
          updated++;
        }
        
      } catch (err) {
        console.error(`❌ Error processing activity:`, err.message);
        errors++;
      }
    }
    
    console.log('\n' + '='.repeat(60));
    console.log('📊 SUMMARY');
    console.log('='.repeat(60));
    console.log(`✅ Successfully updated: ${updated}`);
    console.log(`⚠️  Not found in Supabase: ${notFound}`);
    console.log(`❌ Errors: ${errors}`);
    console.log(`📝 Total processed: ${jsonData.length}`);
    console.log('='.repeat(60) + '\n');
    
    // Verify the updates
    console.log('🔍 Verifying updates...');
    const { data: sampleActivities } = await supabase
      .from('activities')
      .select('name, vespa_category, score_threshold_min, score_threshold_max')
      .not('score_threshold_min', 'is', null)
      .limit(5);
    
    console.log('\nSample updated activities:');
    sampleActivities?.forEach(a => {
      console.log(`  - ${a.name} (${a.vespa_category}): ${a.score_threshold_min}-${a.score_threshold_max}`);
    });
    
    // Count how many have thresholds now
    const { count: totalWithThresholds } = await supabase
      .from('activities')
      .select('*', { count: 'exact', head: true })
      .not('score_threshold_min', 'is', null);
    
    const { count: totalActivities } = await supabase
      .from('activities')
      .select('*', { count: 'exact', head: true });
    
    console.log(`\n✅ ${totalWithThresholds} out of ${totalActivities} activities now have thresholds!`);
    
  } catch (error) {
    console.error('❌ Fatal error:', error);
    process.exit(1);
  }
}

// Run it
populateThresholds()
  .then(() => {
    console.log('\n🎉 Threshold population complete!');
    process.exit(0);
  })
  .catch(err => {
    console.error('❌ Script failed:', err);
    process.exit(1);
  });

