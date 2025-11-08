<template>
  <div class="progress-indicator">
    <div class="progress-info">
      <span class="progress-label">
        Question {{ currentQuestion }} of {{ totalQuestions }}
      </span>
      <span class="progress-percentage">{{ percentage }}%</span>
    </div>
    <div class="progress-bar-container">
      <div 
        class="progress-bar-fill" 
        :style="{ width: percentage + '%' }"
      ></div>
    </div>
    <div v-if="categoryName" class="current-category">
      <span 
        class="category-dot"
        :style="{ backgroundColor: categoryColor }"
      ></span>
      <span>{{ categoryName }}</span>
    </div>
  </div>
</template>

<script>
export default {
  name: 'ProgressIndicator',
  props: {
    currentQuestion: {
      type: Number,
      required: true
    },
    totalQuestions: {
      type: Number,
      required: true
    },
    categoryName: {
      type: String,
      default: ''
    },
    categoryColor: {
      type: String,
      default: '#079baa'
    }
  },
  computed: {
    percentage() {
      return Math.round((this.currentQuestion / this.totalQuestions) * 100)
    }
  }
}
</script>

<style scoped>
.progress-indicator {
  background: white;
  padding: 16px 20px;
  flex-shrink: 0;
  border-radius: 16px 16px 0 0;
  margin: 0 20px 0;
  box-shadow: 0 -2px 10px rgba(0, 0, 0, 0.05);
}

.progress-info {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 12px;
  font-size: 14px;
  color: var(--text-secondary);
}

.progress-label {
  font-weight: 600;
}

.progress-percentage {
  font-weight: 700;
  color: var(--vespa-primary);
}

.progress-bar-container {
  width: 100%;
  height: 8px;
  background: #e0e0e0;
  border-radius: 4px;
  overflow: hidden;
}

.progress-bar-fill {
  height: 100%;
  background: linear-gradient(90deg, var(--vespa-primary) 0%, var(--vespa-secondary) 100%);
  transition: width 0.4s ease;
  border-radius: 4px;
}

.current-category {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-top: 12px;
  font-size: 13px;
  color: var(--text-secondary);
  font-weight: 600;
}

.category-dot {
  width: 12px;
  height: 12px;
  border-radius: 50%;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);
}

@media (max-width: 768px) {
  .progress-indicator {
    padding: 12px 15px;
    margin: 0;
    border-radius: 0;
  }

  .progress-info {
    font-size: 12px;
    margin-bottom: 8px;
  }
  
  .current-category {
    display: none;
  }
}
</style>

