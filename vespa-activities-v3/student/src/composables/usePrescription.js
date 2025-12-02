/**
 * usePrescription Composable
 * Manages the initial prescription flow and "Continue OR Choose" logic
 */

import { ref, computed } from 'vue';

export function usePrescription() {
  // State
  const hasSeenWelcomeModal = ref(false);
  const showWelcomeModal = ref(false);
  const showProblemSelector = ref(false);
  const selectedProblem = ref(null);
  const selectedProblemActivities = ref([]);
  
  /**
   * Check if user should see the welcome modal
   * Show if: (1) Has VESPA scores, (2) Has NOT seen modal before, (3) Has no activities assigned
   */
  const shouldShowWelcome = computed(() => {
    return !hasSeenWelcomeModal.value;
  });
  
  /**
   * Initialize the prescription flow
   */
  const initializePrescriptionFlow = (vespaScores, myActivities, currentCycle = 1) => {
    // Check localStorage to see if user has already seen the modal FOR THIS CYCLE
    const storageKey = `vespa-welcome-modal-seen-cycle-${currentCycle}`;
    const hasSeenBefore = localStorage.getItem(storageKey) === 'true';
    
    hasSeenWelcomeModal.value = hasSeenBefore;
    
    // Show welcome modal if:
    // 1. Has VESPA scores (completed questionnaire)
    // 2. Has NOT seen welcome modal FOR THIS CYCLE
    // 3. Has no activities assigned FOR THIS CYCLE
    const hasScores = vespaScores && Object.keys(vespaScores).length > 0;
    const hasNoActivities = !myActivities || myActivities.length === 0;
    
    if (hasScores && !hasSeenBefore && hasNoActivities) {
      console.log(`[usePrescription] 🎯 Showing welcome modal for Cycle ${currentCycle} (first-time or new cycle)`);
      showWelcomeModal.value = true;
    } else {
      console.log('[usePrescription] Skipping welcome modal:', {
        cycle: currentCycle,
        hasScores,
        hasSeenBefore,
        hasNoActivities
      });
    }
  };
  
  /**
   * User clicked "Continue with These"
   */
  const handleContinue = (currentCycle = 1) => {
    // Mark as seen in localStorage FOR THIS CYCLE
    const storageKey = `vespa-welcome-modal-seen-cycle-${currentCycle}`;
    localStorage.setItem(storageKey, 'true');
    hasSeenWelcomeModal.value = true;
    showWelcomeModal.value = false;
    
    console.log(`[usePrescription] User selected: Continue with prescribed activities (Cycle ${currentCycle})`);
  };
  
  /**
   * User clicked "Choose Your Own"
   */
  const handleChooseOwn = (currentCycle = 1) => {
    // Mark as seen in localStorage FOR THIS CYCLE
    const storageKey = `vespa-welcome-modal-seen-cycle-${currentCycle}`;
    localStorage.setItem(storageKey, 'true');
    hasSeenWelcomeModal.value = true;
    
    // Close welcome modal, open problem selector
    showWelcomeModal.value = false;
    showProblemSelector.value = true;
    
    console.log(`[usePrescription] User selected: Choose your own via problem selector (Cycle ${currentCycle})`);
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
    showProblemSelector,
    hasSeenWelcomeModal,
    selectedProblem,
    selectedProblemActivities,
    
    // Computed
    shouldShowWelcome,
    
    // Methods
    initializePrescriptionFlow,
    handleContinue,
    handleChooseOwn,
    handleProblemSelected,
    closeProblemSelector,
    resetWelcomeModal,
    resetAllCycles
  };
}

export default usePrescription;

