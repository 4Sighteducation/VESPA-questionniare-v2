<template>
  <div 
    class="activity-card" 
    :class="{ 
      'completed': isCompleted, 
      'prescribed': isAssigned,
      'has-notification': hasUnreadFeedback || isNewlyAssigned 
    }"
    :data-activity-id="activity.id"
  >
    <div class="card-glow" :style="{ background: categoryColor }"></div>
    
    <!-- Notification Indicators -->
    <div v-if="hasUnreadFeedback" class="notification-badge feedback-badge" title="You have new feedback!">
      <span class="badge-icon">💬</span>
      <span class="badge-pulse"></span>
    </div>
    <div v-else-if="isNewlyAssigned" class="notification-badge new-badge" title="Newly assigned!">
      <span class="badge-icon">✨</span>
    </div>
    
    <!-- Delete Button (only for assigned activities) -->
    <button 
      v-if="isAssigned && !isCompleted" 
      @click.stop="$emit('remove-activity', activity.id)" 
      class="activity-delete-btn" 
      title="Remove activity"
    >
      ×
    </button>
    
    <div class="card-header">
      <span class="category-chip" :style="{ background: `${categoryColor}20`, color: categoryColor }">
        {{ getCategoryEmoji(activity.vespa_category) }} {{ activity.vespa_category }}
      </span>
      <span class="level-chip">{{ activity.level }}</span>
      <span class="points-chip">+{{ basePoints }} pts</span>
    </div>
    
    <h3 class="activity-name">{{ activity.name }}</h3>
    
    <!-- Time and Difficulty -->
    <div class="activity-meta">
      <span class="meta-item">⏱️ {{ activity.time_minutes || 30 }} min</span>
      <span class="meta-item" :class="`level-${activity.level?.replace(' ', '-').toLowerCase()}`">
        📊 {{ activity.level || 'Level 2' }}
      </span>
    </div>
    
    <!-- Difficulty Stars -->
    <div v-if="activity.difficulty" class="difficulty-indicator">
      <span class="difficulty-label">Difficulty:</span>
      <span class="difficulty-stars">{{ '⭐'.repeat(Math.min(activity.difficulty || 1, 5)) }}</span>
    </div>
    
    <div class="card-footer">
      <button 
        v-if="!progress || progress.status === 'assigned'"
        @click.stop="$emit('start-activity', activity)"
        class="start-activity-btn"
        :style="{ background: categoryColor }"
      >
        Start Activity <span class="arrow">→</span>
      </button>
      <button 
        v-else-if="progress.status === 'in_progress'"
        @click.stop="$emit('start-activity', activity)"
        class="start-activity-btn in-progress"
        :style="{ background: categoryColor }"
      >
        Continue <span class="arrow">→</span>
      </button>
      <button 
        v-else-if="progress.status === 'completed'"
        @click.stop="$emit('start-activity', activity)"
        class="review-activity-btn"
      >
        Review Work <span class="arrow">👁️</span>
      </button>
    </div>
    
    <div class="card-hover-effect"></div>
  </div>
</template>

<script setup>
import { computed } from 'vue';
import { CATEGORY_COLORS } from '../../shared/constants';

const props = defineProps({
  activity: {
    type: Object,
    required: true
  },
  progress: {
    type: Object,
    default: null
  },
  isAssigned: {
    type: Boolean,
    default: false
  },
  hasFeedback: {
    type: Boolean,
    default: false
  },
  isNewlyAssigned: {
    type: Boolean,
    default: false
  }
});

defineEmits(['start-activity', 'remove-activity', 'view-feedback']);

// Check for unread feedback
const hasUnreadFeedback = computed(() => {
  return props.progress?.staff_feedback && !props.progress?.feedback_read_by_student;
});

const categoryColor = computed(() => {
  return CATEGORY_COLORS[props.activity.vespa_category] || '#079baa';
});

const categoryEmojis = {
  'Vision': '👁️',
  'Effort': '💪',
  'Systems': '⚙️',
  'Practice': '🎯',
  'Attitude': '🧠'
};

const getCategoryEmoji = (category) => {
  return categoryEmojis[category] || '📚';
};

const isCompleted = computed(() => {
  return props.progress?.status === 'completed';
});

const isInProgress = computed(() => {
  return props.progress?.status === 'in_progress';
});

const basePoints = computed(() => {
  return props.activity.level === 'Level 3' ? 15 : 10;
});

const progressPercentage = computed(() => {
  if (!props.progress) return 0;
  if (props.progress.status === 'completed') return 100;
  if (props.progress.status === 'in_progress') return 50;
  return 0;
});

const progressStatusText = computed(() => {
  if (!props.progress) return 'Not Started';
  switch (props.progress.status) {
    case 'completed':
      return 'Completed';
    case 'in_progress':
      return 'In Progress';
    case 'assigned':
      return 'Assigned';
    default:
      return 'Not Started';
  }
});
</script>

<style scoped>
.activity-card {
  background: var(--white);
  border-radius: 20px;
  padding: 1.5rem;
  position: relative;
  overflow: hidden;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
  transition: all 0.3s;
  cursor: pointer;
  border: 2px solid transparent;
}

.activity-card:hover {
  transform: translateY(-5px) scale(1.02);
  box-shadow: 0 12px 40px rgba(0, 0, 0, 0.2);
}

.activity-card.prescribed {
  border-color: var(--primary);
}

.activity-card.completed {
  position: relative;
  background: linear-gradient(135deg, #f0f9eb 0%, #e8f5e0 100%);
  border: 2px solid #72cb44;
  box-shadow: 0 2px 8px rgba(114, 203, 68, 0.15);
}

.activity-card.completed:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(114, 203, 68, 0.2);
}

.activity-card.completed::before {
  content: '';
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  height: 4px;
  background: linear-gradient(90deg, #72cb44 0%, #5cb030 100%);
  border-radius: 18px 18px 0 0;
}

.activity-card.completed::after {
  content: '✓ COMPLETED';
  position: absolute;
  top: 12px;
  right: 12px;
  background: linear-gradient(135deg, #72cb44 0%, #5cb030 100%);
  color: white;
  padding: 6px 14px;
  border-radius: 20px;
  font-size: 0.75rem;
  font-weight: 700;
  z-index: 10;
  box-shadow: 0 2px 6px rgba(114, 203, 68, 0.3);
}

.card-glow {
  position: absolute;
  top: -2px;
  left: -2px;
  right: -2px;
  bottom: -2px;
  background: inherit;
  border-radius: 20px;
  opacity: 0.1;
  filter: blur(10px);
  z-index: -1;
}

.activity-card.completed .card-glow {
  display: none;
}

/* Delete Button */
.activity-delete-btn {
  position: absolute;
  top: 10px;
  right: 10px;
  width: 28px;
  height: 28px;
  border-radius: 50%;
  background: rgba(255, 255, 255, 0.9);
  border: 1px solid #e9ecef;
  color: #dc3545;
  font-size: 20px;
  font-weight: bold;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  opacity: 0;
  transition: all 0.2s;
  z-index: 10;
  line-height: 1;
  padding: 0;
}

.activity-card:hover .activity-delete-btn {
  opacity: 1;
}

.activity-delete-btn:hover {
  background: #dc3545;
  color: white;
  transform: scale(1.1);
}

/* Notification Badges */
.notification-badge {
  position: absolute;
  top: -8px;
  right: -8px;
  width: 32px;
  height: 32px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 15;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.2);
}

.feedback-badge {
  background: linear-gradient(135deg, #dc3545 0%, #c82333 100%);
}

.new-badge {
  background: linear-gradient(135deg, #079baa 0%, #057a87 100%);
}

.badge-icon {
  font-size: 16px;
  z-index: 2;
}

.badge-pulse {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  border-radius: 50%;
  background: inherit;
  animation: pulse-ring 1.5s infinite;
}

@keyframes pulse-ring {
  0% {
    transform: scale(1);
    opacity: 0.8;
  }
  50% {
    transform: scale(1.3);
    opacity: 0.3;
  }
  100% {
    transform: scale(1.5);
    opacity: 0;
  }
}

.activity-card.has-notification {
  border: 2px solid #dc3545;
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1rem;
  flex-wrap: wrap;
  gap: 0.5rem;
}

.category-chip {
  padding: 4px 12px;
  border-radius: 20px;
  font-size: 12px;
  font-weight: 600;
  text-transform: capitalize;
  display: flex;
  align-items: center;
  gap: 4px;
}

.level-chip {
  padding: 4px 10px;
  border-radius: 12px;
  font-size: 11px;
  font-weight: 600;
  text-transform: uppercase;
  background: #e9ecef;
  color: #495057;
}

.points-chip {
  background: #f8f9fa;
  color: #495057;
  padding: 0.375rem 0.75rem;
  border-radius: 20px;
  font-size: 0.875rem;
  font-weight: 600;
}

.activity-name {
  font-size: 1.25rem;
  font-weight: 700;
  color: var(--dark-blue);
  margin: 0 0 1rem 0;
  line-height: 1.3;
}

.activity-meta {
  display: flex;
  gap: 1rem;
  margin-bottom: 0.75rem;
  font-size: 0.875rem;
  color: #6c757d;
}

.meta-item {
  display: flex;
  align-items: center;
  gap: 4px;
}

.difficulty-indicator {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  margin-bottom: 1rem;
  font-size: 0.875rem;
}

.difficulty-label {
  color: #6c757d;
  font-weight: 500;
}

.difficulty-stars {
  font-size: 1rem;
}

.card-footer {
  display: flex;
  justify-content: flex-end;
  gap: 0.5rem;
  margin-top: 1rem;
}

.start-activity-btn {
  padding: 0.75rem 1.5rem;
  border: none;
  border-radius: 12px;
  color: var(--white);
  font-size: 1rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.3s;
  display: flex;
  align-items: center;
  gap: 0.5rem;
  flex: 1;
  justify-content: center;
}

.start-activity-btn:hover {
  transform: translateX(5px);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
}

.arrow {
  transition: transform 0.3s;
}

.start-activity-btn:hover .arrow {
  transform: translateX(5px);
}

.review-activity-btn {
  padding: 0.75rem 1.5rem;
  border: 2px solid #72cb44;
  background: linear-gradient(135deg, #f8fff5 0%, #e8f5e0 100%);
  border-radius: 12px;
  color: #3d8c21;
  font-size: 1rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.3s;
  display: flex;
  align-items: center;
  gap: 0.5rem;
  flex: 1;
  justify-content: center;
}

.review-activity-btn:hover {
  background: linear-gradient(135deg, #e8f5e0 0%, #d4edc8 100%);
  border-color: #5cb030;
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(114, 203, 68, 0.2);
}

.review-activity-btn .arrow {
  font-size: 1.1rem;
  transition: transform 0.3s;
}

.card-hover-effect {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: radial-gradient(circle at 50% 50%, rgba(255, 255, 255, 0.1) 0%, transparent 50%);
  pointer-events: none;
  opacity: 0;
  transition: opacity 0.3s;
}

.activity-card:hover .card-hover-effect {
  opacity: 1;
}

@media (max-width: 768px) {
  .activity-card {
    padding: 1rem;
  }
  
  .activity-name {
    font-size: 1.1rem;
  }
  
  .card-header {
    flex-wrap: wrap;
  }
  
  .start-activity-btn,
  .redo-activity-btn {
    font-size: 0.875rem;
    padding: 0.5rem 1rem;
  }
}
</style>

