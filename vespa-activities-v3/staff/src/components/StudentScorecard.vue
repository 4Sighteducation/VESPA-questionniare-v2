<template>
  <div class="scorecard" :class="{'compact': compact}">
    <div class="scorecard-header">
      <i class="fas fa-chart-line"></i>
      <span>{{ compact ? 'Progress' : 'Activity Progress' }}</span>
    </div>
    
    <div class="scorecard-stats">
      <div class="stat-item completed">
        <div class="stat-number">{{ stats.completed }}</div>
        <div class="stat-label">Completed</div>
      </div>
      
      <div class="stat-item in-progress">
        <div class="stat-number">{{ stats.inProgress }}</div>
        <div class="stat-label">In Progress</div>
      </div>
      
      <div class="stat-item assigned">
        <div class="stat-number">{{ stats.total }}</div>
        <div class="stat-label">Total</div>
      </div>
      
      <div class="stat-item rate">
        <div class="stat-number">{{ completionRate }}%</div>
        <div class="stat-label">Complete</div>
      </div>
    </div>
    
    <div v-if="!compact && showWeekly" class="weekly-stats">
      <div class="weekly-label">This Week:</div>
      <div class="weekly-number">{{ weeklyCompleted }} completed</div>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue';

const props = defineProps({
  activities: {
    type: Array,
    default: () => []
  },
  compact: {
    type: Boolean,
    default: false
  },
  showWeekly: {
    type: Boolean,
    default: false
  }
});

const stats = computed(() => {
  const activities = props.activities || [];
  return {
    total: activities.filter(a => a.status !== 'removed').length,
    completed: activities.filter(a => a.status === 'completed').length,
    inProgress: activities.filter(a => a.status === 'in_progress').length
  };
});

const completionRate = computed(() => {
  if (stats.value.total === 0) return 0;
  return Math.round((stats.value.completed / stats.value.total) * 100);
});

const weeklyCompleted = computed(() => {
  if (!props.showWeekly) return 0;
  
  const oneWeekAgo = new Date();
  oneWeekAgo.setDate(oneWeekAgo.getDate() - 7);
  
  return (props.activities || []).filter(a => {
    if (!a.completed_at) return false;
    const completedDate = new Date(a.completed_at);
    return completedDate >= oneWeekAgo;
  }).length;
});
</script>

<style scoped>
.scorecard {
  background: linear-gradient(135deg, #079baa 0%, #00b4cc 100%);
  border-radius: 12px;
  padding: 16px;
  color: white;
  box-shadow: 0 4px 12px rgba(7, 155, 170, 0.2);
}

.scorecard.compact {
  padding: 10px 12px;
  border-radius: 8px;
}

.scorecard-header {
  display: flex;
  align-items: center;
  gap: 8px;
  font-weight: 600;
  font-size: 13px;
  margin-bottom: 12px;
  opacity: 0.9;
}

.scorecard.compact .scorecard-header {
  font-size: 11px;
  margin-bottom: 8px;
}

.scorecard-stats {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 12px;
}

.scorecard.compact .scorecard-stats {
  gap: 8px;
}

.stat-item {
  text-align: center;
  background: rgba(255, 255, 255, 0.15);
  padding: 10px 6px;
  border-radius: 8px;
  transition: all 0.2s;
}

.scorecard.compact .stat-item {
  padding: 6px 4px;
  border-radius: 6px;
}

.stat-item:hover {
  background: rgba(255, 255, 255, 0.25);
  transform: translateY(-2px);
}

.stat-number {
  font-size: 22px;
  font-weight: 700;
  line-height: 1;
  margin-bottom: 4px;
}

.scorecard.compact .stat-number {
  font-size: 16px;
}

.stat-label {
  font-size: 10px;
  opacity: 0.85;
  font-weight: 500;
}

.scorecard.compact .stat-label {
  font-size: 9px;
}

.stat-item.completed {
  background: rgba(34, 197, 94, 0.3);
}

.stat-item.in-progress {
  background: rgba(251, 191, 36, 0.3);
}

.stat-item.rate .stat-number {
  color: #fbbf24;
}

.weekly-stats {
  margin-top: 12px;
  padding-top: 12px;
  border-top: 1px solid rgba(255, 255, 255, 0.2);
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-size: 12px;
}

.weekly-label {
  opacity: 0.85;
}

.weekly-number {
  font-weight: 700;
  font-size: 14px;
}
</style>

