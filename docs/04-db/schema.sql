-- DDL Скрипт базы данных ГИС «Господдержка» (Модуль 1)
-- СУБД: PostgreSQL 14+

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =============================================================================
-- 1. ТАБЛИЦА: Компании / Предприятия (Заявители)
-- =============================================================================
CREATE TABLE IF NOT EXISTS companies (
    id BIGSERIAL PRIMARY KEY,
    inn VARCHAR(10) NOT NULL UNIQUE,
    kpp VARCHAR(9),
    ogrn VARCHAR(13),
    name VARCHAR(255) NOT NULL,
    legal_address TEXT,
    okved VARCHAR(10) NOT NULL,
    revenue_last_year NUMERIC(15, 2) DEFAULT 0.00,
    tax_debt NUMERIC(15, 2) DEFAULT 0.00,
    is_bankrupt BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT chk_inn_length CHECK (LENGTH(inn) = 10)
);

COMMENT ON TABLE companies IS 'Справочник профилей юридических лиц (предприятий)';
COMMENT ON COLUMN companies.inn IS 'ИНН компании (10 цифр)';
COMMENT ON COLUMN companies.tax_debt IS 'Текущая задолженность по налогам из API ФНС';

-- =============================================================================
-- 2. ТАБЛИЦА: Заявки на государственную поддержку
-- =============================================================================
CREATE TABLE IF NOT EXISTS applications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    application_number VARCHAR(50) NOT NULL UNIQUE,
    company_id BIGINT NOT NULL,
    subsidy_type VARCHAR(100) NOT NULL,
    requested_amount NUMERIC(15, 2) NOT NULL,
    project_title VARCHAR(255) NOT NULL,
    project_description TEXT,
    status VARCHAR(50) NOT NULL,
    rejection_reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_applications_company FOREIGN KEY (company_id) 
        REFERENCES companies(id) ON DELETE RESTRICT,
    CONSTRAINT chk_requested_amount CHECK (requested_amount > 0 AND requested_amount <= 500000000.00),
    CONSTRAINT chk_status CHECK (status IN (
        'DRAFT', 
        'SUBMITTED', 
        'REJECTED_AUTO', 
        'UNDER_MANUAL_REVIEW', 
        'RECOMMENDED_APPROVE', 
        'APPROVED', 
        'REJECTED_MANUAL'
    ))
);

COMMENT ON TABLE applications IS 'Заявки предприятий на получение льготных займов/субсидий';

-- =============================================================================
-- 3. ТАБЛИЦА: Результаты автопроверок и AI-скоринга
-- =============================================================================
CREATE TABLE IF NOT EXISTS scoring_results (
    id BIGSERIAL PRIMARY KEY,
    application_id UUID NOT NULL UNIQUE,
    score_value INT NOT NULL,
    stop_factors JSONB DEFAULT '[]'::jsonb,
    risk_assessment JSONB DEFAULT '{}'::jsonb,
    recommendation VARCHAR(50) NOT NULL,
    calculated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_scoring_application FOREIGN KEY (application_id) 
        REFERENCES applications(id) ON DELETE CASCADE,
    CONSTRAINT chk_score_range CHECK (score_value BETWEEN 0 AND 100)
);

COMMENT ON TABLE scoring_results IS 'Результаты проверки стоп-факторов и оценки финансового рейтинга';

-- =============================================================================
-- 4. ТАБЛИЦА: Решения операторов Минпромторга
-- =============================================================================
CREATE TABLE IF NOT EXISTS decisions (
    id BIGSERIAL PRIMARY KEY,
    application_id UUID NOT NULL,
    operator_id VARCHAR(100) NOT NULL,
    decision_type VARCHAR(50) NOT NULL,
    comment TEXT,
    decided_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_decisions_application FOREIGN KEY (application_id) 
        REFERENCES applications(id) ON DELETE CASCADE,
    CONSTRAINT chk_decision_type CHECK (decision_type IN ('APPROVED', 'REJECTED'))
);

COMMENT ON TABLE decisions IS 'История решений операторов по заявкам';

-- =============================================================================
-- 5. ИНДЕКСЫ ДЛЯ ОПТИМИЗАЦИИ ЗАПРОСОВ
-- =============================================================================
CREATE INDEX idx_companies_inn ON companies(inn);
CREATE INDEX idx_applications_company_id ON applications(company_id);
CREATE INDEX idx_applications_status ON applications(status);
CREATE INDEX idx_applications_created_at ON applications(created_at DESC);
CREATE INDEX idx_scoring_application_id ON scoring_results(application_id);