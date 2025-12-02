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
      @start-activity="openActivityModal"
      @add-activity="addActivityToDashboard"
      @remove-activity="removeActivityFromDashboard"
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
  </div>
</template>

<script setup>
import { ref, onMounted, computed } from 'vue';
import ActivityDashboard from './components/ActivityDashboard.vue';
import ActivityModal from './components/ActivityModal.vue';
import AchievementPanel from './components/AchievementPanel.vue';
import { useActivities } from './composables/useActivities';
import { useVESPAScores } from './composables/useVESPAScores';
import { useNotifications } from './composables/useNotifications';
import { useAchievements } from './composables/useAchievements';
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
  fetchNotifications,
  markRead,
  toggleNotifications
} = useNotifications(studentEmail.value);

const {
  achievements,
  totalPoints,
  fetchAchievements,
  checkNewAchievements
} = useAchievements(studentEmail.value);

// Methods
const initialize = async () => {
  try {
    loading.value = true;
    error.value = null;
    
    if (!studentEmail.value) {
      throw new Error('Student email not found. Please ensure you are logged in.');
    }
    
    console.log('[VESPA Activities] Initializing for:', studentEmail.value);
    
    // FIRST: Fetch current cycle from Supabase (vespa_students table)
    try {
      const { data: studentData } = await supabase
        .from('vespa_students')
        .select('current_cycle, latest_vespa_scores')
        .eq('email', studentEmail.value)
        .single();
      
      if (studentData) {
        // Get cycle from column OR from cached scores JSONB
        currentCycle.value = studentData.current_cycle || 
                            studentData.latest_vespa_scores?.cycle || 
                            1;
        console.log('[VESPA Activities] ✅ Current cycle from Supabase:', currentCycle.value);
      } else {
        console.warn('[VESPA Activities] Student not found in vespa_students, using default cycle 1');
        currentCycle.value = 1;
      }
    } catch (cycleErr) {
      console.error('[VESPA Activities] Error fetching cycle from Supabase:', cycleErr);
      currentCycle.value = 1; // Fallback to cycle 1
    }
    
    console.log('[VESPA Activities] Using cycle:', currentCycle.value);
    
    // Fetch all data in parallel with correct cycle
    await Promise.all([
      fetchVESPAScores(currentCycle.value),
      fetchRecommendedActivities(currentCycle.value),
      fetchMyActivities(currentCycle.value),
      fetchNotifications(),
      fetchAchievements()
    ]);
    
    console.log('[VESPA Activities] ✅ Initialization complete');
    
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
  activeActivity.value = activity;
  
  try {
    // Fetch questions for this activity
    const response = await fetch(
      `${import.meta.env.VITE_API_URL || 'https://vespa-dashboard-9a1f84ee5341.herokuapp.com'}/api/activities/questions?activity_id=${activity.id}`
    );
    
    if (response.ok) {
      const data = await response.json();
      activityQuestions.value = data.questions || [];
    }
    
    // Fetch existing response if any (use current cycle)
    const { data } = await supabase
      .from('activity_responses')
      .select('*')
      .eq('student_email', studentEmail.value)
      .eq('activity_id', activity.id)
      .eq('cycle_number', currentCycle.value)
      .maybeSingle();
    
    existingResponses.value = data || {};
    
    // Start activity if not already started
    if (!existingResponses.value.id) {
      await fetch(`${import.meta.env.VITE_API_URL || 'https://vespa-dashboard-9a1f84ee5341.herokuapp.com'}/api/activities/start`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          studentEmail: studentEmail.value,
          activityId: activity.id,
          selectedVia: 'student_choice',
          cycle: currentCycle.value
        })
      });
    }
  } catch (err) {
    console.error('[App] Error opening activity:', err);
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
    await fetch(`${import.meta.env.VITE_API_URL || 'https://vespa-dashboard-9a1f84ee5341.herokuapp.com'}/api/activities/save`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        studentEmail: studentEmail.value,
        activityId: activeActivity.value.id,
        responses: saveData.responses,
        timeMinutes: saveData.timeMinutes,
        cycle: currentCycle.value
      })
    });
    console.log('[VESPA Activities] ✅ Progress saved');
  } catch (err) {
    console.error('[VESPA Activities] Error saving progress:', err);
  }
};

const completeActivity = async (completeData) => {
  try {
    const response = await fetch(`${import.meta.env.VITE_API_URL || 'https://vespa-dashboard-9a1f84ee5341.herokuapp.com'}/api/activities/complete`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        studentEmail: studentEmail.value,
        activityId: activeActivity.value.id,
        responses: completeData.responses,
        reflection: completeData.reflection,
        timeMinutes: completeData.timeMinutes,
        wordCount: completeData.wordCount,
        cycle: currentCycle.value
      })
    });
    
    if (response.ok) {
      const data = await response.json();
      console.log('[VESPA Activities] ✅ Activity completed:', data);
      
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
      
      // Refresh achievements
      await fetchAchievements();
    }
  } catch (err) {
    console.error('[VESPA Activities] Error completing activity:', err);
    alert('Failed to complete activity. Please try again.');
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
</style>


