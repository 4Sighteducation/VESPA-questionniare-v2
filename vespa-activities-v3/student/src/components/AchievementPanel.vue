<template>
  <div class="achievement-panel-overlay" @click.self="$emit('close')">
    <div class="achievement-panel">
      <div class="panel-header">
        <h2>🏆 Your Achievements</h2>
        <button @click="$emit('close')" class="close-btn">✕</button>
      </div>
      
      <div class="panel-content">
        <!-- Points Summary -->
        <div class="points-summary">
          <div class="total-points">
            <span class="points-value">{{ totalPoints }}</span>
            <span class="points-label">Total Points</span>
          </div>
          <div class="achievements-count">
            <span class="count-value">{{ achievements.length }}</span>
            <span class="count-label">Achievements Earned</span>
          </div>
        </div>
        
        <!-- Achievements List -->
        <div v-if="achievements.length === 0" class="empty-state">
          <p>No achievements yet. Complete activities to earn achievements!</p>
        </div>
        
        <div v-else class="achievements-grid">
          <div
            v-for="achievement in achievements"
            :key="achievement.id"
            class="achievement-card"
            :class="{ 'pinned': achievement.is_pinned }"
          >
            <div class="achievement-icon">{{ achievement.icon_emoji || '🏆' }}</div>
            <div class="achievement-content">
              <h4 class="achievement-name">{{ achievement.achievement_name }}</h4>
              <p class="achievement-description">{{ achievement.achievement_description }}</p>
              <div class="achievement-meta">
                <span class="points-badge">+{{ achievement.points_value }} pts</span>
                <span class="date-earned">{{ formatDate(achievement.date_earned) }}</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
defineProps({
  achievements: {
    type: Array,
    default: () => []
  },
  totalPoints: {
    type: Number,
    default: 0
  }
});

defineEmits(['close']);

const formatDate = (dateString) => {
  if (!dateString) return '';
  const date = new Date(dateString);
  return date.toLocaleDateString();
};
</script>

<style scoped>
.achievement-panel-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.7);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 10000;
  padding: var(--spacing-lg);
}

.achievement-panel {
  background: white;
  border-radius: var(--radius-xl);
  max-width: 800px;
  width: 100%;
  max-height: 90vh;
  display: flex;
  flex-direction: column;
  box-shadow: var(--shadow-lg);
}

.panel-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: var(--spacing-lg);
  border-bottom: 2px solid var(--gray);
}

.panel-header h2 {
  margin: 0;
}

.close-btn {
  background: none;
  border: none;
  font-size: 24px;
  cursor: pointer;
  color: var(--dark-gray);
  padding: var(--spacing-xs);
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 4px;
  transition: background 0.2s;
}

.close-btn:hover {
  background: var(--gray);
}

.panel-content {
  flex: 1;
  overflow-y: auto;
  padding: var(--spacing-lg);
}

.points-summary {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: var(--spacing-md);
  margin-bottom: var(--spacing-xl);
  padding: var(--spacing-lg);
  background: linear-gradient(135deg, var(--primary) 0%, var(--secondary) 100%);
  border-radius: var(--radius-lg);
  color: white;
}

.total-points,
.achievements-count {
  text-align: center;
}

.points-value,
.count-value {
  display: block;
  font-size: 3rem;
  font-weight: 700;
  margin-bottom: var(--spacing-xs);
}

.points-label,
.count-label {
  font-size: 0.875rem;
  opacity: 0.9;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

.achievements-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(250px, 1fr));
  gap: var(--spacing-md);
}

.achievement-card {
  background: white;
  border: 2px solid var(--gray);
  border-radius: var(--radius-lg);
  padding: var(--spacing-md);
  display: flex;
  gap: var(--spacing-md);
  transition: transform 0.2s, box-shadow 0.2s;
}

.achievement-card:hover {
  transform: translateY(-2px);
  box-shadow: var(--shadow-md);
}

.achievement-card.pinned {
  border-color: var(--primary);
  background: linear-gradient(135deg, #fff 0%, var(--light-gray) 100%);
}

.achievement-icon {
  font-size: 3rem;
  flex-shrink: 0;
}

.achievement-content {
  flex: 1;
}

.achievement-name {
  font-size: 1.125rem;
  font-weight: 600;
  margin-bottom: var(--spacing-xs);
  color: var(--dark-blue);
}

.achievement-description {
  font-size: 0.875rem;
  color: var(--dark-gray);
  margin-bottom: var(--spacing-sm);
  line-height: 1.5;
}

.achievement-meta {
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-size: 0.75rem;
}

.points-badge {
  background: var(--primary);
  color: white;
  padding: 2px 8px;
  border-radius: 12px;
  font-weight: 600;
}

.date-earned {
  color: var(--dark-gray);
}

.empty-state {
  text-align: center;
  padding: var(--spacing-xl);
  color: var(--dark-gray);
}

@media (max-width: 768px) {
  .achievements-grid {
    grid-template-columns: 1fr;
  }
  
  .points-summary {
    grid-template-columns: 1fr;
  }
}
</style>

