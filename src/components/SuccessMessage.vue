<template>
  <div class="success-screen">
    <div class="success-card">
      <!-- Success Icon -->
      <div class="success-icon">
        <i class="fa fa-check-circle"></i>
      </div>

      <!-- Message -->
      <h2>Questionnaire Complete!</h2>
      <p class="success-message">
        Thank you for completing the VESPA questionnaire. 
        Your responses have been saved successfully.
      </p>

      <!-- Quick Scores Preview -->
      <div v-if="scores" class="scores-preview">
        <h3>Your VESPA Scores</h3>
        <div class="scores-grid">
          <div 
            v-for="(score, category) in displayScores" 
            :key="category"
            class="score-item"
          >
            <div 
              class="score-badge"
              :style="{ backgroundColor: getCategoryColor(category) }"
            >
              {{ score }}
            </div>
            <span class="score-label">{{ category }}</span>
          </div>
        </div>
      </div>

      <!-- Next Steps -->
      <div class="next-steps">
        <p class="next-steps-text">
          <i class="fa fa-arrow-right"></i>
          View your detailed report with personalized coaching questions and recommendations
        </p>
        <button class="btn btn-primary btn-large" @click="viewReport">
          <i class="fa fa-file-alt"></i>
          View Your Report
        </button>
      </div>

      <!-- Alternative Action -->
      <button class="btn btn-secondary" @click="goHome">
        <i class="fa fa-home"></i>
        Return to Home
      </button>
    </div>
  </div>
</template>

<script>
import { categories } from '../data/questions.js'

export default {
  name: 'SuccessMessage',
  props: {
    scores: {
      type: Object,
      default: null
    }
  },
  computed: {
    displayScores() {
      if (!this.scores) return {}
      
      // Show all 5 categories + overall
      return {
        Vision: this.scores.VISION,
        Effort: this.scores.EFFORT,
        Systems: this.scores.SYSTEMS,
        Practice: this.scores.PRACTICE,
        Attitude: this.scores.ATTITUDE,
        Overall: this.scores.OVERALL
      }
    }
  },
  methods: {
    getCategoryColor(categoryName) {
      const categoryKey = categoryName.toUpperCase()
      return categories[categoryKey]?.color || '#079baa'
    },
    viewReport() {
      // Navigate to the V2 report page (scene_1284)
      window.location.hash = '#vespa-coaching-report/'
    },
    goHome() {
      window.location.hash = '#landing-page/'
    }
  }
}
</script>

<style scoped>
.success-screen {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 20px;
}

.success-card {
  background: white;
  border-radius: 20px;
  box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
  max-width: 650px;
  width: 100%;
  padding: 50px 40px;
  text-align: center;
  animation: slideIn 0.5s ease-out;
}

@keyframes slideIn {
  from {
    opacity: 0;
    transform: translateY(30px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.success-icon {
  width: 100px;
  height: 100px;
  border-radius: 50%;
  background: linear-gradient(135deg, #4caf50 0%, #388e3c 100%);
  display: flex;
  align-items: center;
  justify-content: center;
  margin: 0 auto 30px;
  font-size: 56px;
  color: white;
  box-shadow: 0 8px 24px rgba(76, 175, 80, 0.4);
  animation: successPulse 1s ease-out;
}

@keyframes successPulse {
  0% {
    transform: scale(0.8);
    opacity: 0;
  }
  50% {
    transform: scale(1.1);
  }
  100% {
    transform: scale(1);
    opacity: 1;
  }
}

.success-card h2 {
  color: var(--vespa-dark);
  font-size: 32px;
  font-weight: 700;
  margin: 0 0 20px 0;
}

.success-message {
  color: var(--text-secondary);
  font-size: 18px;
  line-height: 1.6;
  margin-bottom: 40px;
}

.scores-preview {
  background: var(--bg-light);
  border-radius: 15px;
  padding: 30px 25px;
  margin-bottom: 40px;
}

.scores-preview h3 {
  color: var(--vespa-dark);
  font-size: 20px;
  font-weight: 600;
  margin: 0 0 25px 0;
}

.scores-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(100px, 1fr));
  gap: 15px;
}

.score-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 10px;
}

.score-badge {
  width: 60px;
  height: 60px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  color: white;
  font-size: 28px;
  font-weight: 700;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
}

.score-label {
  font-size: 13px;
  font-weight: 600;
  color: var(--text-secondary);
}

.next-steps {
  margin-bottom: 25px;
}

.next-steps-text {
  color: var(--text-secondary);
  font-size: 16px;
  margin-bottom: 20px;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 10px;
}

.next-steps-text i {
  color: var(--vespa-primary);
}

.btn-large {
  padding: 18px 40px;
  font-size: 18px;
  width: 100%;
  margin-bottom: 15px;
}

.btn-secondary {
  width: 100%;
}

@media (max-width: 768px) {
  .success-card {
    padding: 40px 25px;
  }

  .success-card h2 {
    font-size: 26px;
  }

  .success-message {
    font-size: 16px;
  }

  .scores-preview {
    padding: 25px 20px;
  }

  .scores-grid {
    grid-template-columns: repeat(3, 1fr);
    gap: 12px;
  }

  .score-badge {
    width: 50px;
    height: 50px;
    font-size: 24px;
  }

  .score-label {
    font-size: 12px;
  }

  .btn-large {
    padding: 16px 30px;
    font-size: 16px;
  }
}
</style>

