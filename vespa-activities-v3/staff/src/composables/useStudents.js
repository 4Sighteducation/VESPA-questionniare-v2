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

      // RPC returns basic student data without nested responses
      // Store as-is, we'll load detailed data when viewing individual students
      students.value = data || [];
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
   */
  const getStudent = async (studentId) => {
    try {
      // First try from loaded students
      const cachedStudent = students.value.find(s => s.id === studentId);
      
      if (cachedStudent) {
        // Reload with fresh data for workspace view
        const { data, error } = await supabase
          .from('vespa_students')
          .select(`
            *,
            activity_responses (
              id,
              activity_id,
              status,
              selected_via,
              completed_at,
              started_at,
              responses,
              responses_text,
              staff_feedback,
              staff_feedback_by,
              staff_feedback_at,
              feedback_read_by_student,
              feedback_read_at,
              time_spent_minutes,
              word_count,
              cycle_number,
              academic_year,
              year_group,
              student_group,
              created_at,
              updated_at,
              activities (
                id,
                name,
                vespa_category,
                level,
                difficulty,
                time_minutes,
                do_section_html,
                think_section_html,
                learn_section_html,
                reflect_section_html,
                problem_mappings,
                curriculum_tags
              )
            )
          `)
          .eq('id', studentId)
          .single();

        if (error) throw error;

        // Process like in loadStudents
        const responses = data.activity_responses || [];
        const prescribed = responses.filter(r => 
          r.selected_via === 'questionnaire' || 
          r.selected_via === 'staff_assigned'
        );
        const completed = prescribed.filter(r => r.completed_at);
        
        return {
          ...data,
          prescribedCount: prescribed.length,
          completedCount: completed.length,
          progress: prescribed.length > 0 ? 
            Math.round((completed.length / prescribed.length) * 100) : 0
        };
      }

      return null;
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

