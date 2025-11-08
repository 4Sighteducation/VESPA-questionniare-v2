<template>
  <div class="instructions-screen">
    <div class="instructions-card">
      <!-- Header -->
      <div class="card-header">
        <img 
          src="https://vespa.academy/_astro/vespalogo.BGrK1ARl.png" 
          alt="VESPA Academy" 
          class="logo"
        >
        <h1>VESPA Questionnaire</h1>
        <p class="subtitle">Understanding Your Academic Mindset</p>
      </div>

      <!-- Content -->
      <div class="card-body">
        <!-- Student Info -->
        <div v-if="studentName" class="student-info">
          <span>Welcome, <strong>{{ studentName }}</strong> | Cycle {{ cycleInfo?.cycle || 1 }} of 3</span>
        </div>

        <!-- Compact Info -->
        <div class="info-compact">
          <p class="main-message">
            The VESPA Questionnaire measures your mindset across <strong>Vision, Effort, Systems, Practice, and Attitude</strong> 
            to motivate growth and spark meaningful change.
          </p>
          <p class="remember-message">
            <i class="fa fa-info-circle"></i>
            Your results reflect <strong>how you see yourself right now</strong>—a snapshot, not a verdict.
          </p>
        </div>

        <!-- Call to Action -->
        <div class="cta-section">
          <button class="btn btn-primary btn-large" @click="$emit('start')">
            <i class="fa fa-play-circle"></i>
            Start Questionnaire
          </button>
          <p class="time-estimate">
            <i class="fa fa-clock"></i>
            5 minutes · 32 questions
          </p>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
export default {
  name: 'InstructionsScreen',
  props: {
    studentName: {
      type: String,
      default: ''
    },
    cycleInfo: {
      type: Object,
      default: null
    }
  },
  emits: ['start'],
  data() {
    return {
      categories: [
        { key: 'VISION', name: 'Vision', letter: 'V', color: '#ff8f00' },
        { key: 'EFFORT', name: 'Effort', letter: 'E', color: '#86b4f0' },
        { key: 'SYSTEMS', name: 'Systems', letter: 'S', color: '#72cb44' },
        { key: 'PRACTICE', name: 'Practice', letter: 'P', color: '#7f31a4' },
        { key: 'ATTITUDE', name: 'Attitude', letter: 'A', color: '#f032e6' }
      ]
    }
  }
}
</script>

<style scoped>
.instructions-screen {
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 20px;
  overflow: hidden;
}

.instructions-card {
  background: white;
  border-radius: 20px;
  box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
  max-width: 600px;
  width: 100%;
  max-height: 100%;
  display: flex;
  flex-direction: column;
  animation: slideIn 0.5s ease-out;
  overflow: hidden;
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

.card-header {
  background: linear-gradient(135deg, var(--vespa-dark) 0%, var(--vespa-primary) 100%);
  color: white;
  padding: 25px 30px;
  text-align: center;
  flex-shrink: 0;
}

.logo {
  width: 100px;
  height: auto;
  margin-bottom: 12px;
  filter: brightness(0) invert(1);
}

.card-header h1 {
  font-size: 26px;
  font-weight: 700;
  margin: 0 0 8px 0;
}

.subtitle {
  font-size: 15px;
  opacity: 0.9;
  margin: 0;
}

.card-body {
  padding: 20px 30px;
  flex: 1;
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  overflow-y: hidden;
}

.student-info {
  background: var(--bg-light);
  padding: 8px 16px;
  border-radius: 8px;
  margin-bottom: 12px;
  text-align: center;
  color: var(--vespa-dark);
  font-size: 14px;
}

.info-compact {
  margin-bottom: 16px;
}

.main-message {
  color: var(--text-primary);
  font-size: 15px;
  line-height: 1.4;
  margin: 0 0 10px 0;
  text-align: center;
}

.remember-message {
  background: linear-gradient(135deg, rgba(7, 155, 170, 0.08) 0%, rgba(123, 216, 208, 0.08) 100%);
  padding: 10px 14px;
  border-radius: 8px;
  border-left: 3px solid var(--vespa-primary);
  color: var(--text-secondary);
  font-size: 13px;
  line-height: 1.3;
  margin: 0;
  display: flex;
  align-items: center;
  gap: 8px;
  text-align: left;
}

.remember-message i {
  color: var(--vespa-primary);
  font-size: 16px;
  flex-shrink: 0;
}

.cta-section {
  text-align: center;
}

.btn-large {
  padding: 16px 40px;
  font-size: 17px;
  font-weight: 600;
  width: 100%;
}

.time-estimate {
  margin-top: 10px;
  color: var(--text-secondary);
  font-size: 13px;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
}

.time-estimate i {
  color: var(--vespa-primary);
}

@media (max-width: 768px) {
  .instructions-screen {
    padding: 10px;
  }

  .instructions-card {
    border-radius: 12px;
    max-height: 95vh;
  }

  .card-header {
    padding: 20px;
  }

  .card-header h1 {
    font-size: 22px;
  }

  .subtitle {
    font-size: 14px;
  }

  .logo {
    width: 80px;
    margin-bottom: 10px;
  }

  .card-body {
    padding: 20px;
  }

  .main-message {
    font-size: 15px;
  }

  .remember-message {
    font-size: 13px;
    padding: 10px 12px;
  }

  .btn-large {
    padding: 14px 30px;
    font-size: 16px;
  }

  .time-estimate {
    font-size: 12px;
  }
}
</style>
