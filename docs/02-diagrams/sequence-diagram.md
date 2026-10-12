# Sequence Diagram: Взаимодействие систем при обработке заявки

```mermaid
sequenceDiagram
    autonumber
    actor Applicant as Заявитель (Завод)
    participant Web as Frontend (Портал)
    participant GW as API Gateway
    participant Orch as Backend Orchestrator
    participant DB as PostgreSQL DB
    participant FNS as ЕГРЮЛ / ФНС API
    participant AI as Модуль AI-скоринга
    actor Operator as Оператор Минпромторга

    %% Сценарий 1. Автозаполнение формы по ИНН
    rect rgb(240, 248, 255)
    note over Applicant, FNS: Сценарий 1. Автозаполнение формы по ИНН
    Applicant->>Web: Ввод ИНН (напр., 7701234567)
    Web->>GW: GET /api/v1/companies/suggest?inn=7701234567
    GW->>FNS: GET /egrul/v1/company?inn=7701234567
    FNS-->>GW: 200 OK (Наименование, Адрес, Выручка, ОКВЭД)
    GW-->>Web: 200 OK (JSON с данными компании)
    Web-->>Applicant: Автозаполнение 70% полей формы
    end

    %% Сценарий 2. Подача заявки и фоновая проверка
    rect rgb(255, 250, 240)
    note over Applicant, DB: Сценарий 2. Подача заявки и фоновая проверка
    Applicant->>Web: Заполнение суммы, прикрепление проекта и отправка
    Web->>GW: POST /api/v1/applications (Payload)
    GW->>Orch: ProcessApplication(ApplicationDTO)
    Orch->>DB: INSERT INTO applications (status = 'SUBMITTED')
    Orch-->>GW: application_id = "app-8923"
    GW-->>Web: 201 Created
    Web-->>Applicant: Экран «Заявка принята в обработку»

    par Фоновые интеграционные запросы
        Orch->>FNS: GET /fns/v1/tax-debts?inn=...
        FNS-->>Orch: 200 OK (Debt: 0 RUR, Status: Active)
    and Скоринг
        Orch->>AI: POST /api/v1/scoring/evaluate (FinMetrics)
        AI-->>Orch: 200 OK (Score: 92, Risk: Low, Rec: Approve)
    end

    alt Выявление стоп-факторов или Score менее 60
        Orch->>DB: UPDATE status = 'REJECTED_AUTO'
    else Score 60–79
        Orch->>DB: UPDATE status = 'UNDER_MANUAL_REVIEW'
    else Score 80–100 (Успешный путь)
        Orch->>DB: UPDATE status = 'RECOMMENDED_APPROVE'
    end
    end

    %% Сценарий 3. Просмотр дашборда и принятие решения
    rect rgb(240, 255, 240)
    note over Operator, Applicant: Сценарий 3. Просмотр дашборда и принятие решения
    Operator->>Web: Открытие дашборда рекомендованных заявок
    Web->>GW: GET /api/v1/applications?status=RECOMMENDED_APPROVE
    GW->>DB: SELECT * FROM applications WHERE status = 'RECOMMENDED_APPROVE'
    DB-->>GW: Result Set
    GW-->>Web: 200 OK (Список заявок)
    Web-->>Operator: Отображение карточки (Завод X, 50 млн руб., Score 92/100)

    Operator->>Web: Нажатие кнопки «Подтвердить решение»
    Web->>GW: POST /api/v1/applications/app-8923/decision (Type: APPROVE)
    GW->>Orch: ApplyDecision(app-8923, APPROVE)
    Orch->>DB: UPDATE status = 'APPROVED', create decision_record
    Orch-->>Applicant: Уведомление в ЛК («Заявка одобрена»)
    end
```