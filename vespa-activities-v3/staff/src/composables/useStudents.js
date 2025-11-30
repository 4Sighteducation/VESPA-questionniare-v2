/**
 * Students Data Composable
 * Handles loading and managing student data with activities
 */

import { ref, computed } from 'vue';
import supabase from '../supabaseClient';
import { useAuth } from './useAuth';

// Global state
const students = ref([]);
const isLoadingStudents = ref(false);
const studentsError = ref(null);

export function useStudents() {
  const { staffContext, currentUser, hasRole } = useAuth();

  /**
   * Load students based on staff role and connections
   * Uses RPC functions to bypass RLS properly
   */
  const loadStudents = async () => {
    isLoadingStudents.value = true;
    studentsError.value = null;

    try {
      console.log('📚 Loading students via RPC for school:', staffContext.value.schoolId);
      console.log('📚 Staff email:', currentUser.value.email);

      let data, error;

      // For super users or staff admins: get all students in school
      if (staffContext.value.isSuperUser || hasRole('staff_admin')) {
        console.log('🔐 Admin access - loading ALL students via RPC');
        
        // Use RPC function to bypass RLS
        const rpcResult = await supabase.rpc('get_students_for_staff', {
          staff_email_param: currentUser.value.email,
          school_id_param: staffContext.value.schoolId
        });
        
        data = rpcResult.data;
        error = rpcResult.error;

      } else {
        // For regular staff: get only connected students
        console.log('👥 Regular staff - loading CONNECTED students via RPC');
        
        // Use RPC function to get connected students
        const rpcResult = await supabase.rpc('get_connected_students_for_staff', {
          staff_email_param: currentUser.value.email,
          school_id_param: staffContext.value.schoolId,
          connection_type_filter: null  // null = all connection types
        });
        
        data = rpcResult.data;
        error = rpcResult.error;
      }

      if (error) throw error;

      // RPC returns basic student data - add default progress fields for UI
      students.value = (data || []).map(student => ({
        ...student,
        prescribedCount: 0,  // TODO: Load from activity_responses
        completedCount: 0,
        totalCompletedCount: 0,
        progress: 0,
        categoryBreakdown: {},
        unreadFeedbackCount: 0
      }));
      
      console.log(`✅ Loaded ${students.value.length} students via RPC`);

    } catch (err) {
      console.error('❌ Failed to load students:', err);
      studentsError.value = err.message;
      throw err;
    } finally {
      isLoadingStudents.value = false;
    }
  };

  /**
   * Get single student with full activity details
   * Fetches activity_responses from Supabase
   */
  const getStudent = async (studentId) => {
    try {
      console.log('🔍 Getting student:', studentId);
      
      // Get student from cache
      const student = students.value.find(s => s.id === studentId);
      
      if (!student) {
        console.warn('⚠️ Student not found in cache');
        return null;
      }
      
      console.log('✅ Found student in cache:', student.full_name);
      console.log('📚 Fetching activity_responses for:', student.email);
      
      // Use RPC function to fetch activity_responses (bypasses RLS)
      const { data: activityResponses, error } = await supabase.rpc('get_student_activity_responses', {
        student_email_param: student.email,
        staff_email_param: currentUser.value.email,
        school_id_param: staffContext.value.schoolId
      });
      
      if (error) {
        console.error('Failed to fetch activity_responses:', error);
        throw error;
      }
      
      // Transform RPC response to match expected format (flatten activity data)
      const formattedResponses = (activityResponses || []).map(ar => ({
        ...ar,
        activities: {
          id: ar.activity_id,
          name: ar.activity_name,
          vespa_category: ar.activity_category,
          level: ar.activity_level,
          time_minutes: ar.activity_time_minutes,
          difficulty: ar.activity_difficulty,
          do_section_html: ar.activity_do_section,
          think_section_html: ar.activity_think_section,
          learn_section_html: ar.activity_learn_section,
          reflect_section_html: ar.activity_reflect_section
        }
      }));
      
      console.log(`✅ Loaded ${formattedResponses?.length || 0} activity responses for ${student.full_name}`);
      
      // Return student with populated activity_responses
      return {
        ...student,
        activity_responses: formattedResponses || []
      };
      
    } catch (err) {
      console.error('Failed to get student:', err);
      throw err;
    }
  };

  /**
   * Filter students by search term
   */
  const filterStudents = (searchTerm) => {
    if (!searchTerm) return students.value;
    
    const term = searchTerm.toLowerCase();
    return students.value.filter(s => 
      s.full_name?.toLowerCase().includes(term) ||
      s.email?.toLowerCase().includes(term) ||
      s.student_group?.toLowerCase().includes(term)
    );
  };

  return {
    students,
    isLoadingStudents,
    studentsError,
    loadStudents,
    getStudent,
    filterStudents
  };
}

