<template>
  <div class="activity-card card" :class="{ 'completed': isCompleted, 'in-progress': isInProgress }">
    <div class="card-header">
      <div class="category-badge" :style="{ backgroundColor: categoryColor }">
        {{ activity.vespa_category }}
      </div>
      <div class="card-actions">
        <button v-if="isAssigned" @click="$emit('remove-activity', activity.id)" class="btn-icon" title="Remove">
          ✕
        </button>
      </div>
    </div>
    
    <h3 class="activity-name">{{ activity.name }}</h3>
    
    <div class="activity-meta">
      <span class="meta-item">⏱️ {{ activity.time_minutes || 'N/A' }} min</span>
      <span class="meta-item">📊 {{ activity.level }}</span>
      <span v-if="activity.difficulty" class="meta-item">
        Difficulty: {{ '⭐'.repeat(activity.difficulty) }}
      </span>
    </div>
    
    <div v-if="progress" class="progress-indicator">
      <div class="progress-bar">
        <div 
          class="progress-fill" 
          :style="{ width: progressPercentage + '%' }"
        ></div>
      </div>
      <span class="progress-text">{{ progressStatusText }}</span>
    </div>
    
    <div v-if="progress?.staff_feedback" class="feedback-badge">
      💬 Feedback Available
    </div>
    
    <div class="card-footer">
      <button 
        v-if="!progress || progress.status === 'assigned'"
        @click="$emit('start-activity', activity)"
        class="btn btn-primary"
      >
        Start Activity
      </button>
      <button 
        v-else-if="progress.status === 'in_progress'"
        @click="$emit('start-activity', activity)"
        class="btn btn-secondary"
      >
        Continue Activity
      </button>
      <button 
        v-else-if="progress.status === 'completed'"
        @click="$emit('view-feedback', activity)"
        class="btn btn-outline"
      >
        View Feedback
      </button>
    </div>
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
  }
});

defineEmits(['start-activity', 'remove-activity', 'view-feedback']);

const categoryColor = computed(() => {
  return CATEGORY_COLORS[props.activity.vespa_category] || '#079baa';
});

const isCompleted = computed(() => {
  return props.progress?.status === 'completed';
});

const isInProgress = computed(() => {
  return props.progress?.status === 'in_progress';
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
  transition: transform 0.2s, box-shadow 0.2s;
  position: relative;
}

.activity-card:hover {
  transform: translateY(-2px);
  box-shadow: var(--shadow-md);
}

.activity-card.completed {
  border-left: 4px solid #4caf50;
}

.activity-card.in-progress {
  border-left: 4px solid var(--primary);
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: var(--spacing-sm);
}

.category-badge {
  padding: 4px 12px;
  border-radius: 12px;
  color: white;
  font-size: 12px;
  font-weight: 600;
  text-transform: uppercase;
}

.card-actions {
  display: flex;
  gap: var(--spacing-xs);
}

.btn-icon {
  background: none;
  border: none;
  font-size: 18px;
  cursor: pointer;
  color: var(--dark-gray);
  padding: 4px;
  width: 24px;
  height: 24px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 4px;
  transition: background 0.2s;
}

.btn-icon:hover {
  background: var(--gray);
}

.activity-name {
  font-size: 1.25rem;
  margin-bottom: var(--spacing-sm);
  color: var(--dark-blue);
}

.activity-meta {
  display: flex;
  flex-wrap: wrap;
  gap: var(--spacing-sm);
  margin-bottom: var(--spacing-md);
  font-size: 0.875rem;
  color: var(--dark-gray);
}

.meta-item {
  display: flex;
  align-items: center;
  gap: 4px;
}

.progress-indicator {
  margin-bottom: var(--spacing-md);
}

.progress-bar {
  height: 8px;
  background: var(--gray);
  border-radius: 4px;
  overflow: hidden;
  margin-bottom: var(--spacing-xs);
}

.progress-fill {
  height: 100%;
  background: var(--primary);
  transition: width 0.3s;
}

.progress-text {
  font-size: 0.75rem;
  color: var(--dark-gray);
  font-weight: 500;
}

.feedback-badge {
  background: #fff3cd;
  color: #856404;
  padding: var(--spacing-xs) var(--spacing-sm);
  border-radius: var(--radius-sm);
  font-size: 0.875rem;
  margin-bottom: var(--spacing-md);
  text-align: center;
}

.card-footer {
  margin-top: var(--spacing-md);
  padding-top: var(--spacing-md);
  border-top: 1px solid var(--gray);
}

.card-footer .btn {
  width: 100%;
  justify-content: center;
}
</style>

