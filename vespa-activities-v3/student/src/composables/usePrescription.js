/**
 * usePrescription Composable
 * Manages the initial prescription flow, motivational popups, and "Continue OR Choose" logic
 * 
 * UX Flow:
 * - First-time per cycle: Show welcome modal (tracked in Supabase)
 * - Returning users: Show motivational popup with "Add more activities" option
 */

import { ref, computed } from 'vue';
import { API_BASE_URL } from '../../shared/constants';

export function usePrescription() {
  // State
  const hasSeenWelcomeModal = ref(false);
  const showWelcomeModal = ref(false);
  const showMotivationalPopup = ref(false);
  const showProblemSelector = ref(false);
  const selectedProblem = ref(null);
  const selectedProblemActivities = ref([]);
  const isCheckingSupabase = ref(false);
  
  /**
   * Check if user should see the welcome modal
   * Show if: (1) Has VESPA scores, (2) Has NOT seen modal before, (3) Has no activities assigned
   */
  const shouldShowWelcome = computed(() => {
    return !hasSeenWelcomeModal.value;
  });
  
  /**
   * Initialize the prescription flow (checks Supabase, not localStorage)
   * 
   * Logic:
   * 1. First-time per cycle (no activities + not seen) → Welcome modal
   * 2. Returning user (has activities) → Motivational popup
   */
  const initializePrescriptionFlow = async (vespaScores, myActivities, currentCycle = 1, studentEmail) => {
    try {
      isCheckingSupabase.value = true;
      
      console.log(`[usePrescription] Initializing flow for Cycle ${currentCycle}`);
      
      const hasScores = vespaScores && Object.keys(vespaScores).length > 0;
      const hasNoActivities = !myActivities || myActivities.length === 0;
      
      // Check via API (bypasses RLS)
      try {
        const response = await fetch(
          `${API_BASE_URL}/api/students/welcome-status?email=${encodeURIComponent(studentEmail)}&cycle=${currentCycle}`
        );
        
        if (response.ok) {
          const data = await response.json();
          hasSeenWelcomeModal.value = data.has_seen || false;
          console.log(`[usePrescription] API check Cycle ${currentCycle}: has_seen =`, hasSeenWelcomeModal.value);
        } else {
          console.warn('[usePrescription] API check failed, using localStorage fallback');
          const storageKey = `vespa-welcome-modal-seen-cycle-${currentCycle}`;
          hasSeenWelcomeModal.value = localStorage.getItem(storageKey) === 'true';
        }
      } catch (apiError) {
        console.warn('[usePrescription] API error, using localStorage fallback:', apiError);
        const storageKey = `vespa-welcome-modal-seen-cycle-${currentCycle}`;
        hasSeenWelcomeModal.value = localStorage.getItem(storageKey) === 'true';
      }
      
      // Decision logic
      if (hasScores && !hasSeenWelcomeModal.value && hasNoActivities) {
        // First-time per cycle: Show welcome modal
        console.log(`[usePrescription] 🎯 Showing WELCOME modal for Cycle ${currentCycle} (first-time or new cycle)`);
        showWelcomeModal.value = true;
        showMotivationalPopup.value = false;
      } else if (hasScores && hasSeenWelcomeModal.value && !hasNoActivities) {
        // Returning user with activities: Show motivational popup
        console.log(`[usePrescription] 💪 Showing MOTIVATIONAL popup for Cycle ${currentCycle} (returning user)`);
        showWelcomeModal.value = false;
        showMotivationalPopup.value = true;
      } else {
        // Edge cases: No scores, or seen but no activities (weird state)
        console.log('[usePrescription] Skipping both modals:', {
          cycle: currentCycle,
          hasScores,
          hasSeenBefore: hasSeenWelcomeModal.value,
          hasNoActivities
        });
        showWelcomeModal.value = false;
        showMotivationalPopup.value = false;
      }
      
    } catch (err) {
      console.error('[usePrescription] Error in initializePrescriptionFlow:', err);
      // Don't show any modal if error
      showWelcomeModal.value = false;
      showMotivationalPopup.value = false;
    } finally {
      isCheckingSupabase.value = false;
    }
  };
  
  /**
   * User clicked "Continue with These"
   * Saves to Supabase so it syncs across devices
   */
  const handleContinue = async (currentCycle = 1, studentEmail) => {
    try {
      // Mark as seen via API (cross-device sync, bypasses RLS)
      const response = await fetch(`${API_BASE_URL}/api/students/welcome-seen`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email: studentEmail,
          cycle: currentCycle
        })
      });
      
      if (response.ok) {
        console.log(`[usePrescription] ✅ Saved to Supabase via API: Cycle ${currentCycle} = seen`);
      } else {
        console.warn('[usePrescription] API save failed, using localStorage fallback');
        localStorage.setItem(`vespa-welcome-modal-seen-cycle-${currentCycle}`, 'true');
      }
      
      hasSeenWelcomeModal.value = true;
      showWelcomeModal.value = false;
      
      console.log(`[usePrescription] User selected: Continue with prescribed activities (Cycle ${currentCycle})`);
    } catch (err) {
      console.error('[usePrescription] Error in handleContinue:', err);
      // Continue anyway, use localStorage fallback
      localStorage.setItem(`vespa-welcome-modal-seen-cycle-${currentCycle}`, 'true');
      hasSeenWelcomeModal.value = true;
      showWelcomeModal.value = false;
    }
  };
  
  /**
   * User clicked "Choose Your Own"
   * Saves to Supabase so it syncs across devices
   */
  const handleChooseOwn = async (currentCycle = 1, studentEmail) => {
    try {
      // Mark as seen via API (cross-device sync, bypasses RLS)
      const response = await fetch(`${API_BASE_URL}/api/students/welcome-seen`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email: studentEmail,
          cycle: currentCycle
        })
      });
      
      if (response.ok) {
        console.log(`[usePrescription] ✅ Saved to Supabase via API: Cycle ${currentCycle} = seen`);
      } else {
        console.warn('[usePrescription] API save failed, using localStorage fallback');
        localStorage.setItem(`vespa-welcome-modal-seen-cycle-${currentCycle}`, 'true');
      }
      
      hasSeenWelcomeModal.value = true;
      
      // Close welcome modal, open problem selector
      showWelcomeModal.value = false;
      showProblemSelector.value = true;
      
      console.log(`[usePrescription] User selected: Choose your own via problem selector (Cycle ${currentCycle})`);
    } catch (err) {
      console.error('[usePrescription] Error in handleChooseOwn:', err);
      localStorage.setItem(`vespa-welcome-modal-seen-cycle-${currentCycle}`, 'true');
      hasSeenWelcomeModal.value = true;
      showWelcomeModal.value = false;
      showProblemSelector.value = true;
    }
  };
  
  /**
   * User dismissed motivational popup
   */
  const handleMotivationalDismiss = () => {
    showMotivationalPopup.value = false;
    console.log('[usePrescription] Motivational popup dismissed');
  };
  
  /**
   * User clicked "Add More Activities" from motivational popup
   */
  const handleMotivationalAddMore = () => {
    console.log('[usePrescription] 🎯 handleMotivationalAddMore called');
    console.log('[usePrescription] Before:', { 
      showMotivationalPopup: showMotivationalPopup.value, 
      showProblemSelector: showProblemSelector.value 
    });
    
    showMotivationalPopup.value = false;
    showProblemSelector.value = true;
    
    console.log('[usePrescription] After:', { 
      showMotivationalPopup: showMotivationalPopup.value, 
      showProblemSelector: showProblemSelector.value 
    });
    console.log('[usePrescription] ✅ Problem selector should now show');
  };
  
  /**
   * User selected a problem from problem selector
   */
  const handleProblemSelected = ({ problem, activities }) => {
    console.log('[usePrescription] Problem selected:', problem.text, 'Activities:', activities.length);
    
    selectedProblem.value = problem;
    selectedProblemActivities.value = activities;
    
    // Don't close problem selector yet - show activities modal
  };
  
  /**
   * Close problem selector
   */
  const closeProblemSelector = () => {
    showProblemSelector.value = false;
    selectedProblem.value = null;
    selectedProblemActivities.value = [];
  };
  
  /**
   * Reset the welcome modal state (for testing)
   */
  const resetWelcomeModal = (currentCycle = 1) => {
    const storageKey = `vespa-welcome-modal-seen-cycle-${currentCycle}`;
    localStorage.removeItem(storageKey);
    hasSeenWelcomeModal.value = false;
    console.log(`[usePrescription] ✅ Welcome modal state reset for Cycle ${currentCycle}`);
  };
  
  /**
   * Reset ALL cycles (for testing across cycles)
   */
  const resetAllCycles = () => {
    for (let i = 1; i <= 3; i++) {
      localStorage.removeItem(`vespa-welcome-modal-seen-cycle-${i}`);
    }
    hasSeenWelcomeModal.value = false;
    console.log('[usePrescription] ✅ All cycle welcome states reset');
  };
  
  return {
    // State
    showWelcomeModal,
    showMotivationalPopup,
    showProblemSelector,
    hasSeenWelcomeModal,
    selectedProblem,
    selectedProblemActivities,
    isCheckingSupabase,
    
    // Computed
    shouldShowWelcome,
    
    // Methods
    initializePrescriptionFlow,
    handleContinue,
    handleChooseOwn,
    handleMotivationalDismiss,
    handleMotivationalAddMore,
    handleProblemSelected,
    closeProblemSelector,
    resetWelcomeModal,
    resetAllCycles
  };
}

export default usePrescription;

