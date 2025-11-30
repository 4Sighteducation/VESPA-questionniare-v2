<template>
  <div
    :class="['activity-card', categoryClass, {
      'completed': isCompleted,
      'has-feedback': hasUnreadFeedback
    }]"
    @click="$emit('click')"
  >
    <!-- Status Indicators -->
    <div class="card-indicators">
      <span
        v-if="activity.selected_via === 'questionnaire'"
        class="source-indicator questionnaire"
        title="Added via questionnaire"
      >
        <i class="fas fa-file-alt"></i>
      </span>
      <span
        v-else-if="activity.selected_via === 'staff_assigned'"
        class="source-indicator staff"
        title="Staff assigned"
      >
        <i class="fas fa-user-tie"></i>
      </span>
      <span
        v-else
        class="source-indicator student"
        title="Student choice"
      >
        <i class="fas fa-user"></i>
      </span>

      <span
        v-if="hasUnreadFeedback"
        class="feedback-indicator"
        title="Unread feedback"
      >
        <i class="fas fa-comment-dots"></i>
      </span>

      <span
        v-if="isCompleted"
        class="completion-indicator"
        title="Completed"
      >
        <i class="fas fa-check"></i>
      </span>
    </div>

    <!-- Activity Content -->
    <div class="card-content">
      <h4 class="activity-name">{{ activity.activities?.name }}</h4>
      
      <div class="activity-meta">
        <span class="level-badge">
          {{ activity.activities?.level }}
        </span>
        <span v-if="activity.activities?.time_minutes" class="time-badge">
          <i class="fas fa-clock"></i> {{ activity.activities.time_minutes }}m
        </span>
      </div>

      <div v-if="isCompleted && activity.completed_at" class="completion-info">
        <i class="fas fa-check-circle"></i>
        Completed {{ formatDate(activity.completed_at) }}
      </div>

      <div v-if="activity.staff_feedback" class="feedback-preview">
        <i class="fas fa-comment"></i>
        <span class="feedback-text">{{ feedbackPreview }}</span>
      </div>
    </div>

    <!-- Actions -->
    <div class="card-actions" @click.stop>
      <button
        v-if="isAssigned"
        class="btn-action btn-remove"
        @click="$emit('remove')"
        title="Remove activity"
      >
        <i class="fas fa-times"></i>
      </button>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue';

const props = defineProps({
  activity: {
    type: Object,
    required: true
  },
  student: {
    type: Object,
    required: true
  },
  isAssigned: {
    type: Boolean,
    default: false
  }
});

defineEmits(['click', 'remove']);

const isCompleted = computed(() => !!props.activity.completed_at);

const hasUnreadFeedback = computed(() => {
  return props.activity.staff_feedback && !props.activity.feedback_read_by_student;
});

const categoryClass = computed(() => {
  return props.activity.activities?.vespa_category?.toLowerCase() || '';
});

const feedbackPreview = computed(() => {
  if (!props.activity.staff_feedback) return '';
  const text = props.activity.staff_feedback;
  return text.length > 50 ? text.substring(0, 50) + '...' : text;
});

const formatDate = (dateString) => {
  if (!dateString) return '';
  const date = new Date(dateString);
  return date.toLocaleDateString('en-GB', { 
    day: 'numeric', 
    month: 'short',
    year: 'numeric'
  });
};
</script>

<style scoped>
.activity-card {
  background: white;
  border: 2px solid #e2e8f0;
  border-radius: 8px;
  padding: 10px;
  cursor: pointer;
  transition: all 0.2s;
  position: relative;
  font-size: 13px;
}

.activity-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(0,0,0,0.12);
}

.activity-card.completed {
  background: linear-gradient(135deg, #dcfce7 0%, #bbf7d0 100%);
  border-color: #22c55e;
}

.activity-card.has-feedback {
  border-left-width: 4px;
  border-left-color: #dc3545;
}

.activity-card.vision {
  border-top-color: #ff8f00;
}

.activity-card.effort {
  border-top-color: #86b4f0;
}

.activity-card.systems {
  border-top-color: #84cc16;
}

.activity-card.practice {
  border-top-color: #7f31a4;
}

.activity-card.attitude {
  border-top-color: #f032e6;
}

.card-indicators {
  display: flex;
  gap: 6px;
  margin-bottom: 8px;
  flex-wrap: wrap;
}

.source-indicator,
.feedback-indicator,
.completion-indicator {
  width: 20px;
  height: 20px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 10px;
  color: white;
}

.source-indicator.questionnaire {
  background: #1e7e34;
}

.source-indicator.staff {
  background: #6f42c1;
}

.source-indicator.student {
  background: #007bff;
}

.feedback-indicator {
  background: #dc3545;
  animation: pulse 2s infinite;
}

.completion-indicator {
  background: #22c55e;
}

@keyframes pulse {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.6; }
}

.card-content {
  margin-bottom: 8px;
}

.activity-name {
  font-size: 13px;
  font-weight: 600;
  color: #212529;
  margin: 0 0 6px 0;
  line-height: 1.3;
}

.activity-meta {
  display: flex;
  gap: 4px;
  margin-bottom: 6px;
  flex-wrap: wrap;
}

.level-badge,
.time-badge {
  padding: 2px 8px;
  border-radius: 12px;
  font-size: 11px;
  font-weight: 500;
}

.level-badge {
  background: #e9ecef;
  color: #495057;
}

.time-badge {
  background: #e3f2fd;
  color: #0d47a1;
  display: flex;
  align-items: center;
  gap: 4px;
}

.completion-info {
  font-size: 12px;
  color: #15803d;
  display: flex;
  align-items: center;
  gap: 4px;
  margin-top: 8px;
}

.feedback-preview {
  margin-top: 8px;
  padding: 8px;
  background: #fef3c7;
  border-radius: 6px;
  font-size: 12px;
  color: #92400e;
  display: flex;
  gap: 6px;
}

.feedback-text {
  flex: 1;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.card-actions {
  display: flex;
  justify-content: flex-end;
  gap: 6px;
  margin-top: 8px;
}

.btn-action {
  width: 24px;
  height: 24px;
  border-radius: 50%;
  border: none;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  transition: all 0.2s;
  font-size: 12px;
}

.btn-remove {
  background: #fee;
  color: #dc3545;
}

.btn-remove:hover {
  background: #dc3545;
  color: white;
}
</style>

