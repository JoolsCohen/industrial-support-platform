<?xml version="1.0" encoding="UTF-8"?>
<bpmn:definitions xmlns:bpmn="http://www.omg.org/spec/BPMN/20100524/MODEL" 
                  xmlns:bpmndi="http://www.omg.org/spec/BPMN/20100524/DI" 
                  xmlns:dc="http://www.omg.org/spec/DD/20100524/DC" 
                  xmlns:di="http://www.omg.org/spec/DD/20100524/DI" 
                  xmlns:camunda="http://camunda.org/schema/1.0/bpmn" 
                  id="Definitions_1" 
                  targetNamespace="http://bpmn.io/schema/bpmn">
  <bpmn:collaboration id="Collaboration_1">
    <bpmn:participant id="Participant_GIS" name="ГИС «Господдержка» — Процесс распределения субсидий" processRef="Process_SubsidyDistribution" />
  </bpmn:collaboration>
  
  <bpmn:process id="Process_SubsidyDistribution" name="Распределение господдержки" isExecutable="true">
    <bpmn:laneSet id="LaneSet_1">
      <bpmn:lane id="Lane_Applicant" name="Заявитель (Предприятие)">
        <bpmn:flowNodeRef>StartEvent_1</bpmn:flowNodeRef>
        <bpmn:flowNodeRef>Task_EnterINN</bpmn:flowNodeRef>
        <bpmn:flowNodeRef>Task_FillForm</bpmn:flowNodeRef>
        <bpmn:flowNodeRef>Task_SubmitApp</bpmn:flowNodeRef>
      </bpmn:lane>
      <bpmn:lane id="Lane_Gateway" name="Портал / API Gateway">
        <bpmn:flowNodeRef>Task_FetchEGRUL</bpmn:flowNodeRef>
        <bpmn:flowNodeRef>Task_ValidateForm</bpmn:flowNodeRef>
        <bpmn:flowNodeRef>Gateway_FormValid</bpmn:flowNodeRef>
      </bpmn:lane>
      <bpmn:lane id="Lane_Orchestrator" name="Оркестратор и Интеграции">
        <bpmn:flowNodeRef>Task_SaveApp</bpmn:flowNodeRef>
        <bpmn:flowNodeRef>Gateway_SplitChecks</bpmn:flowNodeRef>
        <bpmn:flowNodeRef>Task_CheckFNS</bpmn:flowNodeRef>
        <bpmn:flowNodeRef>Task_AIScoring</bpmn:flowNodeRef>
        <bpmn:flowNodeRef>Gateway_JoinChecks</bpmn:flowNodeRef>
        <bpmn:flowNodeRef>Gateway_StopFactors</bpmn:flowNodeRef>
        <bpmn:flowNodeRef>Gateway_ScoreRouting</bpmn:flowNodeRef>
        <bpmn:flowNodeRef>Task_SetAutoReject</bpmn:flowNodeRef>
        <bpmn:flowNodeRef>EndEvent_AutoRejected</bpmn:flowNodeRef>
      </bpmn:lane>
      <bpmn:lane id="Lane_Operator" name="Оператор Минпромторга">
        <bpmn:flowNodeRef>Task_ReviewDashboard</bpmn:flowNodeRef>
        <bpmn:flowNodeRef>Gateway_OperatorDecision</bpmn:flowNodeRef>
        <bpmn:flowNodeRef>Task_ApproveApp</bpmn:flowNodeRef>
        <bpmn:flowNodeRef>Task_RejectApp</bpmn:flowNodeRef>
        <bpmn:flowNodeRef>EndEvent_Approved</bpmn:flowNodeRef>
        <bpmn:flowNodeRef>EndEvent_ManualRejected</bpmn:flowNodeRef>
      </bpmn:lane>
    </bpmn:laneSet>

    <!-- Node Elements -->
    <bpmn:startEvent id="StartEvent_1" name="Потребность в поддержке">
      <bpmn:outgoing>Flow_1</bpmn:outgoing>
    </bpmn:startEvent>
    
    <bpmn:userTask id="Task_EnterINN" name="Ввод ИНН организации">
      <bpmn:incoming>Flow_1</bpmn:incoming>
      <bpmn:outgoing>Flow_2</bpmn:outgoing>
    </bpmn:userTask>
    
    <bpmn:serviceTask id="Task_FetchEGRUL" name="Запрос данных ЕГРЮЛ по ИНН">
      <bpmn:incoming>Flow_2</bpmn:incoming>
      <bpmn:outgoing>Flow_3</bpmn:outgoing>
    </bpmn:serviceTask>
    
    <bpmn:userTask id="Task_FillForm" name="Заполнение параметров заявки">
      <bpmn:incoming>Flow_3</bpmn:incoming>
      <bpmn:incoming>Flow_ValidNo</bpmn:incoming>
      <bpmn:outgoing>Flow_4</bpmn:outgoing>
    </bpmn:userTask>
    
    <bpmn:userTask id="Task_SubmitApp" name="Отправка заявки">
      <bpmn:incoming>Flow_4</bpmn:incoming>
      <bpmn:outgoing>Flow_5</bpmn:outgoing>
    </bpmn:userTask>
    
    <bpmn:businessRuleTask id="Task_ValidateForm" name="Валидация полей (BR-VAL)">
      <bpmn:incoming>Flow_5</bpmn:incoming>
      <bpmn:outgoing>Flow_6</bpmn:outgoing>
    </bpmn:businessRuleTask>
    
    <bpmn:exclusiveGateway id="Gateway_FormValid" name="Форма валидна?">
      <bpmn:incoming>Flow_6</bpmn:incoming>
      <bpmn:outgoing>Flow_ValidYes</bpmn:outgoing>
      <bpmn:outgoing>Flow_ValidNo</bpmn:outgoing>
    </bpmn:exclusiveGateway>
    
    <bpmn:serviceTask id="Task_SaveApp" name="Сохранение заявки (SUBMITTED)">
      <bpmn:incoming>Flow_ValidYes</bpmn:incoming>
      <bpmn:outgoing>Flow_7</bpmn:outgoing>
    </bpmn:serviceTask>
    
    <bpmn:parallelGateway id="Gateway_SplitChecks">
      <bpmn:incoming>Flow_7</bpmn:incoming>
      <bpmn:outgoing>Flow_ToFNS</bpmn:outgoing>
      <bpmn:outgoing>Flow_ToAI</bpmn:outgoing>
    </bpmn:parallelGateway>
    
    <bpmn:serviceTask id="Task_CheckFNS" name="Проверка долгов (API ФНС)">
      <bpmn:incoming>Flow_ToFNS</bpmn:incoming>
      <bpmn:outgoing>Flow_FromFNS</bpmn:outgoing>
    </bpmn:serviceTask>
    
    <bpmn:serviceTask id="Task_AIScoring" name="Расчет AI-скоринга">
      <bpmn:incoming>Flow_ToAI</bpmn:incoming>
      <bpmn:outgoing>Flow_FromAI</bpmn:outgoing>
    </bpmn:serviceTask>
    
    <bpmn:parallelGateway id="Gateway_JoinChecks">
      <bpmn:incoming>Flow_FromFNS</bpmn:incoming>
      <bpmn:incoming>Flow_FromAI</bpmn:incoming>
      <bpmn:outgoing>Flow_8</bpmn:outgoing>
    </bpmn:parallelGateway>
    
    <bpmn:exclusiveGateway id="Gateway_StopFactors" name="Есть стоп-факторы?">
      <bpmn:incoming>Flow_8</bpmn:incoming>
      <bpmn:outgoing>Flow_StopYes</bpmn:outgoing>
      <bpmn:outgoing>Flow_StopNo</bpmn:outgoing>
    </bpmn:exclusiveGateway>
    
    <bpmn:serviceTask id="Task_SetAutoReject" name="Установка статуса REJECTED_AUTO">
      <bpmn:incoming>Flow_StopYes</bpmn:incoming>
      <bpmn:incoming>Flow_ScoreLow</bpmn:incoming>
      <bpmn:outgoing>Flow_ToAutoEnd</bpmn:outgoing>
    </bpmn:serviceTask>
    
    <bpmn:endEvent id="EndEvent_AutoRejected" name="Автоматический отказ">
      <bpmn:incoming>Flow_ToAutoEnd</bpmn:incoming>
    </bpmn:endEvent>
    
    <bpmn:exclusiveGateway id="Gateway_ScoreRouting" name="Оценка Score">
      <bpmn:incoming>Flow_StopNo</bpmn:incoming>
      <bpmn:outgoing>Flow_ScoreLow</bpmn:outgoing>
      <bpmn:outgoing>Flow_ScoreMidHigh</bpmn:outgoing>
    </bpmn:exclusiveGateway>
    
    <bpmn:userTask id="Task_ReviewDashboard" name="Просмотр дашборда оператором">
      <bpmn:incoming>Flow_ScoreMidHigh</bpmn:incoming>
      <bpmn:outgoing>Flow_9</bpmn:outgoing>
    </bpmn:userTask>
    
    <bpmn:exclusiveGateway id="Gateway_OperatorDecision" name="Решение оператора">
      <bpmn: