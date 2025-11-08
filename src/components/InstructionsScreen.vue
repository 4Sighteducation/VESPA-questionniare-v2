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
          <i class="fa fa-user"></i>
          <span>Welcome, <strong>{{ studentName }}</strong></span>
        </div>

        <div v-if="cycleInfo" class="cycle-info">
          <i class="fa fa-calendar-check"></i>
          <span>You're taking <strong>Cycle {{ cycleInfo.cycle }}</strong> of 3</span>
        </div>

        <!-- What it is -->
        <div class="info-section">
          <h3><i class="fa fa-lightbulb"></i> What it is</h3>
          <p>The VESPA Questionnaire measures your current mindset across <strong>Vision, Effort, Systems, Practice, and Attitude</strong>.</p>
        </div>

        <!-- What it's for -->
        <div class="info-section">
          <h3><i class="fa fa-target"></i> What it's for</h3>
          <p>It's designed to <strong>motivate growth and spark meaningful change</strong>—not to label you.</p>
        </div>

        <!-- How to use it -->
        <div class="info-section">
          <h3><i class="fa fa-comments"></i> How to use it</h3>
          <p>Use your results to kick off coaching conversations, guide team discussions, set goals, and shape your ongoing development.</p>
        </div>

        <!-- Remember -->
        <div class="info-section remember">
          <h3><i class="fa fa-heart"></i> Remember</h3>
          <p>Your results reflect <strong>how you see yourself right now</strong>—a snapshot, not a verdict.</p>
        </div>

        <!-- VESPA Categories Display -->
        <div class="vespa-categories">
          <div 
            v-for="category in categories" 
            :key="category.key"
            class="category-badge"
            :style="{ borderColor: category.color }"
          >
            <div 
              class="category-icon"
              :style="{ backgroundColor: category.color }"
            >
              {{ category.letter }}
            </div>
            <span class="category-name">{{ category.name }}</span>
          </div>
        </div>

        <!-- Call to Action -->
        <div class="cta-section">
          <p class="cta-text">Ready to start exploring your academic mindset?</p>
          <button class="btn btn-primary btn-large" @click="$emit('start')">
            <i class="fa fa-play-circle"></i>
            Start Questionnaire
          </button>
          <p class="time-estimate">
            <i class="fa fa-clock"></i>
            Takes approximately 5 minutes
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
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 20px;
}

.instructions-card {
  background: white;
  border-radius: 20px;
  box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
  max-width: 700px;
  width: 100%;
  overflow: hidden;
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

.card-header {
  background: linear-gradient(135deg, var(--vespa-dark) 0%, var(--vespa-primary) 100%);
  color: white;
  padding: 40px 30px;
  text-align: center;
}

.logo {
  width: 120px;
  height: auto;
  margin-bottom: 20px;
  filter: brightness(0) invert(1);
}

.card-header h1 {
  font-size: 32px;
  font-weight: 700;
  margin: 0 0 10px 0;
}

.subtitle {
  font-size: 18px;
  opacity: 0.9;
  margin: 0;
}

.card-body {
  padding: 40px 30px;
}

.student-info,
.cycle-info {
  background: var(--bg-light);
  padding: 12px 20px;
  border-radius: 10px;
  margin-bottom: 20px;
  display: flex;
  align-items: center;
  gap: 12px;
  color: var(--vespa-dark);
}

.student-info i,
.cycle-info i {
  color: var(--vespa-primary);
  font-size: 18px;
}

.info-section {
  margin-bottom: 25px;
  padding-bottom: 20px;
  border-bottom: 1px solid #e0e0e0;
}

.info-section:last-of-type {
  border-bottom: none;
}

.info-section h3 {
  color: var(--vespa-dark);
  font-size: 18px;
  font-weight: 600;
  margin: 0 0 12px 0;
  display: flex;
  align-items: center;
  gap: 10px;
}

.info-section h3 i {
  color: var(--vespa-primary);
  font-size: 20px;
}

.info-section p {
  color: var(--text-secondary);
  font-size: 16px;
  line-height: 1.6;
  margin: 0;
}

.info-section.remember {
  background: linear-gradient(135deg, rgba(7, 155, 170, 0.05) 0%, rgba(123, 216, 208, 0.05) 100%);
  padding: 20px;
  border-radius: 12px;
  border: 2px solid rgba(7, 155, 170, 0.2);
  border-bottom: 2px solid rgba(7, 155, 170, 0.2);
}

.info-section.remember h3 {
  color: var(--vespa-primary);
}

.vespa-categories {
  display: flex;
  flex-wrap: wrap;
  gap: 12px;
  justify-content: center;
  margin: 30px 0;
}

.category-badge {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 16px;
  background: white;
  border: 2px solid;
  border-radius: 25px;
  transition: all 0.3s ease;
}

.category-badge:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
}

.category-icon {
  width: 32px;
  height: 32px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  color: white;
  font-weight: bold;
  font-size: 16px;
}

.category-name {
  font-weight: 600;
  color: var(--text-primary);
}

.cta-section {
  text-align: center;
  margin-top: 40px;
}

.cta-text {
  font-size: 20px;
  font-weight: 600;
  color: var(--vespa-dark);
  margin-bottom: 25px;
}

.btn-large {
  padding: 16px 40px;
  font-size: 18px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

.time-estimate {
  margin-top: 15px;
  color: var(--text-secondary);
  font-size: 14px;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
}

.time-estimate i {
  color: var(--vespa-primary);
}

@media (max-width: 768px) {
  .instructions-card {
    border-radius: 0;
  }

  .card-header {
    padding: 30px 20px;
  }

  .card-header h1 {
    font-size: 26px;
  }

  .subtitle {
    font-size: 16px;
  }

  .card-body {
    padding: 30px 20px;
  }

  .info-section h3 {
    font-size: 16px;
  }

  .info-section p {
    font-size: 15px;
  }

  .vespa-categories {
    gap: 8px;
  }

  .category-badge {
    padding: 8px 12px;
    gap: 8px;
  }

  .category-icon {
    width: 28px;
    height: 28px;
    font-size: 14px;
  }

  .cta-text {
    font-size: 18px;
  }

  .btn-large {
    padding: 14px 30px;
    font-size: 16px;
    width: 100%;
  }
}
</style>
