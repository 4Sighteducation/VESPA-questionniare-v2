<template>
  <div id="vespa-staff-app" class="staff-app">
    <!-- Loading Screen -->
    <div v-if="isInitializing" class="loading-screen">
      <div class="loading-content">
        <div class="loading-spinner"></div>
        <h2>Loading VESPA Staff Dashboard...</h2>
        <p class="loading-text">{{ loadingMessage }}</p>
      </div>
    </div>

    <!-- Authentication Error -->
    <div v-else-if="authError" class="error-screen">
      <div class="error-content">
        <i class="fas fa-exclamation-triangle error-icon"></i>
        <h2>Authentication Required</h2>
        <p>{{ authError }}</p>
        <p class="error-hint">Please log in through Knack to access the staff dashboard.</p>
      </div>
    </div>

    <!-- Main Dashboard -->
    <div v-else-if="isAuthenticated" class="dashboard-container">
      <!-- Page 1: Student List View -->
      <StudentListView
        v-if="currentView === 'list'"
        :students="students"
        :is-loading="isLoadingStudents"
        :staff-context="staffContext"
        @view-student="viewStudent"
        @refresh="loadStudents"
      />

      <!-- Page 2: Student Workspace -->
      <StudentWorkspace
        v-else-if="currentView === 'workspace' && selectedStudent"
        :student="selectedStudent"
        :staff-context="staffContext"
        @back="backToList"
        @refresh="refreshStudent"
      />
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, computed } from 'vue';
import StudentListView from './components/StudentListView.vue';
import StudentWorkspace from './components/StudentWorkspace.vue';
import { useAuth } from './composables/useAuth';
import { useStudents } from './composables/useStudents';

// State
const isInitializing = ref(true);
const loadingMessage = ref('Initializing...');
const authError = ref(null);
const currentView = ref('list'); // 'list' or 'workspace'
const selectedStudent = ref(null);

// Composables
const { 
  isAuthenticated, 
  staffContext, 
  checkAuth 
} = useAuth();

const { 
  students, 
  isLoadingStudents, 
  loadStudents,
  getStudent 
} = useStudents();

// Initialize app
onMounted(async () => {
  try {
    loadingMessage.value = 'Checking authentication...';
    
    // Check if user is authenticated via Knack
    await checkAuth();
    
    if (!isAuthenticated.value) {
      authError.value = 'You must be logged in as staff to access this dashboard.';
      return;
    }
    
    loadingMessage.value = 'Loading students...';
    
    // Load students based on staff role
    await loadStudents();
    
    console.log('✅ Staff Dashboard initialized successfully');
    
  } catch (error) {
    console.error('❌ Failed to initialize dashboard:', error);
    authError.value = error.message || 'Failed to initialize dashboard. Please try refreshing the page.';
  } finally {
    isInitializing.value = false;
  }
});

// Actions
const viewStudent = async (studentId) => {
  try {
    const student = await getStudent(studentId);
    if (student) {
      selectedStudent.value = student;
      currentView.value = 'workspace';
    }
  } catch (error) {
    console.error('Failed to load student:', error);
    alert('Error loading student details. Please try again.');
  }
};

const backToList = () => {
  currentView.value = 'list';
  selectedStudent.value = null;
};

const refreshStudent = async () => {
  if (selectedStudent.value) {
    const refreshed = await getStudent(selectedStudent.value.id);
    if (refreshed) {
      selectedStudent.value = refreshed;
    }
  }
};
</script>

<style>
/* Global styles imported */
@import './style.css';
</style>

