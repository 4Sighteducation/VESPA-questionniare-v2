/**
 * Populate Problem Mappings for Activities
 * 
 * Reads vespa-problem-activity-mappings1a.json and updates
 * activities table with problem_mappings array
 */

const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const path = require('path');

const SUPABASE_URL = 'https://qcdcdzfanrlvdcagmwmg.supabase.co';
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY;

if (!SUPABASE_SERVICE_KEY) {
  console.error('❌ SUPABASE_SERVICE_KEY required!');
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

async function populateProblemMappings() {
  console.log('🎯 Populating problem mappings...\n');
  
  try {
    // Read the problem mappings JSON
    const jsonPath = path.join(__dirname, '../../../vespa-activities-v2/shared/vespa-problem-activity-mappings1a.json');
    const problemData = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));
    const problemMappings = problemData.problemMappings;
    
    console.log('📖 Loaded problem mappings for categories:', Object.keys(problemMappings));
    
    // Invert the mapping: activity name → list of problems
    const activityToProblems = {};
    
    Object.entries(problemMappings).forEach(([category, problems]) => {
      problems.forEach(problem => {
        // For each recommended activity, add this problem
        (problem.recommendedActivities || []).forEach(activityName => {
          if (!activityToProblems[activityName]) {
            activityToProblems[activityName] = [];
          }
          activityToProblems[activityName].push({
            id: problem.id,
            text: problem.text,
            category: category
          });
        });
      });
    });
    
    console.log(`✅ Mapped ${Object.keys(activityToProblems).length} activities to problems\n`);
    
    // Update each activity in Supabase
    let updated = 0;
    let notFound = 0;
    
    for (const [activityName, problems] of Object.entries(activityToProblems)) {
      // Create array of problem IDs for the database
      const problemIds = problems.map(p => p.id);
      
      const { data, error } = await supabase
        .from('activities')
        .update({ problem_mappings: problemIds })
        .eq('name', activityName)
        .select('id, name');
      
      if (error) {
        console.error(`❌ Error updating "${activityName}":`, error.message);
      } else if (!data || data.length === 0) {
        console.log(`⚠️  Activity not found: "${activityName}"`);
        notFound++;
      } else {
        console.log(`✅ "${activityName}" → ${problemIds.length} problems`);
        updated++;
      }
    }
    
    console.log('\n' + '='.repeat(60));
    console.log('📊 SUMMARY');
    console.log('='.repeat(60));
    console.log(`✅ Successfully updated: ${updated}`);
    console.log(`⚠️  Not found: ${notFound}`);
    console.log('='.repeat(60));
    
    // Verify
    const { data: sample } = await supabase
      .from('activities')
      .select('name, problem_mappings')
      .not('problem_mappings', 'is', null)
      .limit(5);
    
    console.log('\nSample activities with problem mappings:');
    sample?.forEach(a => {
      console.log(`  - ${a.name}: ${a.problem_mappings?.length || 0} problems`);
    });
    
    const { count } = await supabase
      .from('activities')
      .select('*', { count: 'exact', head: true })
      .not('problem_mappings', 'is', null);
    
    console.log(`\n✅ ${count} activities now have problem mappings!`);
    
  } catch (error) {
    console.error('❌ Fatal error:', error);
    process.exit(1);
  }
}

populateProblemMappings()
  .then(() => {
    console.log('\n🎉 Problem mapping population complete!');
    process.exit(0);
  })
  .catch(err => {
    console.error('❌ Script failed:', err);
    process.exit(1);
  });



