# ER-диаграмма базы данных

## 1. Назначение

ER-диаграмма описывает структуру хранения данных Модуля 1 системы «ГИС Господдержка». Модель согласована с `system-requirements.md` и учебным контрактом `docs/03-api/openapi.yaml`.

Диаграмма покрывает профиль предприятия, финансовые снимки из внешнего источника, заявки и контактные данные, документы, историю проверок и скоринга, решения, историю статусов, интеграционные доставки, ключи идемпотентности, аудит и очередь уведомлений.

## 2. ER-диаграмма

```mermaid
erDiagram
    COMPANIES ||--o{ APPLICATIONS : "подает"
    COMPANIES ||--o{ COMPANY_FINANCIAL_SNAPSHOTS : "имеет финансовые снимки"
    APPLICATIONS ||--o| APPLICATION_CONTACTS : "содержит контакт"
    APPLICATIONS ||--o{ APPLICATION_DOCUMENTS : "содержит документы"
    APPLICATIONS ||--o{ APPLICATION_CHECKS : "проходит проверки"
    APPLICATIONS ||--o{ SCORING_RESULTS : "имеет результаты скоринга"
    APPLICATIONS ||--o{ DECISIONS : "имеет историю решений"
    APPLICATIONS ||--o{ APPLICATION_STATUS_HISTORY : "имеет историю статусов"
    APPLICATIONS ||--o{ INTEGRATION_DELIVERIES : "передает данные"
    APPLICATIONS ||--o{ AUDIT_EVENTS : "имеет события аудита"
    APPLICATIONS ||--o{ NOTIFICATION_OUTBOX : "порождает уведомления"

    COMPANIES {
        bigserial id PK
        varchar inn UK
        varchar kpp
        varchar ogrn
        varchar full_name
        varchar short_name
        varchar legal_status
        date registration_date
        text legal_address
        varchar okved_main_code
        text okved_main_name
        timestamptz last_registry_sync_at
        timestamptz created_at
        timestamptz updated_at
    }

    COMPANY_FINANCIAL_SNAPSHOTS {
        bigserial id PK
        bigint company_id FK
        smallint reporting_year
        numeric revenue
        numeric net_profit
        numeric tax_debt_amount
        boolean has_tax_debt
        boolean is_in_bankruptcy_process
        varchar source_provider
        timestamptz fetched_at
    }

    APPLICATIONS {
        uuid id PK
        varchar application_number UK
        bigint company_id FK
        varchar subsidy_type
        numeric requested_amount
        varchar project_title
        text project_description
        integer implementation_period_months
        integer planned_jobs_created
        varchar status
        text rejection_reason
        timestamptz created_at
        timestamptz updated_at
    }

    APPLICATION_CONTACTS {
        uuid application_id PK, FK
        varchar full_name
        varchar email
        varchar phone
        timestamptz created_at
        timestamptz updated_at
    }

    APPLICATION_DOCUMENTS {
        bigserial id PK
        uuid application_id FK
        varchar document_type
        varchar file_name
        varchar storage_key UK
        varchar mime_type
        bigint size_bytes
        varchar checksum_sha256
        text description
        varchar uploaded_by
        timestamptz uploaded_at
        varchar validation_status
        text validation_error
        timestamptz deleted_at
        varchar deleted_by
    }

    APPLICATION_CHECKS {
        bigserial id PK
        uuid application_id FK
        varchar check_code
        varchar provider
        varchar check_status
        jsonb result_data
        varchar error_code
        text error_message
        integer attempt_number
        timestamptz checked_at
        timestamptz created_at
    }

    SCORING_RESULTS {
        bigserial id PK
        uuid application_id FK
        integer score_value
        varchar recommendation
        varchar model_version
        jsonb risk_assessment
        timestamptz calculated_at
    }

    DECISIONS {
        bigserial id PK
        uuid application_id FK
        varchar operator_id
        varchar decision_type
        text comment
        timestamptz decided_at
    }

    APPLICATION_STATUS_HISTORY {
        bigserial id PK
        uuid application_id FK
        varchar previous_status
        varchar new_status
        varchar changed_by_type
        varchar changed_by_id
        text reason
        timestamptz changed_at
    }

    INTEGRATION_DELIVERIES {
        bigserial id PK
        uuid application_id FK
        varchar target_module
        varchar delivery_status
        integer attempt_count
        timestamptz next_attempt_at
        integer last_http_status
        text last_error
        timestamptz last_attempt_at
        timestamptz sent_at
        timestamptz created_at
        timestamptz updated_at
    }

    IDEMPOTENCY_RECORDS {
        bigserial id PK
        varchar actor_id
        varchar operation_scope
        varchar idempotency_key
        varchar request_hash
        varchar processing_status
        integer response_status_code
        jsonb response_body
        varchar resource_type
        varchar resource_id
        timestamptz created_at
        timestamptz expires_at
        timestamptz completed_at
    }

    AUDIT_EVENTS {
        bigserial id PK
        uuid application_id FK
        varchar actor_type
        varchar actor_id
        varchar action
        varchar resource_type
        varchar resource_id
        jsonb details
        varchar trace_id
        timestamptz created_at
    }

    NOTIFICATION_OUTBOX {
        bigserial id PK
        uuid application_id FK
        varchar event_type
        varchar channel
        varchar recipient_reference
        jsonb payload
        varchar delivery_status
        integer attempt_count
        timestamptz next_attempt_at
        timestamptz last_attempt_at
        text last_error
        timestamptz sent_at
        timestamptz created_at
        timestamptz updated_at
    }
```

## 3. Сущности и назначение

| Сущность | Назначение |
|---|---|
| `COMPANIES` | Профиль юридического лица, основные сведения из реестра и дата последнего обновления |
| `COMPANY_FINANCIAL_SNAPSHOTS` | Снимки финансовых показателей, полученных из внешнего источника; текущие проверки по заявке дополнительно фиксируются в `APPLICATION_CHECKS` |
| `APPLICATIONS` | Черновик или заявка, сумма, данные проекта и текущий бизнес-статус |
| `APPLICATION_CONTACTS` | Контактные данные заявителя для конкретной заявки; запись может отсутствовать у незаполненного черновика |
| `APPLICATION_DOCUMENTS` | Метаданные файлов, ссылка на защищённое хранилище, результат проверки файла и признаки логического удаления |
| `APPLICATION_CHECKS` | Результаты проверок, источник, ошибки и номер попытки |
| `SCORING_RESULTS` | История оценок, рекомендаций и аналитических атрибутов скоринга |
| `DECISIONS` | История решений оператора, включая возврат на доработку |
| `APPLICATION_STATUS_HISTORY` | История смены бизнес-статусов и субъектов, которые инициировали переход |
| `INTEGRATION_DELIVERIES` | Состояние передачи данных в Модуль 2 и Модуль 3, ошибки и повторные попытки |
| `IDEMPOTENCY_RECORDS` | Защита операций от дублирования при повторных HTTP-запросах с тем же ключом |
| `AUDIT_EVENTS` | Журнал значимых действий, которые не исчерпываются сменой статуса или решением |
| `NOTIFICATION_OUTBOX` | Очередь уведомлений заявителю и история попыток доставки |

## 4. Основные правила модели

1. Одно предприятие может иметь несколько заявок; ИНН предприятия и номер заявки уникальны.
2. Черновик может быть неполным. Для статусов, отличных от `DRAFT`, должны быть заполнены обязательные поля заявки.
3. У заявки может быть ноль или одна текущая запись контактных данных. История бизнес-изменений фиксируется аудиторскими событиями; версионирование самих контактных данных отдельно не предусмотрено.
4. У заявки может быть несколько документов, проверок, скоринговых результатов, решений и событий смены статуса.
5. `APPLICATIONS.status` хранит только бизнес-статус: `DRAFT`, `SUBMITTED`, `DATA_CHECK`, `NEEDS_REVISION`, `UNDER_REVIEW`, `APPROVED`, `REJECTED`.
6. Рекомендация скоринга (`APPROVE`, `MANUAL_REVIEW`, `REJECT`) не является статусом заявки.
7. Техническая ошибка внешнего сервиса хранится как `APPLICATION_CHECKS.check_status = ERROR`, а не как стоп-фактор.
8. Передача данных и уведомления имеют собственный статус доставки и не изменяют уже принятое решение по заявке.
9. Файлы размещаются во внешнем защищённом хранилище. В PostgreSQL сохраняется `storage_key`, контрольная сумма и метаданные, но не бинарное содержимое.
10. Удаление документа через API реализуется логически: запись помечается `deleted_at` и `deleted_by`; обычные запросы списка исключают помеченные документы.
11. Ключи идемпотентности ограничены областью операции и субъектом; срок хранения определяется настройками очистки.
12. `AUDIT_EVENTS.details` не должен содержать пароли, токены, бинарное содержимое файлов или избыточные персональные данные.

## 5. Примечания по реализации

- История статусов, решение и связанное событие аудита должны записываться согласованно в одной транзакции.
- Значения `APPLICATIONS.rejection_reason` должны обновляться вместе с решением `REJECTED`; источником полной истории оснований остаётся `DECISIONS`.
- На уровне приложения/сервиса валидируется контрольное число ИНН и принадлежность ОКВЭД к допустимому перечню учебной программы. Простая проверка длины ИНН в SQL не заменяет контрольное число.
- Ограничения по допустимому типу и максимальному размеру файла должны быть конфигурируемыми после утверждения политики. Значение лимита пока не фиксируется в модели БД.
- `CREATE TABLE IF NOT EXISTS` не обновляет уже существующие таблицы. Для существующей БД нужно подготовить и применить миграцию; данный DDL предназначен для создания схемы с нуля.
