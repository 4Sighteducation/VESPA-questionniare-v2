<template>
  <div
    :class="['compact-activity-card', categoryClass, levelClass, {
      'completed': isCompleted,
      'has-feedback': hasUnreadFeedback,
      'dragging': isDragging
    }]"
    :draggable="draggable"
    @dragstart="handleDragStart"
    @dragend="handleDragEnd"
    @click="handleClick"
    :title="activityName"
  >
    <!-- Completion Indicator -->
    <span v-if="isCompleted" class="completion-flag">✓</span>
    
    <!-- Source Indicator -->
    <span v-if="isAssigned && sourceType" class="source-circle" :class="sourceType" :title="sourceTitle"></span>
    
    <!-- Feedback Indicator -->
    <span v-if="hasUnreadFeedback" class="source-circle feedback" title="Unread feedback"></span>
    
    <!-- Activity Name -->
    <span class="activity-text">{{ activityName }}</span>
    
    <!-- Remove Button (for assigned activities) -->
    <button
      v-if="isAssigned"
      class="btn-remove-compact"
      @click.stop="$emit('remove')"
      title="Remove"
    >
      −
    </button>
    
    <!-- Add Button (for available activities) -->
    <button
      v-else
      class="btn-add-compact"
      @click.stop="handleClick"
      title="Add to student"
    >
      +
    </button>
  </div>
</template>

<script setup>
import { ref, computed } from 'vue';

const props = defineProps({
  activity: {
    type: Object,
    required: true
  },
  isAssigned: {
    type: Boolean,
    default: false
  },
  draggable: {
    type: Boolean,
    default: true
  }
});

const emit = defineEmits(['click', 'remove', 'dragstart']);

const isDragging = ref(false);

// Computed
const activityName = computed(() => {
  if (props.isAssigned) {
    return props.activity.activities?.name || 'Unnamed Activity';
  }
  return props.activity.name || 'Unnamed Activity';
});

const categoryClass = computed(() => {
  if (props.isAssigned) {
    return props.activity.activities?.vespa_category?.toLowerCase() || '';
  }
  return props.activity.vespa_category?.toLowerCase() || '';
});

const levelClass = computed(() => {
  let level = '';
  if (props.isAssigned) {
    level = props.activity.activities?.level || '';
  } else {
    level = props.activity.level || '';
  }
  
  if (level === 'Level 2') return 'level-level2';
  if (level === 'Level 3') return 'level-level3';
  return '';
});

const isCompleted = computed(() => {
  return !!props.activity.completed_at;
});

const hasUnreadFeedback = computed(() => {
  return props.activity.staff_feedback && !props.activity.feedback_read_by_student;
});

const sourceType = computed(() => {
  if (!props.isAssigned) return null;
  
  const selectedVia = props.activity.selected_via;
  if (selectedVia === 'staff_assigned') return 'staff';
  if (selectedVia === 'student_choice') return 'student';
  return 'questionnaire';
});

const sourceTitle = computed(() => {
  const titles = {
    'questionnaire': 'Added via questionnaire',
    'staff': 'Staff assigned',
    'student': 'Student choice'
  };
  return titles[sourceType.value] || '';
});

// Methods
const handleDragStart = (event) => {
  isDragging.value = true;
  emit('dragstart', event, props.activity);
};

const handleDragEnd = () => {
  isDragging.value = false;
};

const handleClick = () => {
  emit('click', props.activity);
};
</script>

<style scoped>
/* Compact Activity Card - Draggable Workspace Style */
.compact-activity-card {
  padding: 6px 8px;
  border-radius: 6px;
  font-size: 12px;
  font-weight: 500;
  color: white;
  cursor: pointer;
  position: relative;
  transition: all 0.2s;
  display: flex;
  align-items: center;
  gap: 4px;
  min-height: 28px;
  white-space: nowrap;
  overflow: hidden;
}

/* Category Colors */
.compact-activity-card.vision { background: #ff8f00; }
.compact-activity-card.effort { background: #86b4f0; }
.compact-activity-card.systems { background: #84cc16; }
.compact-activity-card.practice { background: #7f31a4; }
.compact-activity-card.attitude { background: #f032e6; }

/* Level Variations */
.compact-activity-card.level-level2.vision {
  background: #ffb366;
}
.compact-activity-card.level-level3.vision {
  background: #ff9933;
}

.compact-activity-card.level-level2.effort {
  background: #a6c8f0;
}
.compact-activity-card.level-level3.effort {
  background: #86b4f0;
}

.compact-activity-card.level-level2.systems {
  background: #99e066;
}
.compact-activity-card.level-level3.systems {
  background: #72cb44;
}

.compact-activity-card.level-level2.practice {
  background: #b366cc;
}
.compact-activity-card.level-level3.practice {
  background: #9952b8;
}

.compact-activity-card.level-level2.attitude {
  background: #ff66e6;
}
.compact-activity-card.level-level3.attitude {
  background: #f032e6;
}

/* Completed State */
.compact-activity-card.completed {
  background: rgba(108, 117, 125, 0.3) !important;
  opacity: 0.7 !important;
  color: #495057 !important;
  border: 2px solid rgba(108, 117, 125, 0.5) !important;
}

.compact-activity-card.completed .activity-text {
  padding-left: 20px;
  color: #343a40 !important;
  font-weight: 700 !important;
}

.compact-activity-card:hover {
  transform: translateX(2px);
  box-shadow: 0 2px 6px rgba(0,0,0,0.15);
}

.compact-activity-card.dragging {
  opacity: 0.5;
  transform: rotate(2deg);
}

/* Activity Text */
.activity-text {
  flex: 1;
  overflow: hidden;
  text-overflow: ellipsis;
}

/* Completion Flag */
.completion-flag {
  position: absolute;
  left: 4px;
  top: 50%;
  transform: translateY(-50%);
  width: 16px;
  height: 16px;
  background: white;
  color: #16a34a;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 10px;
  font-weight: bold;
}

/* Source Circle Indicators */
.source-circle {
  position: absolute;
  width: 12px;
  height: 12px;
  border-radius: 50%;
  border: 2px solid white;
  box-shadow: 0 1px 3px rgba(0,0,0,0.2);
  z-index: 2;
}

.source-circle.questionnaire {
  background: #1e7e34;
  top: 4px;
  left: 4px;
}

.source-circle.student {
  background: #007bff;
  top: 4px;
  left: 4px;
}

.source-circle.staff {
  background: #6f42c1;
  top: 4px;
  left: 4px;
}

.source-circle.feedback {
  background: #dc3545;
  top: 4px;
  left: 18px;
}

/* Action Buttons */
.btn-remove-compact,
.btn-add-compact {
  position: absolute;
  right: 4px;
  top: 50%;
  transform: translateY(-50%);
  width: 20px;
  height: 20px;
  border-radius: 50%;
  border: none;
  background: rgba(255,255,255,0.9);
  color: #333;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 14px;
  font-weight: bold;
  transition: all 0.2s;
  opacity: 0;
}

.compact-activity-card:hover .btn-remove-compact,
.compact-activity-card:hover .btn-add-compact {
  opacity: 1;
}

.btn-remove-compact:hover {
  background: #ef4444;
  color: white;
  transform: translateY(-50%) scale(1.1);
}

.btn-add-compact:hover {
  background: #10b981;
  color: white;
  transform: translateY(-50%) scale(1.1);
}
</style>

