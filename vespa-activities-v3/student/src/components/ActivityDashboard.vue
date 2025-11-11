<template>
  <div class="activity-dashboard">
    <!-- Header -->
    <div class="dashboard-header">
      <h1>VESPA Activities</h1>
      <div class="header-actions">
        <button @click="$emit('show-achievements')" class="btn btn-outline">
          🏆 Achievements ({{ totalPoints }} pts)
        </button>
      </div>
    </div>

    <!-- Progress Overview -->
    <div class="progress-overview card">
      <h2>Your Progress</h2>
      <div class="progress-stats">
        <div class="stat">
          <div class="stat-value">{{ completedCount }}</div>
          <div class="stat-label">Completed</div>
        </div>
        <div class="stat">
          <div class="stat-value">{{ inProgressCount }}</div>
          <div class="stat-label">In Progress</div>
        </div>
        <div class="stat">
          <div class="stat-value">{{ assignedCount }}</div>
          <div class="stat-label">Assigned</div>
        </div>
        <div class="stat">
          <div class="stat-value">{{ totalPoints }}</div>
          <div class="stat-label">Points</div>
        </div>
      </div>
    </div>

    <!-- VESPA Scores Summary -->
    <div v-if="vespaScores" class="scores-summary card">
      <h3>Your VESPA Scores</h3>
      <div class="scores-grid">
        <div class="score-item" v-for="category in categories" :key="category">
          <div class="score-label">{{ category }}</div>
          <div class="score-bar">
            <div 
              class="score-fill" 
              :style="{ 
                width: `${(vespaScores[category.toLowerCase()] || 0) * 10}%`,
                backgroundColor: categoryColors[category]
              }"
            ></div>
            <span class="score-value">{{ vespaScores[category.toLowerCase()] || 0 }}/10</span>
          </div>
        </div>
      </div>
    </div>

    <!-- Recommended Activities -->
    <section class="recommended-section">
      <h2>📊 Recommended for Your Scores</h2>
      <div v-if="recommendedActivities.length === 0" class="empty-state">
        <p>No activities recommended at this time. Complete the VESPA questionnaire to get personalized recommendations.</p>
      </div>
      <div v-else class="activity-grid">
        <ActivityCard
          v-for="activity in recommendedActivities"
          :key="activity.id"
          :activity="activity"
          :progress="getProgressForActivity(activity.id)"
          @start-activity="handleStartActivity"
        />
      </div>
    </section>

    <!-- Problem-Based Selection -->
    <section class="problem-section card">
      <h2>🎯 Select by Problem</h2>
      <ProblemSelector @select-activity="handleAddActivity" />
    </section>

    <!-- My Activities -->
    <section class="my-activities">
      <div class="section-header">
        <h2>📚 My Activities</h2>
        <CategoryFilter v-model="filterCategory" />
      </div>
      <div v-if="filteredMyActivities.length === 0" class="empty-state">
        <p>No activities assigned yet. Browse recommended activities or select by problem above.</p>
      </div>
      <div v-else class="activity-grid">
        <ActivityCard
          v-for="assignment in filteredMyActivities"
          :key="assignment.activity_id || assignment.id"
          :activity="assignment.activities || assignment"
          :progress="assignment.progress"
          :is-assigned="true"
          @start-activity="handleStartActivity"
          @remove-activity="handleRemoveActivity"
        />
      </div>
    </section>
  </div>
</template>

<script setup>
import { ref, computed } from 'vue';
import ActivityCard from './ActivityCard.vue';
import ProblemSelector from './ProblemSelector.vue';
import CategoryFilter from './CategoryFilter.vue';
import { CATEGORY_COLORS, VESPA_CATEGORIES } from '../../shared/constants';

const props = defineProps({
  studentEmail: {
    type: String,
    required: true
  },
  vespaScores: {
    type: Object,
    default: () => ({})
  },
  recommendedActivities: {
    type: Array,
    default: () => []
  },
  myActivities: {
    type: Array,
    default: () => []
  },
  achievements: {
    type: Array,
    default: () => []
  },
  totalPoints: {
    type: Number,
    default: 0
  }
});

const emit = defineEmits(['start-activity', 'add-activity', 'remove-activity', 'show-achievements']);

const filterCategory = ref(null);
const categories = VESPA_CATEGORIES;
const categoryColors = CATEGORY_COLORS;

// Computed
const completedCount = computed(() => {
  return props.myActivities.filter(a => a.progress?.status === 'completed').length;
});

const inProgressCount = computed(() => {
  return props.myActivities.filter(a => a.progress?.status === 'in_progress').length;
});

const assignedCount = computed(() => {
  return props.myActivities.length;
});

const filteredMyActivities = computed(() => {
  if (!filterCategory.value) return props.myActivities;
  return props.myActivities.filter(assignment => {
    const activity = assignment.activities || assignment;
    return activity.vespa_category === filterCategory.value;
  });
});

// Methods
const getProgressForActivity = (activityId) => {
  const assignment = props.myActivities.find(a => 
    (a.activity_id || a.id) === activityId
  );
  return assignment?.progress || null;
};

const handleStartActivity = (activity) => {
  emit('start-activity', activity);
};

const handleAddActivity = (activity) => {
  emit('add-activity', activity);
};

const handleRemoveActivity = (activityId) => {
  emit('remove-activity', activityId);
};
</script>

<style scoped>
.activity-dashboard {
  padding: var(--spacing-lg);
  max-width: 1400px;
  margin: 0 auto;
}

.dashboard-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: var(--spacing-xl);
}

.dashboard-header h1 {
  margin: 0;
  color: var(--dark-blue);
}

.header-actions {
  display: flex;
  gap: var(--spacing-sm);
}

.progress-overview {
  margin-bottom: var(--spacing-lg);
}

.progress-stats {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
  gap: var(--spacing-md);
  margin-top: var(--spacing-md);
}

.stat {
  text-align: center;
}

.stat-value {
  font-size: 2rem;
  font-weight: 700;
  color: var(--primary);
}

.stat-label {
  font-size: 0.875rem;
  color: var(--dark-gray);
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

.scores-summary {
  margin-bottom: var(--spacing-lg);
}

.scores-grid {
  display: flex;
  flex-direction: column;
  gap: var(--spacing-md);
  margin-top: var(--spacing-md);
}

.score-item {
  display: flex;
  align-items: center;
  gap: var(--spacing-md);
}

.score-label {
  min-width: 100px;
  font-weight: 500;
  color: var(--dark-blue);
}

.score-bar {
  flex: 1;
  height: 30px;
  background: var(--gray);
  border-radius: var(--radius-md);
  position: relative;
  overflow: hidden;
}

.score-fill {
  height: 100%;
  transition: width 0.3s;
  border-radius: var(--radius-md);
}

.score-value {
  position: absolute;
  right: var(--spacing-sm);
  top: 50%;
  transform: translateY(-50%);
  font-weight: 600;
  color: var(--text);
  font-size: 0.875rem;
}

.recommended-section,
.my-activities {
  margin-bottom: var(--spacing-xl);
}

.section-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: var(--spacing-md);
}

.activity-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
  gap: var(--spacing-md);
}

.empty-state {
  padding: var(--spacing-xl);
  text-align: center;
  color: var(--dark-gray);
  background: white;
  border-radius: var(--radius-lg);
}

.problem-section {
  margin-bottom: var(--spacing-xl);
}

@media (max-width: 768px) {
  .activity-dashboard {
    padding: var(--spacing-md);
  }
  
  .dashboard-header {
    flex-direction: column;
    align-items: flex-start;
    gap: var(--spacing-md);
  }
  
  .section-header {
    flex-direction: column;
    align-items: flex-start;
  }
  
  .activity-grid {
    grid-template-columns: 1fr;
  }
  
  .progress-stats {
    grid-template-columns: repeat(2, 1fr);
  }
}
</style>

