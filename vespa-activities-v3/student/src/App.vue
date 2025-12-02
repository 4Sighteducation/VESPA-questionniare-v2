<template>
  <div v-if="loading" class="loading-container">
    <div class="spinner"></div>
    <p>Loading VESPA Activities...</p>
  </div>
  
  <div v-else-if="error" class="error-container">
    <h2>⚠️ Unable to Load Activities</h2>
    <p>{{ error }}</p>
    <button @click="retry" class="retry-btn">Retry</button>
  </div>
  
  <div v-else class="vespa-activities-app">
    <!-- Notification Banner (Top) -->
    <NotificationBanner
      :notifications="recentUnreadNotifications"
      @dismiss="handleDismissNotification"
      @dismiss-all="handleDismissAllNotifications"
    />
    
    <!-- Notification Bell -->
    <div class="notification-bell" v-if="unreadNotifications > 0">
      <button @click="toggleNotifications" class="bell-button">
        🔔 <span class="badge">{{ unreadNotifications }}</span>
      </button>
    </div>
    
    <!-- Main Dashboard -->
    <ActivityDashboard
      :student-email="studentEmail"
      :vespa-scores="vespaScores"
      :recommended-activities="recommendedActivities"
      :my-activities="myActivities"
      :achievements="achievements"
      :total-points="totalPoints"
      :current-streak="currentStreak"
      :show-welcome-modal="showWelcomeModal"
      :show-problem-selector="showProblemSelector"
      @start-activity="openActivityModal"
      @add-activity="addActivityToDashboard"
      @remove-activity="removeActivityFromDashboard"
      @show-problem-selector="handleShowProblemSelector"
      @show-achievements="showAchievements = true"
      @improve-category="handleImproveCategory"
    />
    
    <!-- Welcome Modal (Initial Prescription Flow - First Time Per Cycle) -->
    <WelcomeModal
      v-if="showWelcomeModal"
      :vespa-scores="vespaScores"
      :prescribed-activities="recommendedActivities"
      @continue="handleWelcomeContinue"
      @choose-own="handleWelcomeChooseOwn"
      @close="showWelcomeModal = false"
    />
    
    <!-- Motivational Popup (Returning Users - Every Login) -->
    <MotivationalPopup
      v-if="showMotivationalPopup"
      :stats="motivationalStats"
      @dismiss="handleMotivationalDismiss"
      @add-more="handleMotivationalAddMoreClick"
    />
    
    <!-- Problem Selector Modal -->
    <ProblemSelector
      v-if="showProblemSelector"
      :pre-selected-category="selectedCategory"
      @problem-selected="handleProblemSelection"
      @close="closeProblemSelector"
    />
    
    <!-- Selected Activities Modal (after problem selection) -->
    <SelectedActivitiesModal
      v-if="selectedProblem && selectedProblemActivities.length > 0"
      :problem="selectedProblem"
      :activities="selectedProblemActivities"
      :assigned-activity-ids="assignedActivityIds"
      :completed-activity-ids="completedActivityIds"
      @add-activities="handleAddSelectedActivities"
      @close="closeProblemSelector"
    />
    
    <!-- Activity Modal (full-screen) -->
    <ActivityModal
      v-if="activeActivity"
      :activity="activeActivity"
      :questions="activityQuestions"
      :existing-responses="existingResponses"
      @close="closeActivityModal"
      @save="saveActivityProgress"
      @complete="completeActivity"
    />
    
    <!-- Achievements Panel -->
    <AchievementPanel
      v-if="showAchievements"
      :achievements="achievements"
      :total-points="totalPoints"
      @close="showAchievements = false"
    />
    
    <!-- Category Activities Modal (for Improve button) -->
    <CategoryActivitiesModal
      v-if="showCategoryModal && selectedCategoryForModal"
      :category="selectedCategoryForModal"
      :completed-activity-ids="completedActivityIds"
      :assigned-activity-ids="assignedActivityIds"
      @add-activities="handleAddCategoryActivities"
      @close="closeCategoryModal"
    />
  </div>
</template>

<script setup>
import { ref, onMounted, computed } from 'vue';
import ActivityDashboard from './components/ActivityDashboard.vue';
import ActivityModal from './components/ActivityModal.vue';
import AchievementPanel from './components/AchievementPanel.vue';
import WelcomeModal from './components/WelcomeModal.vue';
import MotivationalPopup from './components/MotivationalPopup.vue';
import ProblemSelector from './components/ProblemSelector.vue';
import SelectedActivitiesModal from './components/SelectedActivitiesModal.vue';
import NotificationBanner from './components/NotificationBanner.vue';
import CategoryActivitiesModal from './components/CategoryActivitiesModal.vue';
import { useActivities } from './composables/useActivities';
import { useVESPAScores } from './composables/useVESPAScores';
import { useNotifications } from './composables/useNotifications';
import { useAchievements } from './composables/useAchievements';
import { usePrescription } from './composables/usePrescription';
import supabase from '../shared/supabaseClient';

// Props from KnackAppLoader config
const props = defineProps({
  config: {
    type: Object,
    required: true
  }
});

// Get user from Knack
const studentEmail = computed(() => {
  if (typeof Knack !== 'undefined' && Knack.getUserAttributes) {
    return Knack.getUserAttributes().email;
  }
  return null;
});

// State
const loading = ref(true);
const currentCycle = ref(1); // Will be fetched from Supabase
const error = ref(null);
const activeActivity = ref(null);
const activityQuestions = ref([]);
const existingResponses = ref({});
const showAchievements = ref(false);
const selectedCategory = ref(null); // For problem selector pre-selection
const showCategoryModal = ref(false); // For Improve button -> category activities
const selectedCategoryForModal = ref(null); // The category being improved

// Composables
const {
  recommendedActivities,
  myActivities,
  fetchRecommendedActivities,
  fetchMyActivities,
  addActivity,
  removeActivity
} = useActivities(studentEmail.value);

const { vespaScores, fetchVESPAScores } = useVESPAScores(studentEmail.value);

const { 
  notifications, 
  unreadNotifications, 
  sortedNotifications,
  fetchNotifications,
  markRead,
  markAllRead,
  dismissNotification,
  toggleNotifications
} = useNotifications(studentEmail.value);

// Recent unread notifications for the banner (max 3)
const recentUnreadNotifications = computed(() => {
  return sortedNotifications.value
    .filter(n => !n.is_read && !n.is_dismissed)
    .slice(0, 3);
});

const {
  achievements,
  totalPoints,
  totalActivitiesCompleted,
  currentStreak,
  streakDisplay,
  fetchAchievements,
  checkNewAchievements
} = useAchievements(studentEmail.value);

// Prescription Flow
const {
  showWelcomeModal,
  showMotivationalPopup,
  showProblemSelector,
  selectedProblem,
  selectedProblemActivities,
  initializePrescriptionFlow,
  handleContinue,
  handleChooseOwn,
  handleMotivationalDismiss,
  handleMotivationalAddMore,
  handleProblemSelected,
  closeProblemSelector
} = usePrescription();

// Stats for motivational popup
const motivationalStats = computed(() => ({
  completed: myActivities.value.filter(a => a.status === 'completed').length,
  inProgress: myActivities.value.filter(a => a.status === 'in_progress').length,
  points: totalPoints.value
}));

// Methods
const initialize = async () => {
  try {
    loading.value = true;
    error.value = null;
    
    if (!studentEmail.value) {
      throw new Error('Student email not found. Please ensure you are logged in.');
    }
    
    console.log('[VESPA Activities] Initializing for:', studentEmail.value);
    
    // FIRST: Get current cycle from API (which uses RPC to bypass RLS)
    try {
      const API_BASE_URL = import.meta.env.VITE_API_URL || 'https://vespa-dashboard-9a1f84ee5341.herokuapp.com';
      const response = await fetch(
        `${API_BASE_URL}/api/activities/recommended?email=${encodeURIComponent(studentEmail.value)}&cycle=1`
      );
      
      if (response.ok) {
        const data = await response.json();
        // The API returns the actual cycle from vespa_students cache
        currentCycle.value = data.cycle || data.vespaScores?.cycle_number || 1;
        console.log('[VESPA Activities] ✅ Current cycle from API:', currentCycle.value);
      } else {
        console.warn('[VESPA Activities] API call failed, using default cycle 1');
        currentCycle.value = 1;
      }
    } catch (cycleErr) {
      console.error('[VESPA Activities] Error fetching cycle from API:', cycleErr);
      currentCycle.value = 1; // Fallback to cycle 1
    }
    
    console.log('[VESPA Activities] Using cycle:', currentCycle.value);
    
    // Fetch all data with correct cycle (re-fetch with actual cycle if it changed)
    if (currentCycle.value > 1) {
      // Re-fetch with correct cycle
      await Promise.all([
        fetchVESPAScores(currentCycle.value),
        fetchRecommendedActivities(currentCycle.value),
        fetchMyActivities(currentCycle.value),
        fetchNotifications(),
        fetchAchievements()
      ]);
    } else {
      // Already fetched cycle 1 above, just fetch remaining data
      await Promise.all([
        fetchMyActivities(currentCycle.value),
        fetchNotifications(),
        fetchAchievements()
      ]);
    }
    
    console.log('[VESPA Activities] ✅ Initialization complete');
    
    // Initialize prescription flow (check if welcome modal OR motivational popup should show)
    // Pass currentCycle and studentEmail for Supabase tracking
    await initializePrescriptionFlow(
      vespaScores.value, 
      myActivities.value, 
      currentCycle.value,
      studentEmail.value
    );
    
  } catch (err) {
    console.error('[VESPA Activities] Initialization error:', err);
    error.value = err.message || 'Failed to load activities';
  } finally {
    loading.value = false;
  }
};

const retry = () => {
  initialize();
};

const openActivityModal = async (activity) => {
  const API_URL = import.meta.env.VITE_API_URL || 'https://vespa-dashboard-9a1f84ee5341.herokuapp.com';
  activeActivity.value = activity;
  
  try {
    console.log('[VESPA Activities] 📂 Opening activity:', activity.name, activity.id);
    
    // Fetch questions for this activity
    const questionsResponse = await fetch(
      `${API_URL}/api/activities/questions?activity_id=${activity.id}`
    );
    
    if (questionsResponse.ok) {
      const questionsData = await questionsResponse.json();
      activityQuestions.value = questionsData.questions || [];
      console.log('[VESPA Activities] 📋 Loaded', activityQuestions.value.length, 'questions');
    }
    
    // ALWAYS call start endpoint first - it will return existing record if one exists
    // This avoids RLS issues with direct Supabase queries
    console.log('[VESPA Activities] 🚀 Calling start activity API...');
    const startResponse = await fetch(`${API_URL}/api/activities/start`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        studentEmail: studentEmail.value,
        activityId: activity.id,
        selectedVia: 'student_choice',
        cycle: currentCycle.value
      })
    });
    
    if (startResponse.ok) {
      const startData = await startResponse.json();
      console.log('[VESPA Activities] ✅ Start API response:', startData.existed ? 'Record exists' : 'New record created');
      
      // Use the response from start API as existing responses
      if (startData.response && startData.response.responses) {
        existingResponses.value = startData.response;
        console.log('[VESPA Activities] 📥 Loaded existing responses:', Object.keys(startData.response.responses).length, 'answers');
      } else {
        existingResponses.value = startData.response || {};
      }
    } else {
      console.error('[VESPA Activities] ❌ Start API failed:', startResponse.status);
      existingResponses.value = {};
    }
    
  } catch (err) {
    console.error('[VESPA Activities] ❌ Error opening activity:', err);
    activityQuestions.value = [];
    existingResponses.value = {};
  }
};

const closeActivityModal = () => {
  activeActivity.value = null;
  activityQuestions.value = [];
  existingResponses.value = {};
};

const addActivityToDashboard = async (activity) => {
  try {
    await addActivity(activity.id, 'student_choice');
    await checkNewAchievements();  // Check if this triggered achievement
  } catch (err) {
    console.error('Error adding activity:', err);
    alert('Failed to add activity. Please try again.');
  }
};

const removeActivityFromDashboard = async (activityId) => {
  try {
    await removeActivity(activityId);
  } catch (err) {
    console.error('Error removing activity:', err);
    alert('Failed to remove activity. Please try again.');
  }
};

const saveActivityProgress = async (saveData) => {
  try {
    const API_URL = import.meta.env.VITE_API_URL || 'https://vespa-dashboard-9a1f84ee5341.herokuapp.com';
    
    // Debug: Log what we're sending
    const payload = {
      studentEmail: studentEmail.value,
      activityId: activeActivity.value?.id,
      responses: saveData.responses,
      timeMinutes: saveData.timeMinutes,
      cycle: currentCycle.value
    };
    
    console.log('[VESPA Activities] 📤 Saving progress to API:', {
      url: `${API_URL}/api/activities/save`,
      activityId: payload.activityId,
      responsesCount: Object.keys(payload.responses || {}).length,
      cycle: payload.cycle
    });
    
    // Validate before sending
    if (!payload.studentEmail || !payload.activityId) {
      console.error('[VESPA Activities] ❌ Missing required data for save:', payload);
      return;
    }
    
    const response = await fetch(`${API_URL}/api/activities/save`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });
    
    const data = await response.json();
    
    if (response.ok && data.success) {
      console.log('[VESPA Activities] ✅ Progress saved successfully');
    } else {
      console.error('[VESPA Activities] ❌ Save failed:', response.status, data);
    }
  } catch (err) {
    console.error('[VESPA Activities] ❌ Network error saving progress:', err);
  }
};

const completeActivity = async (completeData) => {
  try {
    const API_URL = import.meta.env.VITE_API_URL || 'https://vespa-dashboard-9a1f84ee5341.herokuapp.com';
    
    // Calculate points based on level
    const activityLevel = activeActivity.value?.level || 'Level 2';
    const pointsEarned = activityLevel === 'Level 3' ? 15 : 10;
    
    const payload = {
      studentEmail: studentEmail.value,
      activityId: activeActivity.value?.id,
      responses: completeData.responses,
      reflection: completeData.reflection,
      timeMinutes: completeData.timeMinutes,
      wordCount: completeData.wordCount,
      cycle: currentCycle.value,
      pointsEarned: pointsEarned
    };
    
    console.log(`[VESPA Activities] 📤 Completing activity - awarding ${pointsEarned} points`, {
      activityId: payload.activityId,
      responsesCount: Object.keys(payload.responses || {}).length,
      wordCount: payload.wordCount,
      cycle: payload.cycle
    });
    
    // Validate before sending
    if (!payload.studentEmail || !payload.activityId) {
      console.error('[VESPA Activities] ❌ Missing required data for complete:', payload);
      alert('Missing required data. Please try again.');
      return;
    }
    
    const response = await fetch(`${API_URL}/api/activities/complete`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });
    
    const data = await response.json();
    
    if (response.ok && data.success) {
      console.log('[VESPA Activities] ✅ Activity completed successfully:', data);
      
      // Show achievements if earned
      if (data.newAchievements && data.newAchievements.length > 0) {
        console.log('[VESPA Activities] 🏆 New achievements:', data.newAchievements);
      }
      
      // After completion, check for achievements
      await checkNewAchievements();
      
      // Close modal
      closeActivityModal();
      
      // Refresh my activities (with correct cycle)
      await fetchMyActivities(currentCycle.value);
      
      // Refresh achievements (to update points)
      await fetchAchievements();
      
      // Show success message with points
      showSuccessNotification(pointsEarned);
    } else {
      console.error('[VESPA Activities] ❌ Complete failed:', response.status, data);
      alert(`Failed to complete activity: ${data.error || 'Unknown error'}`);
    }
  } catch (err) {
    console.error('[VESPA Activities] ❌ Network error completing activity:', err);
    alert('Failed to complete activity. Please check your connection and try again.');
  }
};

const showSuccessNotification = (points) => {
  // Create success notification overlay
  const notification = document.createElement('div');
  notification.className = 'success-notification';
  notification.style.cssText = `
    position: fixed;
    top: 100px;
    right: 20px;
    background: linear-gradient(135deg, #28a745 0%, #20c997 100%);
    color: white;
    padding: 20px 30px;
    border-radius: 12px;
    box-shadow: 0 8px 24px rgba(40, 167, 69, 0.3);
    z-index: 10000;
    animation: slideInRight 0.5s ease-out;
    font-size: 16px;
    font-weight: 600;
  `;
  
  notification.innerHTML = `
    <div style="display: flex; align-items: center; gap: 12px;">
      <span style="font-size: 32px;">🎉</span>
      <div>
        <div>Activity Completed!</div>
        <div style="font-size: 20px; margin-top: 4px;">+${points} points</div>
      </div>
    </div>
  `;
  
  document.body.appendChild(notification);
  
  // Auto-remove after 5 seconds
  setTimeout(() => {
    notification.style.animation = 'fadeOut 0.5s ease-in';
    setTimeout(() => notification.remove(), 500);
  }, 5000);
};

// Prescription Flow Handlers
const handleWelcomeContinue = async (prescribedActivities) => {
  try {
    console.log('[VESPA Activities] 📝 Auto-assigning prescribed activities:', prescribedActivities.length);
    
    // Add all prescribed activities
    for (const activity of prescribedActivities) {
      try {
        await addActivity(activity.id, 'questionnaire', currentCycle.value);
        console.log(`✅ Added: ${activity.name}`);
      } catch (err) {
        console.error(`❌ Failed to add ${activity.name}:`, err);
      }
    }
    
    // Mark welcome as handled (save to Supabase for cross-device sync)
    await handleContinue(currentCycle.value, studentEmail.value);
    
    // Refresh activities
    await fetchMyActivities(currentCycle.value);
    
    console.log('[VESPA Activities] ✅ All prescribed activities added');
    
  } catch (err) {
    console.error('[VESPA Activities] Error in handleWelcomeContinue:', err);
    alert('Failed to add activities. Please try again.');
  }
};

const handleWelcomeChooseOwn = async () => {
  // Save to Supabase for cross-device sync
  await handleChooseOwn(currentCycle.value, studentEmail.value);
};

const handleProblemSelection = (data) => {
  console.log('[App] 📥 Problem selected event received:', data);
  handleProblemSelected(data);
};

const handleShowProblemSelector = (data) => {
  console.log('[App] 🎯 Show Problem Selector event received', data);
  console.log('[App] Before:', { showProblemSelector: showProblemSelector.value, showWelcomeModal: showWelcomeModal.value, showMotivationalPopup: showMotivationalPopup.value });
  
  // Close other modals
  showWelcomeModal.value = false;
  showMotivationalPopup.value = false;
  
  // Set category filter if provided
  if (data?.category) {
    selectedCategory.value = data.category;
  } else {
    selectedCategory.value = null;
  }
  
  // Open problem selector
  showProblemSelector.value = true;
  
  console.log('[App] After:', { showProblemSelector: showProblemSelector.value, selectedCategory: selectedCategory.value });
  console.log('[App] ✅ Problem selector should now render');
};

const handleImproveCategory = (category) => {
  console.log('[App] 🎯 Improve category - opening category activities modal:', category);
  selectedCategoryForModal.value = category;
  showCategoryModal.value = true;
};

// Get completed activity IDs for the category modal
const completedActivityIds = computed(() => {
  return myActivities.value
    .filter(a => a.status === 'completed')
    .map(a => a.activity_id || a.id);
});

// Get assigned activity IDs for the category modal
const assignedActivityIds = computed(() => {
  return myActivities.value
    .filter(a => a.status !== 'removed')
    .map(a => a.activity_id || a.id);
});

// Close the category modal
const closeCategoryModal = () => {
  showCategoryModal.value = false;
  selectedCategoryForModal.value = null;
};

// Add activities from category modal
const handleAddCategoryActivities = async (selectedActivities) => {
  try {
    console.log('[App] 📝 Adding category activities:', selectedActivities.length);
    
    for (const activity of selectedActivities) {
      try {
        await addActivity(activity.id, 'student_choice', currentCycle.value);
        console.log(`✅ Added: ${activity.name}`);
      } catch (err) {
        console.error(`❌ Failed to add ${activity.name}:`, err);
      }
    }
    
    // Close modal
    closeCategoryModal();
    
    // Refresh activities
    await fetchMyActivities(currentCycle.value);
    
    console.log('[App] ✅ Category activities added');
    
  } catch (err) {
    console.error('[App] Failed to add category activities:', err);
    alert('Failed to add activities. Please try again.');
  }
};

// Notification handlers
const handleDismissNotification = async (notificationId) => {
  await dismissNotification(notificationId);
};

const handleDismissAllNotifications = async () => {
  await markAllRead();
};

const handleMotivationalAddMoreClick = () => {
  console.log('[App] 🎯 Motivational Add More clicked');
  handleMotivationalAddMore();
  console.log('[App] showProblemSelector should be:', showProblemSelector.value);
};

const handleAddSelectedActivities = async (selectedActivities) => {
  try {
    console.log('[VESPA Activities] 📝 Adding selected activities:', selectedActivities.length);
    
    for (const activity of selectedActivities) {
      try {
        await addActivity(activity.id, 'student_choice', currentCycle.value);
        console.log(`✅ Added: ${activity.name}`);
      } catch (err) {
        console.error(`❌ Failed to add ${activity.name}:`, err);
      }
    }
    
    // Close modals
    closeProblemSelector();
    
    // Refresh activities
    await fetchMyActivities(currentCycle.value);
    
    console.log('[VESPA Activities] ✅ Selected activities added');
    
  } catch (err) {
    console.error('[VESPA Activities] Error adding selected activities:', err);
    alert('Failed to add activities. Please try again.');
  }
};

// Initialize on mount
onMounted(() => {
  initialize();
});
</script>

<style scoped>
.vespa-activities-app {
  position: relative;
  min-height: 100vh;
  background: linear-gradient(135deg, #f5f9fc 0%, #e8f4f8 100%);
}

.loading-container,
.error-container {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  min-height: 400px;
  padding: 40px;
}

.spinner {
  width: 50px;
  height: 50px;
  border: 4px solid #e0e0e0;
  border-top-color: #079baa;
  border-radius: 50%;
  animation: spin 1s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

.notification-bell {
  position: fixed;
  top: 80px;
  right: 20px;
  z-index: 1000;
}

.bell-button {
  position: relative;
  background: white;
  border: 2px solid #079baa;
  border-radius: 50%;
  width: 50px;
  height: 50px;
  font-size: 20px;
  cursor: pointer;
  box-shadow: 0 2px 8px rgba(0,0,0,0.1);
  transition: transform 0.2s;
}

.bell-button:hover {
  transform: scale(1.1);
}

.bell-button .badge {
  position: absolute;
  top: -5px;
  right: -5px;
  background: #ff4444;
  color: white;
  font-size: 12px;
  font-weight: bold;
  padding: 2px 6px;
  border-radius: 10px;
  min-width: 20px;
  text-align: center;
}

.retry-btn {
  margin-top: 20px;
  padding: 12px 24px;
  background: #079baa;
  color: white;
  border: none;
  border-radius: 8px;
  font-size: 16px;
  cursor: pointer;
  transition: background 0.3s;
}

.retry-btn:hover {
  background: #007a8a;
}

/* Success Notification Animation */
@keyframes slideInRight {
  from {
    transform: translateX(400px);
    opacity: 0;
  }
  to {
    transform: translateX(0);
    opacity: 1;
  }
}

@keyframes fadeOut {
  from {
    opacity: 1;
  }
  to {
    opacity: 0;
  }
}
</style>


