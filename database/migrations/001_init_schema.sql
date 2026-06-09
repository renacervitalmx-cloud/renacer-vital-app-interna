-- ============================================================================
-- Renacer Vital - Database Schema for Supabase
-- Clinical Management System (SOAP, Patients, Sessions, Exercises)
-- ============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- CUSTOM TYPES
-- ============================================================================

-- User roles enum
CREATE TYPE user_role AS ENUM ('admin', 'therapist', 'reception');

-- Session status enum
CREATE TYPE session_status AS ENUM ('scheduled', 'in_progress', 'completed', 'cancelled', 'no_show');

-- Gender enum
CREATE TYPE gender_enum AS ENUM ('M', 'F', 'Other', 'Prefer not to say');

-- Emotion intensity enum
CREATE TYPE emotion_intensity AS ENUM ('very_low', 'low', 'moderate', 'high', 'very_high');

-- ============================================================================
-- PROFILES TABLE (Users/Team Members)
-- ============================================================================

CREATE TABLE IF NOT EXISTS profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
    role user_role NOT NULL DEFAULT 'reception',
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    phone VARCHAR(20),
    specialization VARCHAR(255), -- For therapists: psychology, physiotherapy, etc.
    license_number VARCHAR(100), -- Professional license
    active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    
    CONSTRAINT valid_email CHECK (email ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}$'),
    CONSTRAINT phone_format CHECK (phone IS NULL OR phone ~ '^[0-9\-\+\(\) ]+$')
);

-- ============================================================================
-- PATIENTS TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS patients (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    -- Basic Information
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    date_of_birth DATE NOT NULL,
    gender gender_enum NOT NULL,
    email VARCHAR(255),
    phone VARCHAR(20) NOT NULL,
    emergency_contact_name VARCHAR(100),
    emergency_contact_phone VARCHAR(20),
    
    -- Medical History
    medical_history TEXT, -- Pre-existing conditions, allergies, medications
    current_medications TEXT,
    known_allergies TEXT,
    
    -- Contact Information
    address VARCHAR(255),
    city VARCHAR(100),
    state VARCHAR(100),
    postal_code VARCHAR(20),
    country VARCHAR(100) DEFAULT 'Mexico',
    
    -- Insurance & Administrative
    insurance_provider VARCHAR(100),
    insurance_policy VARCHAR(100),
    insurance_expiration DATE,
    
    -- Metadata
    intake_date DATE DEFAULT CURRENT_DATE,
    status VARCHAR(50) DEFAULT 'active', -- active, inactive, suspended
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_by UUID NOT NULL REFERENCES profiles(user_id) ON DELETE SET NULL,
    
    CONSTRAINT valid_email CHECK (email IS NULL OR email ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}$'),
    CONSTRAINT valid_phone CHECK (phone ~ '^[0-9\-\+\(\) ]+$'),
    CONSTRAINT valid_birth_date CHECK (date_of_birth <= CURRENT_DATE)
);

-- ============================================================================
-- SESSIONS TABLE (Therapy/Clinical Sessions)
-- ============================================================================

CREATE TABLE IF NOT EXISTS sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE RESTRICT,
    therapist_id UUID NOT NULL REFERENCES profiles(user_id) ON DELETE SET NULL,
    
    -- Session Details
    session_date DATE NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME,
    duration_minutes INT, -- Calculated from start and end time
    
    -- Session Management
    status session_status DEFAULT 'scheduled',
    session_type VARCHAR(100), -- individual, couples, family, group
    location VARCHAR(255), -- office, online, home visit
    
    -- Clinical Notes
    initial_observations TEXT,
    notes TEXT,
    
    -- Metadata
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_by UUID NOT NULL REFERENCES profiles(user_id) ON DELETE SET NULL,
    
    CONSTRAINT valid_time CHECK (start_time < end_time OR end_time IS NULL),
    CONSTRAINT valid_duration CHECK (duration_minutes IS NULL OR duration_minutes > 0)
);

-- ============================================================================
-- SOAP_NOTES TABLE (Subjective, Objective, Assessment, Plan)
-- ============================================================================

CREATE TABLE IF NOT EXISTS soap_notes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID NOT NULL UNIQUE REFERENCES sessions(id) ON DELETE CASCADE,
    patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    therapist_id UUID NOT NULL REFERENCES profiles(user_id) ON DELETE SET NULL,
    
    -- SOAP Components
    -- S: Subjective - what the patient reports
    subjective_chief_complaint TEXT,
    subjective_history_of_present_illness TEXT,
    subjective_emotional_state TEXT,
    
    -- O: Objective - what the therapist observes
    objective_vital_signs JSONB, -- {heart_rate, blood_pressure, temperature, etc.}
    objective_physical_observations TEXT,
    objective_behavioral_observations TEXT,
    objective_test_results JSONB, -- Any test results in JSON
    
    -- A: Assessment - therapist's clinical judgment
    assessment_diagnosis TEXT, -- Clinical impressions/diagnosis
    assessment_progress TEXT, -- Progress notes
    assessment_risk_factors TEXT, -- Any identified risks
    assessment_functional_status TEXT, -- How patient is functioning
    
    -- P: Plan - treatment plan forward
    plan_interventions TEXT, -- Planned treatments/interventions
    plan_exercises TEXT, -- Exercise recommendations
    plan_follow_up_date DATE, -- Recommended follow-up
    plan_referrals TEXT, -- Referrals to other professionals
    plan_patient_education TEXT, -- Education given to patient
    
    -- Metadata
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_by UUID NOT NULL REFERENCES profiles(user_id) ON DELETE SET NULL
);

-- ============================================================================
-- CLINICAL_FILES TABLE (Documents & Attachments)
-- ============================================================================

CREATE TABLE IF NOT EXISTS clinical_files (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    session_id UUID REFERENCES sessions(id) ON DELETE SET NULL, -- Optional: file from specific session
    
    -- File Information
    file_name VARCHAR(255) NOT NULL,
    file_type VARCHAR(50), -- pdf, image, video, audio, etc.
    file_size_bytes INT NOT NULL,
    storage_path VARCHAR(512) NOT NULL, -- Supabase storage path
    
    -- File Classification
    document_type VARCHAR(100), -- intake_form, lab_result, imaging, prescription, etc.
    description TEXT,
    
    -- Metadata
    uploaded_by UUID NOT NULL REFERENCES profiles(user_id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    is_confidential BOOLEAN DEFAULT false,
    
    CONSTRAINT valid_file_size CHECK (file_size_bytes > 0 AND file_size_bytes <= 52428800) -- 50MB limit
);

-- ============================================================================
-- IMPROVEMENT_FEEDBACK TABLE (Patient Progress Tracking)
-- ============================================================================

CREATE TABLE IF NOT EXISTS improvement_feedback (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    session_id UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    therapist_id UUID NOT NULL REFERENCES profiles(user_id) ON DELETE SET NULL,
    
    -- Progress Metrics (1-10 scale)
    pain_level INT, -- 1-10 pain scale
    mobility_improvement INT, -- 1-10 improvement in mobility
    emotional_well_being INT, -- 1-10 emotional state
    sleep_quality INT, -- 1-10 sleep quality
    daily_function INT, -- 1-10 functional improvement
    
    -- Qualitative Feedback
    improvements_noted TEXT, -- Patient-reported improvements
    challenges TEXT, -- Challenges faced
    therapy_satisfaction INT, -- 1-10 satisfaction with therapy
    
    -- Goals Progress
    goal_1_progress INT, -- % progress toward goal 1
    goal_2_progress INT, -- % progress toward goal 2
    goal_3_progress INT, -- % progress toward goal 3
    
    -- Follow-up Notes
    follow_up_recommendations TEXT,
    
    -- Metadata
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT valid_pain_level CHECK (pain_level IS NULL OR (pain_level >= 1 AND pain_level <= 10)),
    CONSTRAINT valid_mobility CHECK (mobility_improvement IS NULL OR (mobility_improvement >= 1 AND mobility_improvement <= 10)),
    CONSTRAINT valid_wellbeing CHECK (emotional_well_being IS NULL OR (emotional_well_being >= 1 AND emotional_well_being <= 10)),
    CONSTRAINT valid_sleep CHECK (sleep_quality IS NULL OR (sleep_quality >= 1 AND sleep_quality <= 10)),
    CONSTRAINT valid_function CHECK (daily_function IS NULL OR (daily_function >= 1 AND daily_function <= 10)),
    CONSTRAINT valid_satisfaction CHECK (therapy_satisfaction IS NULL OR (therapy_satisfaction >= 1 AND therapy_satisfaction <= 10)),
    CONSTRAINT valid_goal_progress CHECK (goal_1_progress IS NULL OR (goal_1_progress >= 0 AND goal_1_progress <= 100))
);

-- ============================================================================
-- EXERCISES_CATALOG TABLE (Exercise Library)
-- ============================================================================

CREATE TABLE IF NOT EXISTS exercises_catalog (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Exercise Information
    name VARCHAR(255) NOT NULL UNIQUE,
    description TEXT NOT NULL,
    instructions TEXT NOT NULL,
    
    -- Technical Details
    category VARCHAR(100) NOT NULL, -- stretching, strengthening, balance, mobility, relaxation, etc.
    difficulty_level VARCHAR(50), -- beginner, intermediate, advanced
    duration_seconds INT, -- Duration in seconds
    repetitions INT, -- Number of repetitions
    sets INT, -- Number of sets
    
    -- Media
    image_url VARCHAR(512),
    video_url VARCHAR(512),
    
    -- Clinical Information
    benefits TEXT,
    contraindications TEXT, -- When NOT to do this exercise
    precautions TEXT,
    
    -- Metadata
    created_by UUID NOT NULL REFERENCES profiles(user_id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    active BOOLEAN DEFAULT true,
    
    CONSTRAINT valid_duration CHECK (duration_seconds IS NULL OR duration_seconds > 0),
    CONSTRAINT valid_repetitions CHECK (repetitions IS NULL OR repetitions > 0),
    CONSTRAINT valid_sets CHECK (sets IS NULL OR sets > 0)
);

-- ============================================================================
-- EMOTIONS_CATALOG TABLE (Emotions Library)
-- ============================================================================

CREATE TABLE IF NOT EXISTS emotions_catalog (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Emotion Information
    name VARCHAR(100) NOT NULL UNIQUE,
    spanish_name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    
    -- Characteristics
    intensity emotion_intensity DEFAULT 'moderate',
    color_code VARCHAR(7), -- HEX color for UI representation
    
    -- Related Information
    physical_symptoms TEXT, -- How it manifests physically
    behavioral_responses TEXT, -- Common behaviors
    triggers TEXT, -- Common triggers
    coping_strategies TEXT, -- Recommended coping strategies
    
    -- Metadata
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    active BOOLEAN DEFAULT true,
    
    CONSTRAINT valid_color CHECK (color_code IS NULL OR color_code ~ '^#[0-9A-F]{6}$')
);

-- ============================================================================
-- PATIENT_EXERCISES TABLE (Assigned Exercises to Patients)
-- ============================================================================

CREATE TABLE IF NOT EXISTS patient_exercises (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    exercise_id UUID NOT NULL REFERENCES exercises_catalog(id) ON DELETE RESTRICT,
    therapist_id UUID NOT NULL REFERENCES profiles(user_id) ON DELETE SET NULL,
    
    -- Assignment Details
    assigned_date DATE DEFAULT CURRENT_DATE,
    start_date DATE NOT NULL,
    end_date DATE,
    
    -- Frequency
    frequency_per_week INT DEFAULT 3, -- How many times per week
    frequency_per_day INT DEFAULT 1, -- How many times per day
    
    -- Status
    status VARCHAR(50) DEFAULT 'active', -- active, completed, abandoned
    completed_count INT DEFAULT 0, -- How many times completed
    
    -- Notes
    specific_instructions TEXT, -- Patient-specific modifications
    
    -- Metadata
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT valid_frequency CHECK (frequency_per_week > 0),
    CONSTRAINT valid_daily_frequency CHECK (frequency_per_day > 0),
    CONSTRAINT valid_completed CHECK (completed_count >= 0),
    CONSTRAINT valid_dates CHECK (start_date <= end_date OR end_date IS NULL)
);

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================

-- Profiles indexes
CREATE INDEX idx_profiles_role ON profiles(role);
CREATE INDEX idx_profiles_active ON profiles(active);
CREATE INDEX idx_profiles_email ON profiles(email);
CREATE INDEX idx_profiles_user_id ON profiles(user_id);

-- Patients indexes
CREATE INDEX idx_patients_status ON patients(status);
CREATE INDEX idx_patients_created_by ON patients(created_by);
CREATE INDEX idx_patients_intake_date ON patients(intake_date);
CREATE INDEX idx_patients_email ON patients(email);
CREATE INDEX idx_patients_phone ON patients(phone);

-- Sessions indexes
CREATE INDEX idx_sessions_patient_id ON sessions(patient_id);
CREATE INDEX idx_sessions_therapist_id ON sessions(therapist_id);
CREATE INDEX idx_sessions_session_date ON sessions(session_date);
CREATE INDEX idx_sessions_status ON sessions(status);
CREATE INDEX idx_sessions_created_by ON sessions(created_by);

-- SOAP Notes indexes
CREATE INDEX idx_soap_notes_session_id ON soap_notes(session_id);
CREATE INDEX idx_soap_notes_patient_id ON soap_notes(patient_id);
CREATE INDEX idx_soap_notes_therapist_id ON soap_notes(therapist_id);
CREATE INDEX idx_soap_notes_created_at ON soap_notes(created_at);

-- Clinical Files indexes
CREATE INDEX idx_clinical_files_patient_id ON clinical_files(patient_id);
CREATE INDEX idx_clinical_files_session_id ON clinical_files(session_id);
CREATE INDEX idx_clinical_files_document_type ON clinical_files(document_type);
CREATE INDEX idx_clinical_files_uploaded_by ON clinical_files(uploaded_by);

-- Improvement Feedback indexes
CREATE INDEX idx_improvement_patient_id ON improvement_feedback(patient_id);
CREATE INDEX idx_improvement_session_id ON improvement_feedback(session_id);
CREATE INDEX idx_improvement_therapist_id ON improvement_feedback(therapist_id);
CREATE INDEX idx_improvement_created_at ON improvement_feedback(created_at);

-- Patient Exercises indexes
CREATE INDEX idx_patient_exercises_patient_id ON patient_exercises(patient_id);
CREATE INDEX idx_patient_exercises_exercise_id ON patient_exercises(exercise_id);
CREATE INDEX idx_patient_exercises_therapist_id ON patient_exercises(therapist_id);
CREATE INDEX idx_patient_exercises_status ON patient_exercises(status);

-- ============================================================================
-- ROW LEVEL SECURITY (RLS) - Enable & Configure
-- ============================================================================

-- Enable RLS on all tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE patients ENABLE ROW LEVEL SECURITY;
ALTER TABLE sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE soap_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE clinical_files ENABLE ROW LEVEL SECURITY;
ALTER TABLE improvement_feedback ENABLE ROW LEVEL SECURITY;
ALTER TABLE exercises_catalog ENABLE ROW LEVEL SECURITY;
ALTER TABLE emotions_catalog ENABLE ROW LEVEL SECURITY;
ALTER TABLE patient_exercises ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- HELPER FUNCTION: Get current user role
-- ============================================================================

CREATE OR REPLACE FUNCTION get_user_role()
RETURNS user_role AS $$
  SELECT role FROM profiles WHERE user_id = auth.uid() LIMIT 1;
$$ LANGUAGE SQL SECURITY DEFINER;

-- ============================================================================
-- RLS POLICIES: PROFILES
-- ============================================================================

-- Admins can see all profiles
CREATE POLICY "admins_view_all_profiles" ON profiles
    FOR SELECT TO authenticated
    USING (
        (SELECT role FROM profiles WHERE user_id = auth.uid()) = 'admin'
    );

-- Therapists and reception can see all active profiles
CREATE POLICY "staff_view_active_profiles" ON profiles
    FOR SELECT TO authenticated
    USING (
        active = true AND 
        (SELECT role FROM profiles WHERE user_id = auth.uid()) IN ('therapist', 'reception')
    );

-- Users can view their own profile
CREATE POLICY "users_view_own_profile" ON profiles
    FOR SELECT TO authenticated
    USING (user_id = auth.uid());

-- Admins can insert profiles
CREATE POLICY "admins_insert_profiles" ON profiles
    FOR INSERT TO authenticated
    WITH CHECK (
        (SELECT role FROM profiles WHERE user_id = auth.uid()) = 'admin'
    );

-- Admins can update profiles
CREATE POLICY "admins_update_profiles" ON profiles
    FOR UPDATE TO authenticated
    USING ((SELECT role FROM profiles WHERE user_id = auth.uid()) = 'admin')
    WITH CHECK ((SELECT role FROM profiles WHERE user_id = auth.uid()) = 'admin');

-- Users can update their own profile
CREATE POLICY "users_update_own_profile" ON profiles
    FOR UPDATE TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- ============================================================================
-- RLS POLICIES: PATIENTS
-- ============================================================================

-- Admins can see all patients
CREATE POLICY "admins_view_all_patients" ON patients
    FOR SELECT TO authenticated
    USING (
        (SELECT role FROM profiles WHERE user_id = auth.uid()) = 'admin'
    );

-- Therapists can see patients assigned to them
CREATE POLICY "therapists_view_assigned_patients" ON patients
    FOR SELECT TO authenticated
    USING (
        (SELECT role FROM profiles WHERE user_id = auth.uid()) = 'therapist' AND
        id IN (
            SELECT DISTINCT patient_id FROM sessions 
            WHERE therapist_id = auth.uid()
        )
    );

-- Reception can see all patients (for scheduling)
CREATE POLICY "reception_view_all_patients" ON patients
    FOR SELECT TO authenticated
    USING (
        (SELECT role FROM profiles WHERE user_id = auth.uid()) = 'reception'
    );

-- Admins and therapists can insert patients
CREATE POLICY "staff_insert_patients" ON patients
    FOR INSERT TO authenticated
    WITH CHECK (
        (SELECT role FROM profiles WHERE user_id = auth.uid()) IN ('admin', 'therapist', 'reception')
    );

-- Admins and therapists can update patients
CREATE POLICY "staff_update_patients" ON patients
    FOR UPDATE TO authenticated
    USING (
        (SELECT role FROM profiles WHERE user_id = auth.uid()) IN ('admin', 'therapist')
    )
    WITH CHECK (
        (SELECT role FROM profiles WHERE user_id = auth.uid()) IN ('admin', 'therapist')
    );

-- ============================================================================
-- RLS POLICIES: SESSIONS
-- ============================================================================

-- Admins can see all sessions
CREATE POLICY "admins_view_all_sessions" ON sessions
    FOR SELECT TO authenticated
    USING (
        (SELECT role FROM profiles WHERE user_id = auth.uid()) = 'admin'
    );

-- Therapists can see their own sessions
CREATE POLICY "therapists_view_own_sessions" ON sessions
    FOR SELECT TO authenticated
    USING (
        therapist_id = auth.uid()
    );

-- Therapists can see sessions for patients they work with
CREATE POLICY "therapists_view_patient_sessions" ON sessions
    FOR SELECT TO authenticated
    USING (
        (SELECT role FROM profiles WHERE user_id = auth.uid()) = 'therapist' AND
        patient_id IN (
            SELECT DISTINCT patient_id FROM sessions 
            WHERE therapist_id = auth.uid()
        )
    );

-- Reception can see all sessions (for scheduling)
CREATE POLICY "reception_view_all_sessions" ON sessions
    FOR SELECT TO authenticated
    USING (
        (SELECT role FROM profiles WHERE user_id = auth.uid()) = 'reception'
    );

-- Admins can insert sessions
CREATE POLICY "admins_insert_sessions" ON sessions
    FOR INSERT TO authenticated
    WITH CHECK (
        (SELECT role FROM profiles WHERE user_id = auth.uid()) = 'admin'
    );

-- Reception can insert sessions
CREATE POLICY "reception_insert_sessions" ON sessions
    FOR INSERT TO authenticated
    WITH CHECK (
        (SELECT role FROM profiles WHERE user_id = auth.uid()) = 'reception'
    );

-- Therapists can insert their own sessions
CREATE POLICY "therapists_insert_own_sessions" ON sessions
    FOR INSERT TO authenticated
    WITH CHECK (
        therapist_id = auth.uid() AND
        (SELECT role FROM profiles WHERE user_id = auth.uid()) = 'therapist'
    );

-- Admins and therapists can update sessions
CREATE POLICY "staff_update_sessions" ON sessions
    FOR UPDATE TO authenticated
    USING (
        (SELECT role FROM profiles WHERE user_id = auth.uid()) IN ('admin', 'therapist')
    )
    WITH CHECK (
        (SELECT role FROM profiles WHERE user_id = auth.uid()) IN ('admin', 'therapist')
    );

-- ============================================================================
-- RLS POLICIES: SOAP_NOTES
-- ============================================================================

-- Admins can see all SOAP notes
CREATE POLICY "admins_view_all_soap_notes" ON soap_notes
    FOR SELECT TO authenticated
    USING (
        (SELECT role FROM profiles WHERE user_id = auth.uid()) = 'admin'
    );

-- Therapists can see SOAP notes for their sessions
CREATE POLICY "therapists_view_own_soap_notes" ON soap_notes
    FOR SELECT TO authenticated
    USING (
        therapist_id = auth.uid()
    );

-- Therapists can see SOAP notes for patients they work with
CREATE POLICY "therapists_view_patient_soap_notes" ON soap_notes
    FOR SELECT TO authenticated
    USING (
        (SELECT role FROM profiles WHERE user_id = auth.uid()) = 'therapist' AND
        patient_id IN (
            SELECT DISTINCT patient_id FROM sessions 
            WHERE therapist_id = auth.uid()
        )
    );

-- Only therapist who created SOAP note can edit
CREATE POLICY "therapists_update_own_soap_notes" ON soap_notes
    FOR UPDATE TO authenticated
    USING (
        therapist_id = auth.uid()
    )
    WITH CHECK (
        therapist_id = auth.uid()
    );

-- Only therapist can insert SOAP notes
CREATE POLICY "therapists_insert_soap_notes" ON soap_notes
    FOR INSERT TO authenticated
    WITH CHECK (
        therapist_id = auth.uid() AND
        (SELECT role FROM profiles WHERE user_id = auth.uid()) = 'therapist'
    );

-- ============================================================================
-- RLS POLICIES: CLINICAL_FILES
-- ============================================================================

-- Admins can see all files
CREATE POLICY "admins_view_all_clinical_files" ON clinical_files
    FOR SELECT TO authenticated
    USING (
        (SELECT role FROM profiles WHERE user_id = auth.uid()) = 'admin'
    );

-- Therapists can see files for their patients
CREATE POLICY "therapists_view_patient_files" ON clinical_files
    FOR SELECT TO authenticated
    USING (
        (SELECT role FROM profiles WHERE user_id = auth.uid()) = 'therapist' AND
        patient_id IN (
            SELECT DISTINCT patient_id FROM sessions 
            WHERE therapist_id = auth.uid()
        )
    );

-- Reception can see all files
CREATE POLICY "reception_view_all_files" ON clinical_files
    FOR SELECT TO authenticated
    USING (
        (SELECT role FROM profiles WHERE user_id = auth.uid()) = 'reception'
    );

-- Staff can insert files
CREATE POLICY "staff_insert_clinical_files" ON clinical_files
    FOR INSERT TO authenticated
    WITH CHECK (
        (SELECT role FROM profiles WHERE user_id = auth.uid()) IN ('admin', 'therapist', 'reception')
    );

-- ============================================================================
-- RLS POLICIES: IMPROVEMENT_FEEDBACK
-- ============================================================================

-- Admins can see all feedback
CREATE POLICY "admins_view_all_feedback" ON improvement_feedback
    FOR SELECT TO authenticated
    USING (
        (SELECT role FROM profiles WHERE user_id = auth.uid()) = 'admin'
    );

-- Therapists can see feedback for their patients
CREATE POLICY "therapists_view_patient_feedback" ON improvement_feedback
    FOR SELECT TO authenticated
    USING (
        (SELECT role FROM profiles WHERE user_id = auth.uid()) = 'therapist' AND
        patient_id IN (
            SELECT DISTINCT patient_id FROM sessions 
            WHERE therapist_id = auth.uid()
        )
    );

-- Only therapist can insert feedback
CREATE POLICY "therapists_insert_feedback" ON improvement_feedback
    FOR INSERT TO authenticated
    WITH CHECK (
        therapist_id = auth.uid() AND
        (SELECT role FROM profiles WHERE user_id = auth.uid()) = 'therapist'
    );

-- Only therapist can update own feedback
CREATE POLICY "therapists_update_own_feedback" ON improvement_feedback
    FOR UPDATE TO authenticated
    USING (
        therapist_id = auth.uid()
    )
    WITH CHECK (
        therapist_id = auth.uid()
    );

-- ============================================================================
-- RLS POLICIES: EXERCISES_CATALOG
-- ============================================================================

-- All authenticated users can view exercises
CREATE POLICY "all_view_exercises" ON exercises_catalog
    FOR SELECT TO authenticated
    USING (active = true);

-- Admins can insert exercises
CREATE POLICY "admins_insert_exercises" ON exercises_catalog
    FOR INSERT TO authenticated
    WITH CHECK (
        (SELECT role FROM profiles WHERE user_id = auth.uid()) = 'admin'
    );

-- Admins can update exercises
CREATE POLICY "admins_update_exercises" ON exercises_catalog
    FOR UPDATE TO authenticated
    USING (
        (SELECT role FROM profiles WHERE user_id = auth.uid()) = 'admin'
    )
    WITH CHECK (
        (SELECT role FROM profiles WHERE user_id = auth.uid()) = 'admin'
    );

-- ============================================================================
-- RLS POLICIES: EMOTIONS_CATALOG
-- ============================================================================

-- All authenticated users can view emotions
CREATE POLICY "all_view_emotions" ON emotions_catalog
    FOR SELECT TO authenticated
    USING (active = true);

-- Admins can insert emotions
CREATE POLICY "admins_insert_emotions" ON emotions_catalog
    FOR INSERT TO authenticated
    WITH CHECK (
        (SELECT role FROM profiles WHERE user_id = auth.uid()) = 'admin'
    );

-- Admins can update emotions
CREATE POLICY "admins_update_emotions" ON emotions_catalog
    FOR UPDATE TO authenticated
    USING (
        (SELECT role FROM profiles WHERE user_id = auth.uid()) = 'admin'
    )
    WITH CHECK (
        (SELECT role FROM profiles WHERE user_id = auth.uid()) = 'admin'
    );

-- ============================================================================
-- RLS POLICIES: PATIENT_EXERCISES
-- ============================================================================

-- Admins can see all assignments
CREATE POLICY "admins_view_all_patient_exercises" ON patient_exercises
    FOR SELECT TO authenticated
    USING (
        (SELECT role FROM profiles WHERE user_id = auth.uid()) = 'admin'
    );

-- Therapists can see assignments for their patients
CREATE POLICY "therapists_view_patient_exercises" ON patient_exercises
    FOR SELECT TO authenticated
    USING (
        (SELECT role FROM profiles WHERE user_id = auth.uid()) = 'therapist' AND
        patient_id IN (
            SELECT DISTINCT patient_id FROM sessions 
            WHERE therapist_id = auth.uid()
        )
    );

-- Only therapist can insert assignments
CREATE POLICY "therapists_insert_patient_exercises" ON patient_exercises
    FOR INSERT TO authenticated
    WITH CHECK (
        therapist_id = auth.uid() AND
        (SELECT role FROM profiles WHERE user_id = auth.uid()) = 'therapist'
    );

-- Only therapist can update assignments
CREATE POLICY "therapists_update_patient_exercises" ON patient_exercises
    FOR UPDATE TO authenticated
    USING (
        therapist_id = auth.uid()
    )
    WITH CHECK (
        therapist_id = auth.uid()
    );

-- ============================================================================
-- TRIGGERS FOR UPDATED_AT TIMESTAMPS
-- ============================================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_patients_updated_at BEFORE UPDATE ON patients
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_sessions_updated_at BEFORE UPDATE ON sessions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_soap_notes_updated_at BEFORE UPDATE ON soap_notes
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_improvement_feedback_updated_at BEFORE UPDATE ON improvement_feedback
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_exercises_catalog_updated_at BEFORE UPDATE ON exercises_catalog
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_emotions_catalog_updated_at BEFORE UPDATE ON emotions_catalog
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_patient_exercises_updated_at BEFORE UPDATE ON patient_exercises
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- END OF SCHEMA
-- ============================================================================
