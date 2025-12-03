<template>
  <div class="activity-dashboard">
    <!-- Beautiful Header with Gradient -->
    <div class="vespa-header">
      <div class="header-content">
        <div class="user-welcome">
          <h1 class="animated-title">
            <span class="wave">👋</span> Hi {{ firstName }}!
          </h1>
          <p class="subtitle">Ready to boost your VESPA scores today?</p>
        </div>
        <div class="header-stats">
          <div class="stat-card clickable" @click="handleShowAchievements">
            <span class="stat-emoji">⭐</span>
            <div class="stat-content">
              <div class="stat-value">{{ totalPoints }}</div>
              <div class="stat-label">Points</div>
            </div>
          </div>
          <div class="stat-card clickable" @click="handleShowAchievements">
            <span class="stat-emoji">🔥</span>
            <div class="stat-content">
              <div class="stat-value">{{ currentStreak }}</div>
              <div class="stat-label">Day Streak</div>
            </div>
          </div>
          <div class="stat-card">
            <span class="stat-emoji">🎯</span>
            <div class="stat-content">
              <div class="stat-value">{{ completedCount }}</div>
              <div class="stat-label">Completed</div>
            </div>
          </div>
          <div class="stat-card">
            <span class="stat-emoji">📋</span>
            <div class="stat-content">
              <div class="stat-value">{{ inProgressCount }}</div>
              <div class="stat-label">In Progress</div>
            </div>
          </div>
        </div>
      </div>
      
      <!-- Achievement Button (Top Right) -->
      <button @click="handleShowAchievements" class="achievements-button">
        <span class="trophy-icon">🏆</span>
        <span class="achievement-text">{{ achievementCount }} Achievements</span>
      </button>
    </div>

    <!-- VESPA Scores with Circular Indicators -->
    <section class="vespa-scores-section" v-if="vespaScores">
      <h2 class="section-title">
        <span class="title-icon">📊</span>
        Your VESPA Profile
      </h2>
      <div class="scores-grid">
        <div 
          v-for="category in categories" 
          :key="category"
          class="score-card" 
          :data-category="category.toLowerCase()"
          :data-score="vespaScores[category.toLowerCase()] || 0"
        >
          <div class="score-header" :style="{ background: categoryColors[category] }">
            <span class="score-emoji">{{ categoryEmojis[category] }}</span>
            <span class="score-label">{{ category }}</span>
          </div>
          <div class="score-body">
            <div class="score-circle" :style="{ '--score': vespaScores[category.toLowerCase()] || 0 }">
              <svg viewBox="0 0 36 36">
                <path class="circle-bg" d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831" />
                <path class="circle-fill" :stroke="categoryColors[category]" d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831" />
              </svg>
              <span class="score-value">{{ vespaScores[category.toLowerCase()] || 0 }}</span>
            </div>
            <div class="score-dots" :style="{ color: categoryColors[category] }">
              <span 
                v-for="n in 10" 
                :key="n"
                class="score-dot" 
                :class="{ filled: n <= (vespaScores[category.toLowerCase()] || 0) }"
              ></span>
            </div>
            <div class="score-rating" :style="{ color: categoryColors[category] }">
              {{ getScoreRating(vespaScores[category.toLowerCase()] || 0) }}
            </div>
            <button class="improve-btn" @click="handleImproveCategory(category.toLowerCase())">
              Improve {{ categoryEmojis[category] }}
            </button>
          </div>
        </div>
      </div>
    </section>

    <!-- Recommended Activities (Collapsible) -->
    <section class="recommended-section" v-if="recommendedActivities.length > 0">
      <div class="section-header-with-action">
        <div class="section-title-group">
          <h2 class="section-title">
            <span class="title-icon">💡</span>
            Recommended for Your Scores
          </h2>
          <button 
            @click="toggleRecommendations" 
            class="toggle-section-btn"
            :title="showRecommendations ? 'Hide recommendations' : 'Show recommendations'"
          >
            <i :class="showRecommendations ? 'fas fa-chevron-up' : 'fas fa-chevron-down'"></i>
            {{ showRecommendations ? 'Hide' : 'Show' }}
          </button>
        </div>
        <button @click="handleChooseByProblemClick" class="btn-select-by-problem">
          <i class="fas fa-hand-pointer"></i>
          Or Choose by Problem
        </button>
      </div>
      <transition name="slide-fade">
        <div v-show="showRecommendations" class="activity-grid">
          <ActivityCard
            v-for="activity in recommendedActivities"
            :key="activity.id"
            :activity="activity"
            :progress="getProgressForActivity(activity.id)"
            @start-activity="handleStartActivity"
          />
        </div>
      </transition>
    </section>

    <!-- My Activities (Grouped by Category) -->
    <section class="my-activities" v-if="filteredMyActivities.length > 0">
      <h2 class="section-title">
        <span class="title-icon">✨</span>
        Your Activities
        <span class="title-badge">{{ toCompleteCount }} to complete | {{ completedCount }} completed</span>
      </h2>
      
      <!-- Group by Category -->
      <div v-for="(categoryActivities, categoryName) in activitiesByCategory" :key="categoryName" 
           class="category-group"
           :class="`vespa-${categoryName.toLowerCase()}`"
           :style="{ 
             borderColor: categoryColors[categoryName], 
             backgroundColor: `${categoryColors[categoryName]}10`
           }">
        <h3 class="category-group-title">
          {{ categoryEmojis[categoryName] }} {{ categoryName.toUpperCase() }}
        </h3>
        <div class="activities-grid">
          <ActivityCard
            v-for="assignment in categoryActivities"
            :key="assignment.activity_id || assignment.id"
            :activity="assignment.activities || assignment"
            :progress="assignment.progress"
            :is-assigned="true"
            @start-activity="handleStartActivity"
            @remove-activity="handleRemoveActivity"
          />
        </div>
      </div>
    </section>

    <!-- Empty State -->
    <div v-if="filteredMyActivities.length === 0" class="empty-state-large">
      <span class="empty-icon">🌱</span>
      <h3>No Activities Yet</h3>
      <p>Browse recommended activities above or select by problem to get started!</p>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, watch } from 'vue';
import ActivityCard from './ActivityCard.vue';
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
  },
  currentStreak: {
    type: Number,
    default: 0
  },
  showWelcomeModal: {
    type: Boolean,
    default: false
  },
  showProblemSelector: {
    type: Boolean,
    default: false
  }
});

// Computed for achievement count
const achievementCount = computed(() => {
  return props.achievements?.length || 0;
});

const emit = defineEmits([
  'start-activity', 
  'add-activity', 
  'remove-activity', 
  'show-achievements',
  'show-welcome-modal',
  'show-problem-selector',
  'improve-category'
]);

const handleShowAchievements = () => {
  console.log('[ActivityDashboard] 🏆 Achievements button clicked!');
  emit('show-achievements');
  console.log('[ActivityDashboard] ✅ Emitted show-achievements event');
};

const filterCategory = ref(null);
const categories = VESPA_CATEGORIES;

// Category Colors - matching staff dashboard
const categoryColors = {
  'Vision': '#fc8900',
  'Effort': '#78aced',
  'Systems': '#7bc114',
  'Practice': '#792e9c',
  'Attitude': '#eb2de3'
};

// Category Emojis
const categoryEmojis = {
  'Vision': '👁️',
  'Effort': '💪',
  'Systems': '⚙️',
  'Practice': '🎯',
  'Attitude': '🧠'
};

// Recommendations visibility (persisted in localStorage)
const showRecommendations = ref(true);

// Load saved preference on mount
const savedPref = localStorage.getItem('vespa-show-recommendations');
if (savedPref !== null) {
  showRecommendations.value = savedPref === 'true';
}

const toggleRecommendations = () => {
  showRecommendations.value = !showRecommendations.value;
  localStorage.setItem('vespa-show-recommendations', showRecommendations.value.toString());
};

// Get student first name
const firstName = computed(() => {
  if (typeof Knack !== 'undefined' && Knack.getUserAttributes) {
    const user = Knack.getUserAttributes();
    return user?.name?.split(' ')[0] || 'Student';
  }
  return 'Student';
});

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

const toCompleteCount = computed(() => {
  return props.myActivities.filter(a => a.progress?.status !== 'completed').length;
});

const filteredMyActivities = computed(() => {
  if (!filterCategory.value) return props.myActivities;
  return props.myActivities.filter(assignment => {
    const activity = assignment.activities || assignment;
    return activity.vespa_category === filterCategory.value;
  });
});

// Group activities by category
const activitiesByCategory = computed(() => {
  const grouped = {};
  filteredMyActivities.value.forEach(assignment => {
    const activity = assignment.activities || assignment;
    const category = activity.vespa_category;
    if (category) {
      if (!grouped[category]) {
        grouped[category] = [];
      }
      grouped[category].push(assignment);
    }
  });
  return grouped;
});

// Methods
const getProgressForActivity = (activityId) => {
  const assignment = props.myActivities.find(a => 
    (a.activity_id || a.id) === activityId
  );
  return assignment?.progress || null;
};

const getScoreRating = (score) => {
  if (score >= 9) return 'Excellent! 🌟';
  if (score >= 8) return 'Very Good! ✨';
  if (score >= 7) return 'Great! 🎯';
  if (score >= 6) return 'Good Progress 👍';
  if (score >= 5) return 'Solid Foundation 💪';
  if (score >= 4) return 'Developing 📈';
  if (score >= 3) return 'Building Skills 🔨';
  return 'Getting Started 🌱';
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

const handleChooseByProblemClick = () => {
  console.log('[ActivityDashboard] 🎯 Choose by Problem button clicked');
  emit('show-problem-selector');
  console.log('[ActivityDashboard] 📤 Emitted show-problem-selector event');
};

const handleImproveCategory = (category) => {
  console.log('[ActivityDashboard] 🎯 Improve button clicked for category:', category);
  
  // Emit improve-category to open the CategoryActivitiesModal (category-specific)
  // This is DIFFERENT from the Problem Selector which shows problems across all categories
  console.log('[ActivityDashboard] 📤 Emitting improve-category with:', category);
  emit('improve-category', category);
  // NOTE: Don't emit show-problem-selector here - that's a different modal!
};
</script>

<style scoped>
.activity-dashboard {
  min-height: 100vh;
  background: linear-gradient(135deg, #f5f9fc 0%, #e8f4f8 100%);
}

/* ===== Beautiful Header ===== */
.vespa-header {
  background: linear-gradient(135deg, var(--primary) 0%, var(--primary-light) 100%);
  color: var(--white);
  padding: 2rem;
  border-radius: 0 0 30px 30px;
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.15);
  position: relative;
  overflow: hidden;
  margin-bottom: 2rem;
}

.vespa-header::before {
  content: '';
  position: absolute;
  top: -50%;
  right: -50%;
  width: 200%;
  height: 200%;
  background: radial-gradient(circle, rgba(255, 255, 255, 0.1) 0%, transparent 70%);
}

.header-content {
  position: relative;
  z-index: 1;
}

.user-welcome {
  margin-bottom: 2rem;
}

.animated-title {
  font-size: 2rem;
  font-weight: 800;
  margin: 0 0 0.5rem 0;
  display: flex;
  align-items: center;
  gap: 0.5rem;
  color: white;
}

.wave {
  display: inline-block;
  animation-name: wave-animation;
  animation-duration: 2.5s;
  animation-iteration-count: infinite;
  transform-origin: 70% 70%;
}

@keyframes wave-animation {
  0% { transform: rotate(0deg); }
  10% { transform: rotate(14deg); }
  20% { transform: rotate(-8deg); }
  30% { transform: rotate(14deg); }
  40% { transform: rotate(-4deg); }
  50% { transform: rotate(10deg); }
  60% { transform: rotate(0deg); }
  100% { transform: rotate(0deg); }
}

.subtitle {
  font-size: 1.1rem;
  opacity: 0.9;
  margin: 0;
}

.header-stats {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(120px, 1fr));
  gap: 1rem;
}

.stat-card {
  background: rgba(255, 255, 255, 0.2);
  backdrop-filter: blur(10px);
  border-radius: 15px;
  padding: 1rem;
  display: flex;
  align-items: center;
  gap: 0.75rem;
  transition: all 0.3s;
}

.stat-card:hover {
  background: rgba(255, 255, 255, 0.3);
  transform: translateY(-2px);
}

.stat-card.clickable {
  cursor: pointer;
}

.stat-card.clickable:hover {
  background: rgba(255, 255, 255, 0.4);
  transform: translateY(-3px);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
}

.stat-emoji {
  font-size: 1.5rem;
}

.stat-content {
  display: flex;
  flex-direction: column;
}

.stat-value {
  font-size: 1.5rem;
  font-weight: 700;
  line-height: 1;
}

.stat-label {
  font-size: 0.875rem;
  opacity: 0.9;
}

/* Achievement Button */
.achievements-button {
  position: absolute;
  top: 1rem;
  right: 1rem;
  background: rgba(255, 255, 255, 0.95);
  border: 2px solid var(--primary-light);
  border-radius: 20px;
  padding: 0.75rem 1.5rem;
  display: flex;
  align-items: center;
  gap: 0.5rem;
  cursor: pointer;
  transition: all 0.3s;
  font-weight: 600;
  color: var(--primary);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
}

.achievements-button:hover {
  transform: translateY(-2px);
  box-shadow: 0 6px 16px rgba(0, 0, 0, 0.2);
  background: white;
}

.trophy-icon {
  font-size: 1.25rem;
}

/* ===== VESPA Scores Section ===== */
.vespa-scores-section {
  background: var(--white);
  border-radius: 20px;
  padding: 2rem;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
  margin: 0 2rem 2rem 2rem;
}

.section-title {
  font-size: 1.5rem;
  font-weight: 700;
  color: var(--dark-blue);
  margin: 0 0 1.5rem 0;
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.title-icon {
  font-size: 1.75rem;
}

.title-badge {
  background: var(--primary-light);
  color: var(--dark-blue);
  font-size: 0.75rem;
  padding: 0.25rem 0.75rem;
  border-radius: 20px;
  margin-left: auto;
  font-weight: 600;
}

.scores-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(160px, 1fr));
  gap: 1rem;
}

.score-card {
  background: var(--white);
  border-radius: 16px;
  overflow: hidden;
  transition: all 0.3s;
  border: 2px solid #f1f3f5;
}

.score-card:hover {
  transform: translateY(-4px);
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.15);
}

.score-header {
  padding: 0.75rem;
  color: var(--white);
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-weight: 600;
  text-transform: capitalize;
}

.score-emoji {
  font-size: 1.25rem;
}

.score-label {
  font-size: 0.95rem;
}

.score-body {
  padding: 1.5rem 1rem;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.75rem;
}

.score-circle {
  width: 100px;
  height: 100px;
  position: relative;
}

.score-circle svg {
  width: 100%;
  height: 100%;
  transform: rotate(-90deg);
}

.circle-bg {
  fill: none;
  stroke: #e9ecef;
  stroke-width: 4;
}

.circle-fill {
  fill: none;
  stroke-width: 4;
  stroke-linecap: round;
  stroke-dasharray: calc(var(--score) * 10), 100;
  transition: stroke-dasharray 1s ease;
}

.score-value {
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  font-size: 2rem;
  font-weight: 700;
  color: var(--dark-blue);
}

.score-dots {
  display: flex;
  gap: 0.25rem;
  justify-content: center;
}

.score-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background: #e9ecef;
  transition: all 0.3s;
}

.score-dot.filled {
  background: currentColor;
  transform: scale(1.2);
}

.score-rating {
  font-size: 0.875rem;
  text-align: center;
  font-weight: 500;
  min-height: 1.5rem;
}

.improve-btn {
  background: var(--white);
  border: 2px solid currentColor;
  padding: 0.5rem 1rem;
  border-radius: 8px;
  font-size: 0.875rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.3s;
  color: inherit;
  width: 100%;
}

.improve-btn:hover {
  background: currentColor;
  color: var(--white);
  transform: scale(1.05);
}

/* ===== Sections ===== */
.recommended-section,
.my-activities {
  padding: 0 2rem;
  margin-bottom: 2rem;
}

.section-header-with-action {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1.5rem;
  flex-wrap: wrap;
  gap: 1rem;
}

.section-title-group {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.toggle-section-btn {
  display: flex;
  align-items: center;
  gap: 0.375rem;
  padding: 0.375rem 0.75rem;
  background: #f1f5f9;
  border: 1px solid #e2e8f0;
  border-radius: 6px;
  font-size: 0.8rem;
  font-weight: 500;
  color: #64748b;
  cursor: pointer;
  transition: all 0.2s;
}

.toggle-section-btn:hover {
  background: #e2e8f0;
  color: #475569;
}

.toggle-section-btn i {
  font-size: 0.75rem;
  transition: transform 0.2s;
}

/* Slide transition for collapsible sections */
.slide-fade-enter-active {
  transition: all 0.3s ease-out;
}

.slide-fade-leave-active {
  transition: all 0.2s ease-in;
}

.slide-fade-enter-from,
.slide-fade-leave-to {
  opacity: 0;
  transform: translateY(-10px);
  max-height: 0;
  overflow: hidden;
}

.slide-fade-enter-to,
.slide-fade-leave-from {
  opacity: 1;
  transform: translateY(0);
}

.btn-select-by-problem {
  background: white;
  border: 2px solid #079baa;
  color: #079baa;
  padding: 0.75rem 1.5rem;
  border-radius: 8px;
  font-size: 0.95rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.3s;
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.btn-select-by-problem:hover {
  background: #079baa;
  color: white;
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(7, 155, 170, 0.2);
}

/* Category Groups */
.category-group {
  margin-bottom: 2rem;
  padding: 1.5rem;
  border-radius: 12px;
  border: 2px solid;
  transition: all 0.3s;
  background: white;
}

.category-group:hover {
  transform: translateY(-2px);
  box-shadow: 0 8px 16px rgba(0, 0, 0, 0.08);
}

.category-group-title {
  font-size: 1.25rem;
  font-weight: 700;
  color: var(--dark-blue);
  margin: 0 0 1.25rem 0;
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding-bottom: 0.75rem;
  border-bottom: 1px solid rgba(0, 0, 0, 0.1);
}

.activities-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  gap: 1rem;
}

.activity-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
  gap: 1.5rem;
}

.empty-state-large {
  text-align: center;
  padding: 4rem 2rem;
  background: white;
  border-radius: 20px;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
  margin: 2rem;
}

.empty-icon {
  font-size: 4rem;
  display: block;
  margin-bottom: 1rem;
  opacity: 0.5;
}

.empty-state-large h3 {
  font-size: 1.5rem;
  color: var(--dark-blue);
  margin-bottom: 0.5rem;
}

.empty-state-large p {
  color: var(--dark-gray);
}

@media (max-width: 768px) {
  .vespa-header {
    padding: 1.5rem 1rem;
    border-radius: 0 0 20px 20px;
  }
  
  .animated-title {
    font-size: 1.5rem;
  }
  
  .header-stats {
    grid-template-columns: repeat(2, 1fr);
  }
  
  .achievements-button {
    position: static;
    width: 100%;
    margin-top: 1rem;
    justify-content: center;
  }
  
  .vespa-scores-section,
  .recommended-section,
  .my-activities {
    padding: 0 1rem;
    margin: 0 1rem 1.5rem 1rem;
  }
  
  .scores-grid {
    grid-template-columns: repeat(2, 1fr);
  }
  
  .activity-grid,
  .activities-grid {
    grid-template-columns: 1fr;
  }
  
  .category-group {
    padding: 1rem;
  }
}
</style>

