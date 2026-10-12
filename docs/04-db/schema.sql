-- DDL-скрипт базы данных ГИС «Господдержка», Модуль 1
-- СУБД: PostgreSQL 14+

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =========================================================
-- 1. COMPANIES: предприятия
-- =========================================================

CREATE TABLE IF NOT EXISTS companies (
    id BIGSERIAL PRIMARY KEY,
    inn VARCHAR(10) NOT NULL UNIQUE,
    kpp VARCHAR(9),
    ogrn VARCHAR(13),
    name VARCHAR(255) NOT NULL,
    legal_address TEXT,
    okved VARCHAR(10),
    revenue_last_year NUMERIC(15, 2),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_companies_inn_format
        CHECK (inn ~ '^[0-9]{10}$'),

    CONSTRAINT chk_companies_kpp_format
        CHECK (kpp IS NULL OR kpp ~ '^[0-9]{9}$'),

    CONSTRAINT chk_companies_ogrn_format
        CHECK (ogrn IS NULL OR ogrn ~ '^[0-9]{13}$'),

    CONSTRAINT chk_companies_revenue
        CHECK (revenue_last_year IS NULL OR revenue_last_year >= 0)
);

COMMENT ON TABLE companies IS
    'Справочник профилей юридических лиц';

COMMENT ON COLUMN companies.inn IS
    'ИНН юридического лица: 10 цифр';

-- Результаты налоговых и юридических проверок не хранятся
-- в профиле компании: они привязываются к конкретной заявке
-- в таблице application_checks.


-- =========================================================
-- 2. APPLICATIONS: заявки
-- =========================================================

CREATE TABLE IF NOT EXISTS applications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    application_number VARCHAR(50) NOT NULL UNIQUE,
    company_id BIGINT NOT NULL,
    subsidy_type VARCHAR(100) NOT NULL,
    requested_amount NUMERIC(15, 2) NOT NULL,
    project_title VARCHAR(255) NOT NULL,
    project_description TEXT,
    status VARCHAR(30) NOT NULL DEFAULT 'DRAFT',
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_applications_company
        FOREIGN KEY (company_id)
        REFERENCES companies(id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_requested_amount
        CHECK (requested_amount > 0),

    CONSTRAINT chk_application_status
        CHECK (status IN (
            'DRAFT',
            'SUBMITTED',
            'DATA_CHECK',
            'NEEDS_REVISION',
            'UNDER_REVIEW',
            'APPROVED',
            'REJECTED'
        ))
);

COMMENT ON TABLE applications IS
    'Заявки предприятий на получение государственной поддержки';

COMMENT ON COLUMN applications.status IS
    'Текущий статус заявки согласно системным требованиям';


-- =========================================================
-- 3. APPLICATION_CHECKS: история проверок
-- =========================================================

CREATE TABLE IF NOT EXISTS application_checks (
    id BIGSERIAL PRIMARY KEY,
    application_id UUID NOT NULL,
    check_code VARCHAR(50) NOT NULL,
    provider VARCHAR(100) NOT NULL,
    check_status VARCHAR(20) NOT NULL,
    result_data JSONB,
    error_code VARCHAR(100),
    error_message TEXT,
    attempt_number INTEGER NOT NULL DEFAULT 1,
    checked_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_checks_application
        FOREIGN KEY (application_id)
        REFERENCES applications(id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_check_status
        CHECK (check_status IN (
            'PENDING',
            'PASSED',
            'STOP_FACTOR',
            'ERROR'
        )),

    CONSTRAINT chk_check_attempt_number
        CHECK (attempt_number > 0)
);

COMMENT ON TABLE application_checks IS
    'Результаты внешних проверок и история попыток их выполнения';

COMMENT ON COLUMN application_checks.check_status IS
    'PASSED: стоп-фактор не выявлен; STOP_FACTOR: правило сработало; ERROR: техническая ошибка; PENDING: проверка ожидает выполнения';

CREATE INDEX IF NOT EXISTS idx_checks_application_created
    ON application_checks(application_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_checks_status_created
    ON application_checks(check_status, created_at DESC);


-- =========================================================
-- 4. SCORING_RESULTS: результаты скоринга
-- =========================================================

CREATE TABLE IF NOT EXISTS scoring_results (
    id BIGSERIAL PRIMARY KEY,
    application_id UUID NOT NULL,
    score_value INTEGER NOT NULL,
    risk_assessment JSONB NOT NULL DEFAULT '{}'::jsonb,
    recommendation VARCHAR(30) NOT NULL,
    model_version VARCHAR(100),
    calculated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_scoring_application
        FOREIGN KEY (application_id)
        REFERENCES applications(id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_score_range
        CHECK (score_value BETWEEN 0 AND 100),

    CONSTRAINT chk_scoring_recommendation
        CHECK (recommendation IN (
            'REJECT',
            'MANUAL_REVIEW',
            'APPROVE'
        ))
);

COMMENT ON TABLE scoring_results IS
    'История результатов скоринга и рекомендаций';

CREATE INDEX IF NOT EXISTS idx_scoring_application_calculated
    ON scoring_results(application_id, calculated_at DESC);


-- =========================================================
-- 5. DECISIONS: решения оператора
-- =========================================================

CREATE TABLE IF NOT EXISTS decisions (
    id BIGSERIAL PRIMARY KEY,
    application_id UUID NOT NULL,
    operator_id VARCHAR(100) NOT NULL,
    decision_type VARCHAR(30) NOT NULL,
    comment TEXT,
    decided_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_decisions_application
        FOREIGN KEY (application_id)
        REFERENCES applications(id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_decision_type
        CHECK (decision_type IN (
            'APPROVED',
            'REJECTED',
            'NEEDS_REVISION'
        )),

    CONSTRAINT chk_decision_reason
        CHECK (
            decision_type = 'APPROVED'
            OR NULLIF(BTRIM(comment), '') IS NOT NULL
        )
);

COMMENT ON TABLE decisions IS
    'История решений оператора, включая возвраты на доработку';

CREATE INDEX IF NOT EXISTS idx_decisions_application_decided
    ON decisions(application_id, decided_at DESC);


-- =========================================================
-- 6. APPLICATION_STATUS_HISTORY: история статусов
-- =========================================================

CREATE TABLE IF NOT EXISTS application_status_history (
    id BIGSERIAL PRIMARY KEY,
    application_id UUID NOT NULL,
    previous_status VARCHAR(30),
    new_status VARCHAR(30) NOT NULL,
    changed_by_type VARCHAR(20) NOT NULL,
    changed_by_id VARCHAR(100),
    reason TEXT,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_status_history_application
        FOREIGN KEY (application_id)
        REFERENCES applications(id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_previous_status
        CHECK (
            previous_status IS NULL
            OR previous_status IN (
                'DRAFT',
                'SUBMITTED',
                'DATA_CHECK',
                'NEEDS_REVISION',
                'UNDER_REVIEW',
                'APPROVED',
                'REJECTED'
            )
        ),

    CONSTRAINT chk_new_status
        CHECK (new_status IN (
            'DRAFT',
            'SUBMITTED',
            'DATA_CHECK',
            'NEEDS_REVISION',
            'UNDER_REVIEW',
            'APPROVED',
            'REJECTED'
        )),

    CONSTRAINT chk_status_actor_type
        CHECK (changed_by_type IN (
            'APPLICANT',
            'OPERATOR',
            'SYSTEM'
        ))
);

COMMENT ON TABLE application_status_history IS
    'История переходов между статусами заявок';

CREATE INDEX IF NOT EXISTS idx_status_history_application_changed
    ON application_status_history(application_id, changed_at DESC);


-- =========================================================
-- 7. INTEGRATION_DELIVERIES: доставка данных в другие модули
-- =========================================================

CREATE TABLE IF NOT EXISTS integration_deliveries (
    id BIGSERIAL PRIMARY KEY,
    application_id UUID NOT NULL,
    target_module VARCHAR(20) NOT NULL,
    delivery_status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    attempt_count INTEGER NOT NULL DEFAULT 0,
    last_error TEXT,
    last_attempt_at TIMESTAMPTZ,
    sent_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_deliveries_application
        FOREIGN KEY (application_id)
        REFERENCES applications(id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_delivery_target
        CHECK (target_module IN ('MODULE_2', 'MODULE_3')),

    CONSTRAINT chk_delivery_status
        CHECK (delivery_status IN (
            'PENDING',
            'SENT',
            'FAILED'
        )),

    CONSTRAINT chk_delivery_attempt_count
        CHECK (attempt_count >= 0),

    CONSTRAINT uq_application_target_module
        UNIQUE (application_id, target_module)
);

COMMENT ON TABLE integration_deliveries IS
    'Состояние доставки данных в Модуль 2 и Модуль 3';

CREATE INDEX IF NOT EXISTS idx_deliveries_status_updated
    ON integration_deliveries(delivery_status, updated_at DESC);


-- =========================================================
-- 8. Автоматическое обновление updated_at
-- =========================================================

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_companies_updated_at ON companies;

CREATE TRIGGER trg_companies_updated_at
BEFORE UPDATE ON companies
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_applications_updated_at ON applications;

CREATE TRIGGER trg_applications_updated_at
BEFORE UPDATE ON applications
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_deliveries_updated_at ON integration_deliveries;

CREATE TRIGGER trg_deliveries_updated_at
BEFORE UPDATE ON integration_deliveries
FOR EACH ROW
EXECUTE FUNCTION set_updated_at();


-- =========================================================
-- 9. Комментарии по эксплуатации
-- =========================================================

COMMENT ON COLUMN applications.requested_amount IS
    'Запрашиваемая сумма поддержки в рублях; сумма должна быть положительной';

COMMENT ON COLUMN scoring_results.recommendation IS
    'REJECT: отклонение по учебным правилам; MANUAL_REVIEW: ручная проверка; APPROVE: рекомендация к одобрению';

COMMENT ON COLUMN integration_deliveries.attempt_count IS
    'Количество выполненных попыток передачи данных';