<template>
  <div class="not-available-screen">
    <div class="message-card">
      <!-- Icon -->
      <div class="icon-container" :class="iconClass">
        <i :class="['fa', iconName]"></i>
      </div>

      <!-- Message -->
      <h2>{{ title }}</h2>
      <p class="message-text">{{ message }}</p>

      <!-- Additional Info -->
      <div v-if="nextStartDate" class="info-box">
        <i class="fa fa-calendar-alt"></i>
        <div>
          <strong>Next Available:</strong>
          <p>{{ nextStartDate }}</p>
        </div>
      </div>

      <div v-if="reason === 'all_completed'" class="info-box success">
        <i class="fa fa-check-circle"></i>
        <div>
          <strong>Well done!</strong>
          <p>You've completed all three cycles for this academic year.</p>
        </div>
      </div>

      <!-- Actions -->
      <div class="action-buttons">
        <button 
          v-if="showReportButton" 
          class="btn btn-primary" 
          @click="goToReport"
        >
          <i class="fa fa-file-alt"></i>
          View Your Report
        </button>
        
        <button class="btn btn-secondary" @click="goHome">
          <i class="fa fa-home"></i>
          Return to Home
        </button>
      </div>

      <p class="help-text">
        <i class="fa fa-question-circle"></i>
        If you believe this is incorrect, please speak to your tutor or administrator.
      </p>
    </div>
  </div>
</template>

<script>
export default {
  name: 'NotAvailable',
  props: {
    reason: {
      type: String,
      required: true
    },
    message: {
      type: String,
      required: true
    },
    nextStartDate: {
      type: String,
      default: ''
    }
  },
  computed: {
    title() {
      switch (this.reason) {
        case 'before_start':
          return 'Questionnaire Not Yet Open'
        case 'all_completed':
          return 'All Cycles Complete'
        case 'no_active_cycle':
          return 'No Active Cycle'
        case 'error':
          return 'Unable to Load'
        default:
          return 'Questionnaire Not Available'
      }
    },
    iconName() {
      switch (this.reason) {
        case 'before_start':
          return 'fa-calendar-times'
        case 'all_completed':
          return 'fa-trophy'
        case 'no_active_cycle':
          return 'fa-info-circle'
        case 'error':
          return 'fa-exclamation-triangle'
        default:
          return 'fa-lock'
      }
    },
    iconClass() {
      switch (this.reason) {
        case 'all_completed':
          return 'success'
        case 'error':
          return 'error'
        default:
          return 'warning'
      }
    },
    showReportButton() {
      return this.reason === 'all_completed' || this.reason === 'no_active_cycle'
    }
  },
  methods: {
    goToReport() {
      window.location.hash = '#vespa-results'
    },
    goHome() {
      window.location.hash = '#landing-page/'
    }
  }
}
</script>

<style scoped>
.not-available-screen {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 20px;
}

.message-card {
  background: white;
  border-radius: 20px;
  box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
  max-width: 600px;
  width: 100%;
  padding: 50px 40px;
  text-align: center;
  animation: slideIn 0.5s ease-out;
}

.icon-container {
  width: 100px;
  height: 100px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  margin: 0 auto 30px;
  font-size: 48px;
}

.icon-container.warning {
  background: linear-gradient(135deg, #ffc107 0%, #ff9800 100%);
  color: white;
}

.icon-container.error {
  background: linear-gradient(135deg, #f44336 0%, #d32f2f 100%);
  color: white;
}

.icon-container.success {
  background: linear-gradient(135deg, #4caf50 0%, #388e3c 100%);
  color: white;
}

.message-card h2 {
  color: var(--vespa-dark);
  font-size: 28px;
  font-weight: 700;
  margin: 0 0 20px 0;
}

.message-text {
  color: var(--text-secondary);
  font-size: 18px;
  line-height: 1.6;
  margin-bottom: 30px;
}

.info-box {
  background: var(--bg-light);
  border-left: 4px solid var(--vespa-primary);
  padding: 20px;
  border-radius: 8px;
  margin: 25px 0;
  display: flex;
  align-items: flex-start;
  gap: 15px;
  text-align: left;
}

.info-box.success {
  background: #e8f5e9;
  border-left-color: #4caf50;
}

.info-box i {
  color: var(--vespa-primary);
  font-size: 24px;
  flex-shrink: 0;
  margin-top: 3px;
}

.info-box.success i {
  color: #4caf50;
}

.info-box strong {
  display: block;
  color: var(--vespa-dark);
  font-size: 16px;
  margin-bottom: 5px;
}

.info-box p {
  color: var(--text-secondary);
  font-size: 15px;
  margin: 0;
}

.action-buttons {
  display: flex;
  flex-direction: column;
  gap: 12px;
  margin-top: 30px;
}

.action-buttons .btn {
  width: 100%;
  justify-content: center;
}

.help-text {
  margin-top: 30px;
  color: var(--text-secondary);
  font-size: 14px;
  font-style: italic;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
}

.help-text i {
  color: var(--vespa-primary);
}

@media (max-width: 768px) {
  .message-card {
    padding: 40px 25px;
  }

  .icon-container {
    width: 80px;
    height: 80px;
    font-size: 40px;
  }

  .message-card h2 {
    font-size: 24px;
  }

  .message-text {
    font-size: 16px;
  }
}
</style>
