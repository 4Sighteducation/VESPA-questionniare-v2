/**
 * useVESPAScores Composable
 * Fetches VESPA scores from Supabase
 */

import { ref } from 'vue';
import supabase from '../../shared/supabaseClient';

export function useVESPAScores(studentEmail) {
  // State
  const vespaScores = ref({
    vision: 5,
    effort: 5,
    systems: 5,
    practice: 5,
    attitude: 5,
    overall: 5
  });
  
  const level = ref('Level 2');
  const currentCycle = ref(1);
  const loading = ref(false);
  const error = ref(null);
  
  // Methods
  const fetchVESPAScores = async (cycle = 1) => {
    try {
      loading.value = true;
      error.value = null;
      
      console.log('[useVESPAScores] Fetching scores for:', studentEmail, 'cycle:', cycle);
      
      // Fetch scores via API endpoint (which handles vespa_students.latest_vespa_scores or vespa_scores)
      // The API endpoint is called when fetching recommended activities, so scores come from there
      // For now, we'll fetch from recommended activities endpoint to get scores
      const API_BASE_URL = import.meta.env.VITE_API_URL || 'https://vespa-dashboard-9a1f84ee5341.herokuapp.com';
      const response = await fetch(
        `${API_BASE_URL}/api/activities/recommended?email=${studentEmail}&cycle=${cycle}`
      );
      
      if (response.ok) {
        const data = await response.json();
        
        if (data.vespaScores) {
          const scores = data.vespaScores;
          vespaScores.value = {
            vision: scores.vision_score || scores.vision || 5,
            effort: scores.effort_score || scores.effort || 5,
            systems: scores.systems_score || scores.systems || 5,
            practice: scores.practice_score || scores.practice || 5,
            attitude: scores.attitude_score || scores.attitude || 5,
            overall: scores.overall_score || scores.overall || 5
          };
          
          level.value = data.level || scores.level || 'Level 2';
          currentCycle.value = data.cycle || scores.cycle_number || cycle;
          
          console.log('[useVESPAScores] ✅ Scores loaded:', vespaScores.value);
        } else {
          // Fallback to Knack if no scores
          await fetchFromKnack();
        }
      } else {
        // Fallback to Knack
        await fetchFromKnack();
      }
      
    } catch (err) {
      console.error('[useVESPAScores] Error fetching scores:', err);
      error.value = err.message;
      
      // Fallback to Knack
      await fetchFromKnack();
    } finally {
      loading.value = false;
    }
  };
  
  /**
   * Fallback: Fetch from Knack views (existing pattern)
   */
  const fetchFromKnack = async () => {
    try {
      console.log('[useVESPAScores] Fetching from Knack views...');
      
      // Check if we're in Knack environment
      if (typeof Knack === 'undefined') {
        throw new Error('Knack not available');
      }
      
      // Try view_3164 (VESPA Results view from current system)
      const viewData = Knack.views?.view_3164;
      if (viewData && viewData.model && viewData.model.data && viewData.model.data.length > 0) {
        const record = viewData.model.data[0];
        
        vespaScores.value = {
          vision: parseInt(record.field_147) || 5,
          effort: parseInt(record.field_148) || 5,
          systems: parseInt(record.field_149) || 5,
          practice: parseInt(record.field_150) || 5,
          attitude: parseInt(record.field_151) || 5,
          overall: parseInt(record.field_146) || 5
        };
        
        level.value = record.field_568 || 'Level 2';
        currentCycle.value = parseInt(record.field_146) || 1;
        
        console.log('[useVESPAScores] ✅ Scores loaded from Knack:', vespaScores.value);
        return;
      }
      
      // If still no data, use defaults
      console.warn('[useVESPAScores] No scores found, using defaults');
      
    } catch (err) {
      console.error('[useVESPAScores] Error fetching from Knack:', err);
      // Use default values (already set)
    }
  };
  
  return {
    vespaScores,
    level,
    currentCycle,
    loading,
    error,
    fetchVESPAScores
  };
}

export default useVESPAScores;


