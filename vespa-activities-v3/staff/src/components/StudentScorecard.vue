<template>
  <div class="scorecard" :class="{'compact': compact}">
    <div class="scorecard-header">
      <i class="fas fa-chart-line"></i>
      <span>{{ compact ? 'Progress' : 'Activity Progress' }}</span>
      <select v-if="showPeriodFilter" v-model="selectedPeriod" class="period-filter" @change="$emit('period-changed', selectedPeriod)">
        <option value="week">Last Week</option>
        <option value="month">Last Month</option>
        <option value="all">All Time</option>
      </select>
    </div>
    
    <div class="scorecard-stats">
      <div class="stat-item completed">
        <div class="stat-number">{{ periodStats.completed }}</div>
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
    
    <div v-if="!compact && selectedPeriod !== 'all'" class="period-info">
      {{ periodLabel }}: {{ periodStats.completed }} of {{ periodStats.total }} completed
    </div>
  </div>
</template>

<script setup>
import { ref, computed } from 'vue';

const props = defineProps({
  activities: {
    type: Array,
    default: () => []
  },
  compact: {
    type: Boolean,
    default: false
  },
  showPeriodFilter: {
    type: Boolean,
    default: true
  }
});

defineEmits(['period-changed']);

const selectedPeriod = ref('week');

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

const periodLabel = computed(() => {
  switch (selectedPeriod.value) {
    case 'week': return 'This Week';
    case 'month': return 'This Month';
    case 'all': return 'All Time';
    default: return 'This Week';
  }
});

const periodStats = computed(() => {
  const activities = props.activities || [];
  const now = new Date();
  let startDate;
  
  switch (selectedPeriod.value) {
    case 'week':
      startDate = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
      break;
    case 'month':
      startDate = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
      break;
    case 'all':
    default:
      startDate = new Date(0); // Beginning of time
  }
  
  const periodActivities = activities.filter(a => {
    if (a.status === 'removed') return false;
    if (!a.completed_at) return false;
    const completedDate = new Date(a.completed_at);
    return completedDate >= startDate;
  });
  
  return {
    completed: periodActivities.length,
    total: activities.filter(a => a.status !== 'removed').length
  };
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
  justify-content: space-between;
}

.scorecard.compact .scorecard-header {
  font-size: 11px;
  margin-bottom: 8px;
}

.period-filter {
  background: rgba(255, 255, 255, 0.25);
  color: white;
  border: 1px solid rgba(255, 255, 255, 0.3);
  border-radius: 4px;
  padding: 3px 8px;
  font-size: 11px;
  font-weight: 600;
  cursor: pointer;
}

.period-filter option {
  background: #079baa;
  color: white;
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

.period-info {
  margin-top: 10px;
  padding-top: 10px;
  border-top: 1px solid rgba(255, 255, 255, 0.2);
  font-size: 11px;
  opacity: 0.9;
  text-align: center;
}
</style>

