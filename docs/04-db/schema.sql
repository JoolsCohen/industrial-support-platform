-- DDL bootstrap для PostgreSQL 14+
-- ГИС «Господдержка», Модуль 1.
-- Скрипт предназначен для создания схемы с нуля.
-- CREATE TABLE IF NOT EXISTS не является миграцией существующих таблиц.

-- =========================================================
-- 1. COMPANIES: профиль предприятия
-- =========================================================

CREATE TABLE IF NOT EXISTS companies (
    id BIGSERIAL PRIMARY KEY,
    inn VARCHAR(10) NOT NULL UNIQUE,
    kpp VARCHAR(9),
    ogrn VARCHAR(13),
    full_name VARCHAR(255),
    short_name VARCHAR(255),
    legal_status VARCHAR(30) NOT NULL DEFAULT 'OTHER',
    registration_date DATE,
    legal_address TEXT,
    okved_main_code VARCHAR(10),
    okved_main_name TEXT,
    last_registry_sync_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT chk_companies_inn_format
        CHECK (inn ~ '^[0-9]{10}$'),
    CONSTRAINT chk_companies_kpp_format
        CHECK (kpp IS NULL OR kpp ~ '^[0-9]{9}$'),
    CONSTRAINT chk_companies_ogrn_format
        CHECK (ogrn IS NULL OR ogrn ~ '^[0-9]{13}$'),
    CONSTRAINT chk_companies_legal_status
        CHECK (legal_status IN ('ACTIVE', 'IN_LIQUIDATION', 'LIQUIDATED', 'OTHER'))
);

COMMENT ON TABLE companies IS
    'Профили юридических лиц. Неполный профиль допускается для незавершённого черновика.';
COMMENT ON COLUMN companies.inn IS
    'ИНН юридического лица, 10 цифр. Контрольное число дополнительно проверяется приложением.';
COMMENT ON COLUMN companies.legal_status IS
    'Нормализованный юридический статус из внешнего реестра.';


-- =========================================================
-- 2. COMPANY_FINANCIAL_SNAPSHOTS: финансовые снимки
-- =========================================================

CREATE TABLE IF NOT EXISTS company_financial_snapshots (
    id BIGSERIAL PRIMARY KEY,
    company_id BIGINT NOT NULL,
    reporting_year SMALLINT,
    revenue NUMERIC(15, 2),
    net_profit NUMERIC(15, 2),
    tax_debt_amount NUMERIC(15, 2),
    has_tax_debt BOOLEAN,
    is_in_bankruptcy_process BOOLEAN,
    source_provider VARCHAR(100) NOT NULL DEFAULT 'FNS',
    fetched_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_financial_snapshots_company
        FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE RESTRICT,
    CONSTRAINT chk_financial_reporting_year
        CHECK (reporting_year IS NULL OR reporting_year >= 1900),
    CONSTRAINT chk_financial_revenue
        CHECK (revenue IS NULL OR revenue >= 0),
    CONSTRAINT chk_financial_tax_debt
        CHECK (tax_debt_amount IS NULL OR tax_debt_amount >= 0)
);

COMMENT ON TABLE company_financial_snapshots IS
    'Снимки финансовых индикаторов для автозаполнения и отображения. Бизнес-проверки по заявке также фиксируются в application_checks.';

CREATE INDEX IF NOT EXISTS idx_financial_snapshots_company_fetched
    ON company_financial_snapshots(company_id, fetched_at DESC);


-- =========================================================
-- 3. APPLICATIONS: заявки
-- =========================================================

CREATE TABLE IF NOT EXISTS applications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    application_number VARCHAR(50) NOT NULL UNIQUE,
    company_id BIGINT NOT NULL,
    subsidy_type VARCHAR(100),
    requested_amount NUMERIC(15, 2),
    project_title VARCHAR(255),
    project_description TEXT,
    implementation_period_months INTEGER,
    planned_jobs_created INTEGER,
    status VARCHAR(30) NOT NULL DEFAULT 'DRAFT',
    rejection_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_applications_company
        FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE RESTRICT,
    CONSTRAINT chk_applications_requested_amount
        CHECK (
            requested_amount IS NULL
            OR (requested_amount > 0 AND requested_amount <= 500000000.00)
        ),
    CONSTRAINT chk_applications_implementation_period
        CHECK (implementation_period_months IS NULL OR implementation_period_months >= 1),
    CONSTRAINT chk_applications_planned_jobs
        CHECK (planned_jobs_created IS NULL OR planned_jobs_created >= 0),
    CONSTRAINT chk_applications_status
        CHECK (status IN (
            'DRAFT', 'SUBMITTED', 'DATA_CHECK', 'NEEDS_REVISION',
            'UNDER_REVIEW', 'APPROVED', 'REJECTED'
        )),
    CONSTRAINT chk_submitted_applications_required_fields
        CHECK (
            status = 'DRAFT'
            OR (
                NULLIF(BTRIM(subsidy_type), '') IS NOT NULL
                AND requested_amount IS NOT NULL
                AND NULLIF(BTRIM(project_title), '') IS NOT NULL
            )
        ),
    CONSTRAINT chk_rejected_application_reason
        CHECK (
            status <> 'REJECTED'
            OR NULLIF(BTRIM(rejection_reason), '') IS NOT NULL
        )
);

COMMENT ON TABLE applications IS
    'Заявки предприятий. Черновик может быть неполным; обязательные поля требуются до отправки.';
COMMENT ON COLUMN applications.rejection_reason IS
    'Текущее отображаемое основание отклонения; полная история решений хранится в decisions.';
COMMENT ON COLUMN applications.status IS
    'Бизнес-статус заявки; рекомендация скоринга хранится отдельно.';

CREATE INDEX IF NOT EXISTS idx_applications_company
    ON applications(company_id);
CREATE INDEX IF NOT EXISTS idx_applications_status_created
    ON applications(status, created_at DESC);


-- =========================================================
-- 4. APPLICATION_CONTACTS: контакт заявителя по заявке
-- =========================================================

CREATE TABLE IF NOT EXISTS application_contacts (
    application_id UUID PRIMARY KEY,
    full_name VARCHAR(255) NOT NULL,
    email VARCHAR(254) NOT NULL,
    phone VARCHAR(30) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_application_contacts_application
        FOREIGN KEY (application_id) REFERENCES applications(id) ON DELETE RESTRICT,
    CONSTRAINT chk_application_contact_name
        CHECK (NULLIF(BTRIM(full_name), '') IS NOT NULL),
    CONSTRAINT chk_application_contact_email
        CHECK (NULLIF(BTRIM(email), '') IS NOT NULL),
    CONSTRAINT chk_application_contact_phone
        CHECK (NULLIF(BTRIM(phone), '') IS NOT NULL)
);

COMMENT ON TABLE application_contacts IS
    'Контактные данные заявителя для одной заявки; запись может отсутствовать у незаполненного черновика.';
COMMENT ON COLUMN application_contacts.email IS
    'Персональные данные. Доступ и журналирование должны ограничиваться установленными полномочиями.';


-- =========================================================
-- 5. APPLICATION_DOCUMENTS: метаданные документов
-- =========================================================

CREATE TABLE IF NOT EXISTS application_documents (
    id BIGSERIAL PRIMARY KEY,
    application_id UUID NOT NULL,
    document_type VARCHAR(100) NOT NULL,
    file_name VARCHAR(255) NOT NULL,
    storage_key VARCHAR(500) NOT NULL UNIQUE,
    mime_type VARCHAR(255) NOT NULL,
    size_bytes BIGINT NOT NULL,
    checksum_sha256 VARCHAR(64) NOT NULL,
    description VARCHAR(1000),
    uploaded_by VARCHAR(100) NOT NULL,
    uploaded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    validation_status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    validation_error TEXT,
    deleted_at TIMESTAMPTZ,
    deleted_by VARCHAR(100),

    CONSTRAINT fk_application_documents_application
        FOREIGN KEY (application_id) REFERENCES applications(id) ON DELETE RESTRICT,
    CONSTRAINT chk_document_size
        CHECK (size_bytes >= 0),
    CONSTRAINT chk_document_checksum
        CHECK (checksum_sha256 ~ '^[A-Fa-f0-9]{64}$'),
    CONSTRAINT chk_document_validation_status
        CHECK (validation_status IN ('PENDING', 'ACCEPTED', 'REJECTED', 'ERROR')),
    CONSTRAINT chk_document_deleted_fields
        CHECK ((deleted_at IS NULL AND deleted_by IS NULL) OR (deleted_at IS NOT NULL AND deleted_by IS NOT NULL))
);

COMMENT ON TABLE application_documents IS
    'Метаданные прикреплённых документов. Бинарные файлы находятся во внешнем защищённом хранилище.';
COMMENT ON COLUMN application_documents.storage_key IS
    'Внутренний ключ объекта в хранилище; не должен раскрываться как публичный URL.';
COMMENT ON COLUMN application_documents.validation_status IS
    'Состояние проверки файла по политике конфигурации: PENDING, ACCEPTED, REJECTED или ERROR.';

CREATE INDEX IF NOT EXISTS idx_application_documents_application
    ON application_documents(application_id, uploaded_at DESC)
    WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_application_documents_validation
    ON application_documents(validation_status, uploaded_at DESC);


-- =========================================================
-- 6. APPLICATION_CHECKS: история проверок
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
        FOREIGN KEY (application_id) REFERENCES applications(id) ON DELETE RESTRICT,
    CONSTRAINT chk_check_status
        CHECK (check_status IN ('PENDING', 'PASSED', 'STOP_FACTOR', 'ERROR')),
    CONSTRAINT chk_check_attempt_number
        CHECK (attempt_number > 0),
    CONSTRAINT uq_check_attempt
        UNIQUE (application_id, check_code, provider, attempt_number)
);

COMMENT ON TABLE application_checks IS
    'Результаты внешних проверок и повторных попыток; техническая ошибка не равна отрицательному бизнес-результату.';

CREATE INDEX IF NOT EXISTS idx_checks_application_created
    ON application_checks(application_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_checks_status_created
    ON application_checks(check_status, created_at DESC);


-- =========================================================
-- 7. SCORING_RESULTS: история результатов скоринга
-- =========================================================

CREATE TABLE IF NOT EXISTS scoring_results (
    id BIGSERIAL PRIMARY KEY,
    application_id UUID NOT NULL,
    score_value INTEGER NOT NULL,
    recommendation VARCHAR(30) NOT NULL,
    model_version VARCHAR(100),
    risk_assessment JSONB NOT NULL DEFAULT '{}'::jsonb,
    calculated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_scoring_application
        FOREIGN KEY (application_id) REFERENCES applications(id) ON DELETE RESTRICT,
    CONSTRAINT chk_score_range
        CHECK (score_value BETWEEN 0 AND 100),
    CONSTRAINT chk_scoring_recommendation
        CHECK (recommendation IN ('REJECT', 'MANUAL_REVIEW', 'APPROVE'))
);

COMMENT ON TABLE scoring_results IS
    'История результатов скоринга; риск-оценка хранится в структуре, соответствующей API ScoringResult.risk_assessment.';

CREATE INDEX IF NOT EXISTS idx_scoring_application_calculated
    ON scoring_results(application_id, calculated_at DESC);


-- =========================================================
-- 8. DECISIONS: решения оператора
-- =========================================================

CREATE TABLE IF NOT EXISTS decisions (
    id BIGSERIAL PRIMARY KEY,
    application_id UUID NOT NULL,
    operator_id VARCHAR(100) NOT NULL,
    decision_type VARCHAR(30) NOT NULL,
    comment TEXT,
    decided_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_decisions_application
        FOREIGN KEY (application_id) REFERENCES applications(id) ON DELETE RESTRICT,
    CONSTRAINT chk_decision_type
        CHECK (decision_type IN ('APPROVED', 'REJECTED', 'NEEDS_REVISION')),
    CONSTRAINT chk_decision_reason
        CHECK (
            decision_type = 'APPROVED'
            OR NULLIF(BTRIM(comment), '') IS NOT NULL
        )
);

COMMENT ON TABLE decisions IS
    'История решений оператора; operator_id определяется по авторизованной сессии.';

CREATE INDEX IF NOT EXISTS idx_decisions_application_decided
    ON decisions(application_id, decided_at DESC);


-- =========================================================
-- 9. APPLICATION_STATUS_HISTORY: история бизнес-статусов
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
        FOREIGN KEY (application_id) REFERENCES applications(id) ON DELETE RESTRICT,
    CONSTRAINT chk_previous_status
        CHECK (
            previous_status IS NULL OR previous_status IN (
                'DRAFT', 'SUBMITTED', 'DATA_CHECK', 'NEEDS_REVISION',
                'UNDER_REVIEW', 'APPROVED', 'REJECTED'
            )
        ),
    CONSTRAINT chk_new_status
        CHECK (new_status IN (
            'DRAFT', 'SUBMITTED', 'DATA_CHECK', 'NEEDS_REVISION',
            'UNDER_REVIEW', 'APPROVED', 'REJECTED'
        )),
    CONSTRAINT chk_status_actor_type
        CHECK (changed_by_type IN ('APPLICANT', 'OPERATOR', 'SYSTEM'))
);

COMMENT ON TABLE application_status_history IS
    'История переходов бизнес-статусов. Заполняется приложением в той же транзакции, что и обновление applications.status.';

CREATE INDEX IF NOT EXISTS idx_status_history_application_changed
    ON application_status_history(application_id, changed_at DESC);


-- =========================================================
-- 10. INTEGRATION_DELIVERIES: отправка в Модули 2 и 3
-- =========================================================

CREATE TABLE IF NOT EXISTS integration_deliveries (
    id BIGSERIAL PRIMARY KEY,
    application_id UUID NOT NULL,
    target_module VARCHAR(20) NOT NULL,
    delivery_status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    attempt_count INTEGER NOT NULL DEFAULT 0,
    next_attempt_at TIMESTAMPTZ,
    last_http_status INTEGER,
    last_error TEXT,
    last_attempt_at TIMESTAMPTZ,
    sent_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_deliveries_application
        FOREIGN KEY (application_id) REFERENCES applications(id) ON DELETE RESTRICT,
    CONSTRAINT chk_delivery_target
        CHECK (target_module IN ('MODULE_2', 'MODULE_3')),
    CONSTRAINT chk_delivery_status
        CHECK (delivery_status IN ('PENDING', 'IN_PROGRESS', 'RETRY_SCHEDULED', 'SENT', 'FAILED')),
    CONSTRAINT chk_delivery_attempt_count
        CHECK (attempt_count >= 0),
    CONSTRAINT chk_delivery_http_status
        CHECK (last_http_status IS NULL OR last_http_status BETWEEN 100 AND 599),
    CONSTRAINT uq_application_target_module
        UNIQUE (application_id, target_module)
);

COMMENT ON TABLE integration_deliveries IS
    'Состояние передачи одобренного проекта в смежные модули. Ошибка доставки не изменяет решение по заявке.';
COMMENT ON COLUMN integration_deliveries.attempt_count IS
    'Количество выполненных попыток автоматической и/или согласованной ручной доставки.';

CREATE INDEX IF NOT EXISTS idx_deliveries_status_next_attempt
    ON integration_deliveries(delivery_status, next_attempt_at);


-- =========================================================
-- 11. IDEMPOTENCY_RECORDS: идемпотентность API
-- =========================================================

CREATE TABLE IF NOT EXISTS idempotency_records (
    id BIGSERIAL PRIMARY KEY,
    actor_id VARCHAR(100) NOT NULL,
    operation_scope VARCHAR(255) NOT NULL,
    idempotency_key VARCHAR(255) NOT NULL,
    request_hash VARCHAR(64) NOT NULL,
    processing_status VARCHAR(20) NOT NULL DEFAULT 'IN_PROGRESS',
    response_status_code INTEGER,
    response_body JSONB,
    resource_type VARCHAR(100),
    resource_id VARCHAR(100),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMPTZ NOT NULL,
    completed_at TIMESTAMPTZ,

    CONSTRAINT uq_idempotency_actor_scope_key
        UNIQUE (actor_id, operation_scope, idempotency_key),
    CONSTRAINT chk_idempotency_request_hash
        CHECK (request_hash ~ '^[A-Fa-f0-9]{64}$'),
    CONSTRAINT chk_idempotency_processing_status
        CHECK (processing_status IN ('IN_PROGRESS', 'COMPLETED', 'FAILED')),
    CONSTRAINT chk_idempotency_response_code
        CHECK (response_status_code IS NULL OR response_status_code BETWEEN 100 AND 599),
    CONSTRAINT chk_idempotency_expiry
        CHECK (expires_at > created_at),
    CONSTRAINT chk_idempotency_completion
        CHECK (
            processing_status <> 'COMPLETED'
            OR (response_status_code IS NOT NULL AND completed_at IS NOT NULL)
        )
);

COMMENT ON TABLE idempotency_records IS
    'Ключи идемпотентности для повторных HTTP-запросов. Доступ к сохранённым response_body ограничивается; истёкшие записи подлежат очистке по политике хранения.';

CREATE INDEX IF NOT EXISTS idx_idempotency_expires_at
    ON idempotency_records(expires_at);


-- =========================================================
-- 12. AUDIT_EVENTS: журнал значимых действий
-- =========================================================

CREATE TABLE IF NOT EXISTS audit_events (
    id BIGSERIAL PRIMARY KEY,
    application_id UUID,
    actor_type VARCHAR(20) NOT NULL,
    actor_id VARCHAR(100),
    action VARCHAR(100) NOT NULL,
    resource_type VARCHAR(100) NOT NULL,
    resource_id VARCHAR(100),
    details JSONB NOT NULL DEFAULT '{}'::jsonb,
    trace_id VARCHAR(100),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_audit_events_application
        FOREIGN KEY (application_id) REFERENCES applications(id) ON DELETE RESTRICT,
    CONSTRAINT chk_audit_actor_type
        CHECK (actor_type IN ('APPLICANT', 'OPERATOR', 'ADMIN', 'SYSTEM'))
);

COMMENT ON TABLE audit_events IS
    'Журнал значимых действий. В details запрещено сохранять пароли, токены и бинарное содержимое документов.';

CREATE INDEX IF NOT EXISTS idx_audit_events_application_created
    ON audit_events(application_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_events_trace_id
    ON audit_events(trace_id)
    WHERE trace_id IS NOT NULL;


-- =========================================================
-- 13. NOTIFICATION_OUTBOX: очередь уведомлений
-- =========================================================

CREATE TABLE IF NOT EXISTS notification_outbox (
    id BIGSERIAL PRIMARY KEY,
    application_id UUID NOT NULL,
    event_type VARCHAR(100) NOT NULL,
    channel VARCHAR(30) NOT NULL,
    recipient_reference VARCHAR(255) NOT NULL,
    payload JSONB NOT NULL,
    delivery_status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    attempt_count INTEGER NOT NULL DEFAULT 0,
    next_attempt_at TIMESTAMPTZ,
    last_attempt_at TIMESTAMPTZ,
    last_error TEXT,
    sent_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_notification_application
        FOREIGN KEY (application_id) REFERENCES applications(id) ON DELETE RESTRICT,
    CONSTRAINT chk_notification_delivery_status
        CHECK (delivery_status IN ('PENDING', 'IN_PROGRESS', 'RETRY_SCHEDULED', 'SENT', 'FAILED')),
    CONSTRAINT chk_notification_attempt_count
        CHECK (attempt_count >= 0)
);

COMMENT ON TABLE notification_outbox IS
    'Очередь уведомлений заявителю. Каналы и политика доставки определяются конфигурацией. recipient_reference должен быть ссылкой на получателя, а не открытым секретом.';

CREATE INDEX IF NOT EXISTS idx_notification_outbox_status_next_attempt
    ON notification_outbox(delivery_status, next_attempt_at);
CREATE INDEX IF NOT EXISTS idx_notification_outbox_application_created
    ON notification_outbox(application_id, created_at DESC);


-- =========================================================
-- 14. updated_at triggers
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
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_applications_updated_at ON applications;
CREATE TRIGGER trg_applications_updated_at
BEFORE UPDATE ON applications
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_application_contacts_updated_at ON application_contacts;
CREATE TRIGGER trg_application_contacts_updated_at
BEFORE UPDATE ON application_contacts
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_deliveries_updated_at ON integration_deliveries;
CREATE TRIGGER trg_deliveries_updated_at
BEFORE UPDATE ON integration_deliveries
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_notification_outbox_updated_at ON notification_outbox;
CREATE TRIGGER trg_notification_outbox_updated_at
BEFORE UPDATE ON notification_outbox
FOR EACH ROW EXECUTE FUNCTION set_updated_at();


-- =========================================================
-- 15. Дополнительные пояснения
-- =========================================================

COMMENT ON COLUMN applications.requested_amount IS
    'Сумма поддержки в рублях; от 0.01 до 500000000.00 включительно.';
COMMENT ON COLUMN scoring_results.recommendation IS
    'REJECT, MANUAL_REVIEW или APPROVE. Это рекомендация, не статус заявки.';
COMMENT ON COLUMN application_documents.checksum_sha256 IS
    'SHA-256 содержимого файла для проверки целостности.';
COMMENT ON COLUMN notification_outbox.recipient_reference IS
    'Идентификатор или ссылка на получателя в согласованном канале доставки.';
