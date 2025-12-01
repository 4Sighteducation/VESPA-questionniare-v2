<template>
  <div
    :class="['compact-activity-card', categoryClass, levelClass, {
      'completed': isCompleted,
      'in-progress': isInProgress,
      'has-feedback': hasUnreadFeedback,
      'dragging': isDragging
    }]"
    :draggable="draggable"
    @dragstart="handleDragStart"
    @dragend="handleDragEnd"
    @click.stop="handleClick"
    :title="activityName"
  >
    <!-- Source Indicator - Only ONE indicator per card -->
    <span v-if="hasUnreadFeedback" class="source-circle feedback pulse" title="Unread feedback from staff"></span>
    <span v-else-if="isAssigned && sourceType" class="source-circle" :class="sourceType" :title="sourceTitle"></span>
    
    <!-- Activity Name -->
    <span class="activity-text">{{ activityName }}</span>
    
    <!-- Remove Button (for assigned activities) -->
    <button
      v-if="isAssigned"
      class="btn-remove-compact"
      @click.stop="$emit('remove')"
      title="Remove"
    >
      ×
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
  // Check both completed_at and status field
  if (props.isAssigned) {
    return props.activity.status === 'completed' || !!props.activity.completed_at;
  }
  return false;
});

const hasUnreadFeedback = computed(() => {
  if (!props.isAssigned) return false;
  return props.activity.staff_feedback && !props.activity.feedback_read_by_student;
});

const isInProgress = computed(() => {
  if (!props.isAssigned) return false;
  return props.activity.status === 'in_progress' && !props.activity.completed_at;
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
  console.log('🖱️ Drag started:', activityName.value);
};

const handleDragEnd = () => {
  isDragging.value = false;
};

const handleClick = (event) => {
  console.log('🖱️ ActivityCardCompact clicked:', activityName.value);
  console.log('🖱️ Activity data:', props.activity);
  console.log('🖱️ Is assigned:', props.isAssigned);
  
  // Prevent event from bubbling to parent drag handlers
  event.stopPropagation();
  
  // Emit click event to parent
  emit('click', props.activity);
};
</script>

<style scoped>
/* Compact Activity Card - Smaller & Cleaner */
.compact-activity-card {
  padding: 4px 6px;  /* Reduced padding */
  border-radius: 5px;
  font-size: 11px;  /* Smaller text */
  font-weight: 500;
  color: white;
  cursor: pointer;
  position: relative;
  transition: all 0.2s;
  display: flex;
  align-items: center;
  gap: 3px;  /* Tighter gap */
  min-height: 24px;  /* Reduced from 28px */
  white-space: nowrap;
  overflow: hidden;
  pointer-events: auto !important;
  z-index: 1;
  border: 1px solid transparent;
}

/* Category Colors - IN-PROGRESS (full bright colors) */
.compact-activity-card.in-progress.vision { background: #ff8f00; }
.compact-activity-card.in-progress.effort { background: #86b4f0; }
.compact-activity-card.in-progress.systems { background: #84cc16; }
.compact-activity-card.in-progress.practice { background: #7f31a4; }
.compact-activity-card.in-progress.attitude { background: #f032e6; }

/* Level Variations - IN-PROGRESS */
.compact-activity-card.in-progress.level-level2.vision { background: #ffb366; }
.compact-activity-card.in-progress.level-level3.vision { background: #ff9933; }
.compact-activity-card.in-progress.level-level2.effort { background: #a6c8f0; }
.compact-activity-card.in-progress.level-level3.effort { background: #86b4f0; }
.compact-activity-card.in-progress.level-level2.systems { background: #99e066; }
.compact-activity-card.in-progress.level-level3.systems { background: #72cb44; }
.compact-activity-card.in-progress.level-level2.practice { background: #b366cc; }
.compact-activity-card.in-progress.level-level3.practice { background: #9952b8; }
.compact-activity-card.in-progress.level-level2.attitude { background: #ff66e6; }
.compact-activity-card.in-progress.level-level3.attitude { background: #f032e6; }

/* COMPLETED State - Clean grey (no overlapping) */
.compact-activity-card.completed {
  background: #e9ecef !important;  /* Solid grey - no transparency issues */
  color: #6c757d !important;
  border: 1px solid #ced4da !important;
  cursor: pointer !important;
  opacity: 1 !important;  /* No opacity - prevents overlapping */
}

.compact-activity-card.completed .activity-text {
  color: #6c757d !important;
  font-weight: 500 !important;
}

.compact-activity-card.completed:hover {
  background: #dee2e6 !important;
  border-color: #adb5bd !important;
}

/* DEFAULT State (not assigned yet) - Lighter colors */
.compact-activity-card:not(.in-progress):not(.completed).vision { background: #ffcc80; }
.compact-activity-card:not(.in-progress):not(.completed).effort { background: #b3d4f5; }
.compact-activity-card:not(.in-progress):not(.completed).systems { background: #b3e680; }
.compact-activity-card:not(.in-progress):not(.completed).practice { background: #c580d9; }
.compact-activity-card:not(.in-progress):not(.completed).attitude { background: #ff99f0; }

.compact-activity-card:hover {
  transform: translateY(-1px);
  box-shadow: 0 3px 8px rgba(0,0,0,0.2);
  filter: brightness(1.05);
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

/* Status shown by card color instead of badges */
/* Bright colors = In Progress | Grey = Completed | Light = Available */

/* Source Circle Indicators */
.source-circle {
  width: 8px;  /* Smaller indicator */
  height: 8px;
  border-radius: 50%;
  border: 1.5px solid white;
  box-shadow: 0 1px 2px rgba(0,0,0,0.2);
  flex-shrink: 0;
}

.source-circle.questionnaire {
  background: #28a745;  /* Green = Questionnaire */
}

.source-circle.student {
  background: #007bff;  /* Blue = Student choice */
}

.source-circle.staff {
  background: #6f42c1;  /* Purple = Staff assigned */
}

.source-circle.feedback {
  background: #dc3545;  /* Red = Unread feedback */
}

/* Pulse animation for unread feedback */
.source-circle.pulse {
  animation: pulse 2s infinite;
}

@keyframes pulse {
  0%, 100% { opacity: 1; transform: scale(1); }
  50% { opacity: 0.7; transform: scale(1.2); }
}

/* Action Buttons - Inline compact */
.btn-remove-compact,
.btn-add-compact {
  width: 16px;
  height: 16px;
  min-width: 16px;
  border-radius: 3px;
  border: none;
  background: rgba(255,255,255,0.3);
  color: white;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 13px;
  font-weight: 700;
  line-height: 1;
  opacity: 0.7;
  transition: all 0.2s;
  flex-shrink: 0;
  margin-left: auto;
}

.compact-activity-card:hover .btn-remove-compact,
.compact-activity-card:hover .btn-add-compact {
  opacity: 1;
  background: rgba(255,255,255,0.9);
  color: #333;
}

.btn-remove-compact:hover {
  background: #ef4444 !important;
  color: white !important;
  transform: scale(1.15);
}

.btn-add-compact:hover {
  background: #10b981 !important;
  color: white !important;
  transform: scale(1.15);
}

/* Responsive - smaller screens */
@media (max-width: 1400px) {
  .compact-activity-card {
    font-size: 10px;
    min-height: 22px;
    padding: 3px 5px;
  }
  
  .source-circle {
    width: 7px;
    height: 7px;
  }
  
  .btn-remove-compact,
  .btn-add-compact {
    width: 14px;
    height: 14px;
    font-size: 11px;
  }
}
</style>

