<template>
  <div class="modal-overlay" @click.self="$emit('close')">
    <div class="welcome-modal modal-large">
      <div class="modal-header">
        <h2 class="modal-title">
          <span class="welcome-icon">🎯</span>
          Welcome to Your VESPA Activities!
        </h2>
        <p class="modal-subtitle">
          Based on your VESPA scores, we've selected activities to help you improve
        </p>
      </div>

      <div class="modal-body">
        <!-- Your VESPA Profile Summary -->
        <div class="scores-summary">
          <h4 class="summary-title">
            <i class="fas fa-chart-bar"></i>
            Your VESPA Profile
          </h4>
          <div class="scores-compact">
            <div
              v-for="category in categories"
              :key="category"
              class="score-compact"
              :style="{ borderColor: categoryColors[category] }"
            >
              <span class="score-emoji">{{ categoryEmojis[category] }}</span>
              <span class="score-name">{{ category }}</span>
              <span class="score-num" :style="{ color: categoryColors[category] }">
                {{ vespaScores[category.toLowerCase()] || 0 }}
              </span>
            </div>
          </div>
        </div>

        <!-- Recommended Activities Preview -->
        <div class="recommended-preview">
          <h4 class="summary-title">
            <i class="fas fa-lightbulb"></i>
            We've Selected {{ prescribedActivities.length }} Activities for You
          </h4>
          <p class="preview-description">
            These activities are specifically chosen based on your scores to help you improve where you need it most.
          </p>
          
          <div class="activities-preview-grid">
            <div
              v-for="activity in prescribedActivities"
              :key="activity.id"
              :class="['activity-preview-card', (activity.vespa_category || '').toLowerCase()]"
            >
              <div class="preview-header">
                <span class="preview-emoji">{{ categoryEmojis[activity.vespa_category] }}</span>
                <span class="preview-name">{{ activity.name }}</span>
              </div>
              <div class="preview-meta">
                <span class="preview-badge">{{ activity.vespa_category }}</span>
                <span class="preview-badge">{{ activity.level }}</span>
                <span v-if="activity.time_minutes" class="preview-badge">
                  {{ activity.time_minutes }}min
                </span>
              </div>
            </div>
          </div>
        </div>

        <!-- Action Buttons -->
        <div class="action-section">
          <div class="action-card primary-action">
            <div class="action-icon">✨</div>
            <h3>Continue with These Activities</h3>
            <p>Start with our recommended selection - you can always add or remove activities later</p>
            <button
              class="btn btn-primary btn-large"
              @click="handleContinue"
              :disabled="isAssigning"
            >
              <i class="fas fa-check-circle"></i>
              {{ isAssigning ? 'Adding Activities...' : 'Yes, Continue!' }}
            </button>
          </div>

          <div class="action-divider">
            <span>OR</span>
          </div>

          <div class="action-card secondary-action">
            <div class="action-icon">🎨</div>
            <h3>Choose Your Own Activities</h3>
            <p>Select activities based on specific challenges you're facing</p>
            <button
              class="btn btn-secondary btn-large"
              @click="handleChooseOwn"
              :disabled="isAssigning"
            >
              <i class="fas fa-hand-pointer"></i>
              Select by Problem
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue';
import { CATEGORY_COLORS } from '../../shared/constants';

const props = defineProps({
  vespaScores: {
    type: Object,
    required: true
  },
  prescribedActivities: {
    type: Array,
    required: true
  }
});

const emit = defineEmits(['continue', 'choose-own', 'close']);

const isAssigning = ref(false);

const categories = ['Vision', 'Effort', 'Systems', 'Practice', 'Attitude'];
const categoryColors = CATEGORY_COLORS;

const categoryEmojis = {
  'Vision': '👁️',
  'Effort': '💪',
  'Systems': '⚙️',
  'Practice': '🎯',
  'Attitude': '🧠'
};

const handleContinue = async () => {
  isAssigning.value = true;
  try {
    emit('continue', props.prescribedActivities);
  } finally {
    // Don't set isAssigning back to false - let parent handle cleanup after success
  }
};

const handleChooseOwn = () => {
  emit('choose-own');
};
</script>

<style scoped>
.welcome-modal {
  max-width: 900px;
  width: 95%;
  max-height: 90vh;
  overflow-y: auto;
}

.modal-header {
  background: linear-gradient(135deg, #079baa 0%, #00a8b8 100%);
  color: white;
  padding: 2rem;
  border-radius: 16px 16px 0 0;
  text-align: center;
}

.modal-title {
  margin: 0 0 0.5rem 0;
  font-size: 2rem;
  font-weight: 700;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.75rem;
}

.welcome-icon {
  font-size: 2.5rem;
}

.modal-subtitle {
  margin: 0;
  font-size: 1.1rem;
  opacity: 0.95;
}

.modal-body {
  padding: 2rem;
}

/* Scores Summary */
.scores-summary {
  background: linear-gradient(135deg, #f8f9fa 0%, #e9ecef 100%);
  border-radius: 12px;
  padding: 1.5rem;
  margin-bottom: 2rem;
}

.summary-title {
  margin: 0 0 1rem 0;
  font-size: 1.125rem;
  font-weight: 600;
  color: #212529;
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.scores-compact {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(140px, 1fr));
  gap: 0.75rem;
}

.score-compact {
  background: white;
  border: 2px solid;
  border-radius: 8px;
  padding: 0.75rem;
  display: flex;
  align-items: center;
  gap: 0.5rem;
  transition: all 0.2s;
}

.score-compact:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 8px rgba(0, 0, 0, 0.1);
}

.score-emoji {
  font-size: 1.5rem;
}

.score-name {
  flex: 1;
  font-size: 0.875rem;
  font-weight: 500;
  color: #495057;
}

.score-num {
  font-size: 1.5rem;
  font-weight: 700;
}

/* Recommended Activities Preview */
.recommended-preview {
  background: white;
  border: 2px solid #079baa;
  border-radius: 12px;
  padding: 1.5rem;
  margin-bottom: 2rem;
}

.preview-description {
  color: #6c757d;
  font-size: 0.95rem;
  margin-bottom: 1rem;
}

.activities-preview-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(240px, 1fr));
  gap: 0.75rem;
  max-height: 300px;
  overflow-y: auto;
  padding: 0.5rem;
}

.activity-preview-card {
  background: #f8f9fa;
  border: 2px solid #dee2e6;
  border-radius: 8px;
  padding: 0.75rem;
  transition: all 0.2s;
}

.activity-preview-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 8px rgba(0, 0, 0, 0.1);
}

.activity-preview-card.vision { border-color: #ff8f00; }
.activity-preview-card.effort { border-color: #86b4f0; }
.activity-preview-card.systems { border-color: #84cc16; }
.activity-preview-card.practice { border-color: #7f31a4; }
.activity-preview-card.attitude { border-color: #f032e6; }

.preview-header {
  display: flex;
  align-items: flex-start;
  gap: 0.5rem;
  margin-bottom: 0.5rem;
}

.preview-emoji {
  font-size: 1.25rem;
}

.preview-name {
  flex: 1;
  font-size: 0.875rem;
  font-weight: 600;
  color: #212529;
  line-height: 1.3;
}

.preview-meta {
  display: flex;
  gap: 0.25rem;
  flex-wrap: wrap;
}

.preview-badge {
  font-size: 0.75rem;
  padding: 2px 6px;
  border-radius: 4px;
  background: #e9ecef;
  color: #495057;
  font-weight: 500;
}

/* Action Section */
.action-section {
  display: grid;
  grid-template-columns: 1fr auto 1fr;
  gap: 1.5rem;
  align-items: center;
}

.action-card {
  background: white;
  border: 2px solid #dee2e6;
  border-radius: 12px;
  padding: 1.5rem;
  text-align: center;
  transition: all 0.3s;
}

.action-card:hover {
  transform: translateY(-4px);
  box-shadow: 0 8px 16px rgba(0, 0, 0, 0.1);
}

.primary-action {
  border-color: #079baa;
  background: linear-gradient(135deg, #e0f7fa 0%, #b2ebf2 100%);
}

.secondary-action {
  border-color: #6c757d;
}

.action-icon {
  font-size: 3rem;
  margin-bottom: 0.75rem;
}

.action-card h3 {
  margin: 0 0 0.5rem 0;
  font-size: 1.25rem;
  font-weight: 600;
  color: #212529;
}

.action-card p {
  margin: 0 0 1.25rem 0;
  color: #6c757d;
  font-size: 0.875rem;
  line-height: 1.4;
}

.action-divider {
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 700;
  color: #6c757d;
  font-size: 1.25rem;
}

.action-divider span {
  background: white;
  padding: 0.5rem 1rem;
  border-radius: 20px;
  border: 2px solid #dee2e6;
}

.btn-large {
  padding: 0.875rem 2rem;
  font-size: 1rem;
  font-weight: 600;
  width: 100%;
}

/* Mobile Responsive */
@media (max-width: 768px) {
  .modal-title {
    font-size: 1.5rem;
  }
  
  .welcome-icon {
    font-size: 2rem;
  }
  
  .action-section {
    grid-template-columns: 1fr;
    gap: 1rem;
  }
  
  .action-divider {
    transform: rotate(90deg);
  }
  
  .scores-compact {
    grid-template-columns: repeat(2, 1fr);
  }
  
  .activities-preview-grid {
    grid-template-columns: 1fr;
  }
}
</style>

