# ER-диаграмма базы данных

## 1. Назначение

ER-диаграмма описывает основные сущности PostgreSQL для Модуля 1 системы «ГИС Господдержка», их атрибуты и связи.

Модель поддерживает хранение сведений о предприятиях и заявках, результатов проверок, скоринга, решений оператора, истории статусов и результатов интеграционного взаимодействия со смежными модулями.

## 2. Диаграмма сущностей

```mermaid
erDiagram
    COMPANIES ||--o{ APPLICATIONS : "подает"
    APPLICATIONS ||--o{ APPLICATION_CHECKS : "проходит проверки"
    APPLICATIONS ||--o{ SCORING_RESULTS : "имеет результаты скоринга"
    APPLICATIONS ||--o{ DECISIONS : "имеет историю решений"
    APPLICATIONS ||--o{ APPLICATION_STATUS_HISTORY : "имеет историю статусов"
    APPLICATIONS ||--o{ INTEGRATION_DELIVERIES : "передает данные"

    COMPANIES {
        bigserial id PK
        varchar inn UK
        varchar kpp
        varchar ogrn
        varchar name
        text legal_address
        varchar okved
        numeric revenue_last_year
        timestamptz created_at
        timestamptz updated_at
    }

    APPLICATIONS {
        uuid id PK
        varchar application_number UK
        bigint company_id FK
        varchar subsidy_type
        numeric requested_amount
        varchar project_title
        text project_description
        varchar status
        timestamptz created_at
        timestamptz updated_at
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
        jsonb risk_assessment
        varchar recommendation
        varchar model_version
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
        text last_error
        timestamptz last_attempt_at
        timestamptz sent_at
        timestamptz created_at
        timestamptz updated_at
    }
```

## 3. Описание сущностей

| Сущность | Назначение |
|---|---|
| `COMPANIES` | Профили предприятий и сведения, используемые при заполнении заявки |
| `APPLICATIONS` | Заявки на государственную поддержку, их суммы, описание и текущий статус |
| `APPLICATION_CHECKS` | Результаты отдельных проверок, источники данных, ошибки и повторные попытки |
| `SCORING_RESULTS` | История расчётов скоринга и рекомендаций |
| `DECISIONS` | История решений оператора и основания решений |
| `APPLICATION_STATUS_HISTORY` | История переходов заявки между статусами |
| `INTEGRATION_DELIVERIES` | Состояние передачи данных в Модули 2 и 3, количество попыток и ошибки |

## 4. Основные связи и ограничения

- Одно предприятие может иметь несколько заявок.
- Для одной заявки может выполняться несколько проверок, в том числе повторных.
- Для одной заявки может сохраняться несколько результатов скоринга.
- Для одной заявки могут фиксироваться несколько решений и переходов статуса.
- Для одной заявки могут создаваться записи доставки данных в разные смежные модули.
- ИНН предприятия и номер заявки должны быть уникальны.
- Результаты проверок, скоринга и решений сохраняются с привязкой к конкретной заявке.

## 5. Примечания к модели

1. Текущий статус хранится в `APPLICATIONS.status`; история переходов хранится отдельно.
2. Ошибки внешних сервисов сохраняются в `APPLICATION_CHECKS`, а не интерпретируются как отрицательный результат проверки.
3. Результат скоринга хранится отдельно от окончательного решения оператора.
4. Повторная отправка данных в смежный модуль обновляет состояние интеграционной доставки, а не создаёт повторную бизнес-операцию.
5. Структура не задаёт автоматически сроки хранения записей: они должны быть согласованы отдельно.