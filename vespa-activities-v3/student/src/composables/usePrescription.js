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
  const initializePrescriptionFlow = (vespaScores, myActivities) => {
    // Check localStorage to see if user has already seen the modal
    const storageKey = 'vespa-welcome-modal-seen';
    const hasSeenBefore = localStorage.getItem(storageKey) === 'true';
    
    hasSeenWelcomeModal.value = hasSeenBefore;
    
    // Show welcome modal if:
    // 1. Has VESPA scores (completed questionnaire)
    // 2. Has NOT seen welcome modal before
    // 3. Has no activities assigned yet
    const hasScores = vespaScores && Object.keys(vespaScores).length > 0;
    const hasNoActivities = !myActivities || myActivities.length === 0;
    
    if (hasScores && !hasSeenBefore && hasNoActivities) {
      console.log('[usePrescription] 🎯 Showing welcome modal (first-time user with no activities)');
      showWelcomeModal.value = true;
    } else {
      console.log('[usePrescription] Skipping welcome modal:', {
        hasScores,
        hasSeenBefore,
        hasNoActivities
      });
    }
  };
  
  /**
   * User clicked "Continue with These"
   */
  const handleContinue = () => {
    // Mark as seen in localStorage
    localStorage.setItem('vespa-welcome-modal-seen', 'true');
    hasSeenWelcomeModal.value = true;
    showWelcomeModal.value = false;
    
    console.log('[usePrescription] User selected: Continue with prescribed activities');
  };
  
  /**
   * User clicked "Choose Your Own"
   */
  const handleChooseOwn = () => {
    // Mark as seen in localStorage
    localStorage.setItem('vespa-welcome-modal-seen', 'true');
    hasSeenWelcomeModal.value = true;
    
    // Close welcome modal, open problem selector
    showWelcomeModal.value = false;
    showProblemSelector.value = true;
    
    console.log('[usePrescription] User selected: Choose your own via problem selector');
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
  const resetWelcomeModal = () => {
    localStorage.removeItem('vespa-welcome-modal-seen');
    hasSeenWelcomeModal.value = false;
    console.log('[usePrescription] ✅ Welcome modal state reset');
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
    resetWelcomeModal
  };
}

export default usePrescription;

