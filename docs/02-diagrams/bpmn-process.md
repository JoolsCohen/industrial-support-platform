<?xml version="1.0" encoding="UTF-8"?>
<bpmn:definitions xmlns:bpmn="http://www.omg.org/spec/BPMN/20100524/MODEL" 
                  xmlns:bpmndi="http://www.omg.org/spec/BPMN/20100524/DI" 
                  xmlns:dc="http://www.omg.org/spec/DD/20100524/DC" 
                  xmlns:di="http://www.omg.org/spec/DD/20100524/DI" 
                  id="Definitions_1" 
                  targetNamespace="http://bpmn.io/schema/bpmn" 
                  exporter="Camunda Modeler" 
                  exporterVersion="5.0.0">
  <bpmn:collaboration id="Collaboration_1">
    <bpmn:participant id="Participant_GIS" name="ГИС «Господдержка» — Распределение субсидий" processRef="Process_Subsidy" />
  </bpmn:collaboration>

  <bpmn:process id="Process_Subsidy" isExecutable="false">
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
      </bpmn:lane>
      <bpmn:lane id="Lane_Orchestrator" name="Оркестратор и Интеграции">
        <bpmn:flowNodeRef>Task_SaveApp</bpmn:flowNodeRef>
        <bpmn:flowNodeRef>Task_AIScoring</bpmn:flowNodeRef>
        <bpmn:flowNodeRef>EndEvent_AutoReject</bpmn:flowNodeRef>
      </bpmn:lane>
      <bpmn:lane id="Lane_Operator" name="Оператор Минпромторга">
        <bpmn:flowNodeRef>Task_ReviewDash</bpmn:flowNodeRef>
        <bpmn:flowNodeRef>EndEvent_Approved</bpmn:flowNodeRef>
      </bpmn:lane>
    </bpmn:laneSet>

    <bpmn:startEvent id="StartEvent_1" name="Старт">
      <bpmn:outgoing>Flow_1</bpmn:outgoing>
    </bpmn:startEvent>
    <bpmn:task id="Task_EnterINN" name="Ввод ИНН">
      <bpmn:incoming>Flow_1</bpmn:incoming>
      <bpmn:outgoing>Flow_2</bpmn:outgoing>
    </bpmn:task>
    <bpmn:task id="Task_FetchEGRUL" name="Запрос ЕГРЮЛ (API ФНС)">
      <bpmn:incoming>Flow_2</bpmn:incoming>
      <bpmn:outgoing>Flow_3</bpmn:outgoing>
    </bpmn:task>
    <bpmn:task id="Task_FillForm" name="Заполнение параметров">
      <bpmn:incoming>Flow_3</bpmn:incoming>
      <bpmn:outgoing>Flow_4</bpmn:outgoing>
    </bpmn:task>
    <bpmn:task id="Task_SubmitApp" name="Отправка заявки">
      <bpmn:incoming>Flow_4</bpmn:incoming>
      <bpmn:outgoing>Flow_5</bpmn:outgoing>
    </bpmn:task>
    <bpmn:task id="Task_ValidateForm" name="Валидация полей">
      <bpmn:incoming>Flow_5</bpmn:incoming>
      <bpmn:outgoing>Flow_6</bpmn:outgoing>
    </bpmn:task>
    <bpmn:task id="Task_SaveApp" name="Сохранение в БД (SUBMITTED)">
      <bpmn:incoming>Flow_6</bpmn:incoming>
      <bpmn:outgoing>Flow_7</bpmn:outgoing>
    </bpmn:task>
    <bpmn:task id="Task_AIScoring" name="Проверки и AI-скоринг">
      <bpmn:incoming>Flow_7</bpmn:incoming>
      <bpmn:outgoing>Flow_8</bpmn:outgoing>
      <bpmn:outgoing>Flow_Reject</bpmn:outgoing>
    </bpmn:task>
    <bpmn:endEvent id="EndEvent_AutoReject" name="Автоматический отказ">
      <bpmn:incoming>Flow_Reject</bpmn:incoming>
    </bpmn:endEvent>
    <bpmn:task id="Task_ReviewDash" name="Дашборд оператора (Утверждение)">
      <bpmn:incoming>Flow_8</bpmn:incoming>
      <bpmn:outgoing>Flow_9</bpmn:outgoing>
    </bpmn:task>
    <bpmn:endEvent id="EndEvent_Approved" name="Заявка одобрена">
      <bpmn:incoming>Flow_9</bpmn:incoming>
    </bpmn:endEvent>

    <bpmn:sequenceFlow id="Flow_1" sourceRef="StartEvent_1" targetRef="Task_EnterINN" />
    <bpmn:sequenceFlow id="Flow_2" sourceRef="Task_EnterINN" targetRef="Task_FetchEGRUL" />
    <bpmn:sequenceFlow id="Flow_3" sourceRef="Task_FetchEGRUL" targetRef="Task_FillForm" />
    <bpmn:sequenceFlow id="Flow_4" sourceRef="Task_FillForm" targetRef="Task_SubmitApp" />
    <bpmn:sequenceFlow id="Flow_5" sourceRef="Task_SubmitApp" targetRef="Task_ValidateForm" />
    <bpmn:sequenceFlow id="Flow_6" sourceRef="Task_ValidateForm" targetRef="Task_SaveApp" />
    <bpmn:sequenceFlow id="Flow_7" sourceRef="Task_SaveApp" targetRef="Task_AIScoring" />
    <bpmn:sequenceFlow id="Flow_8" sourceRef="Task_AIScoring" targetRef="Task_ReviewDash" />
    <bpmn:sequenceFlow id="Flow_Reject" sourceRef="Task_AIScoring" targetRef="EndEvent_AutoReject" />
    <bpmn:sequenceFlow id="Flow_9" sourceRef="Task_ReviewDash" targetRef="EndEvent_Approved" />
  </bpmn:process>

  <bpmndi:BPMNDiagram id="BPMNDiagram_1">
    <bpmndi:BPMNPlane id="BPMNPlane_1" bpmnElement="Collaboration_1">
      <bpmndi:BPMNShape id="Participant_GIS_di" bpmnElement="Participant_GIS" isHorizontal="true">
        <dc:Bounds x="160" y="80" width="1100" h="480" />
      </bpmndi:BPMNShape>
      <bpmndi:BPMNShape id="Lane_Applicant_di" bpmnElement="Lane_Applicant" isHorizontal="true">
        <dc:Bounds x="190" y="80" width="1070" h="120" />
      </bpmndi:BPMNShape>
      <bpmndi:BPMNShape id="Lane_Gateway_di" bpmnElement="Lane_Gateway" isHorizontal="true">
        <dc:Bounds x="190" y="200" width="1070" h="120" />
      </bpmndi:BPMNShape>
      <bpmndi:BPMNShape id="Lane_Orchestrator_di" bpmnElement="Lane_Orchestrator" isHorizontal="true">
        <dc:Bounds x="190" y="320" width="1070" h="120" />
      </bpmndi:BPMNShape>
      <bpmndi:BPMNShape id="Lane_Operator_di" bpmnElement="Lane_Operator" isHorizontal="true">
        <dc:Bounds x="190" y="440" width="1070" h="120" />
      </bpmndi:BPMNShape>

      <bpmndi:BPMNShape id="StartEvent_1_di" bpmnElement="StartEvent_1">
        <dc:Bounds x="232" y="122" width="36" height="36" />
      </bpmndi:BPMNShape>
      <bpmndi:BPMNShape id="Task_EnterINN_di" bpmnElement="Task_EnterINN">
        <dc:Bounds x="300" y="100" width="100" height="80" />
      </bpmndi:BPMNShape>
      <bpmndi:BPMNShape id="Task_FetchEGRUL_di" bpmnElement="Task_FetchEGRUL">
        <dc:Bounds x="300" y="220" width="100" height="80" />
      </bpmndi:BPMNShape>
      <bpmndi:BPMNShape id="Task_FillForm_di" bpmnElement="Task_FillForm">
        <dc:Bounds x="440" y="100" width="100" height="80" />
      </bpmndi:BPMNShape>
      <bpmndi:BPMNShape id="Task_SubmitApp_di" bpmnElement="Task_SubmitApp">
        <dc:Bounds x="580" y="100" width="100" height="80" />
      </bpmndi:BPMNShape>
      <bpmndi:BPMNShape id="Task_ValidateForm_di" bpmnElement="Task_ValidateForm">
        <dc:Bounds x="580" y="220" width="100" height="80" />
      </bpmndi:BPMNShape>
      <bpmndi:BPMNShape id="Task_SaveApp_di" bpmnElement="Task_SaveApp">
        <dc:Bounds x="580" y="340" width="100" height="80" />
      </bpmndi:BPMNShape>
      <bpmndi:BPMNShape id="Task_AIScoring_di" bpmnElement="Task_AIScoring">
        <dc:Bounds x="730" y="340" width="100" height="80" />
      </bpmndi:BPMNShape>
      <bpmndi:BPMNShape id="EndEvent_AutoReject_di" bpmnElement="EndEvent_AutoReject">
        <dc:Bounds x="872" y="362" width="36" height="36" />
      </bpmndi:BPMNShape>
      <bpmndi:BPMNShape id="Task_ReviewDash_di" bpmnElement="Task_ReviewDash">
        <dc:Bounds x="880" y="460" width="100" height="80" />
      </bpmndi:BPMNShape>
      <bpmndi:BPMNShape id="EndEvent_Approved_di" bpmnElement="EndEvent_Approved">
        <dc:Bounds x="1032" y="482" width="36" height="36" />
      </bpmndi:BPMNShape>

      <bpmndi:BPMNEdge id="Flow_1_di" bpmnElement="Flow_1">
        <di:waypoint x="268" y="140" />
        <di:waypoint x="300" y="140" />
      </bpmndi:BPMNEdge>
      <bpmndi:BPMNEdge id="Flow_2_di" bpmnElement="Flow_2">
        <di:waypoint x="350" y="180" />
        <di:waypoint x="350" y="220" />
      </bpmndi:BPMNEdge>
      <bpmndi:BPMNEdge id="Flow_3_di" bpmnElement="Flow_3">
        <di:waypoint x="400" y="260" />
        <di:waypoint x="420" y="260" />
        <di:waypoint x="420" y="140" />
        <di:waypoint x="440" y="140" />
      </bpmndi:BPMNEdge>
      <bpmndi:BPMNEdge id="Flow_4_di" bpmnElement="Flow_4">
        <di:waypoint x="540" y="140" />
        <di:waypoint x="580" y="140" />
      </bpmndi:BPMNEdge>
      <bpmndi:BPMNEdge id="Flow_5_di" bpmnElement="Flow_5">
        <di:waypoint x="630" y="180" />
        <di:waypoint x="630" y="220" />
      </bpmndi:BPMNEdge>
      <bpmndi:BPMNEdge id="Flow_6_di" bpmnElement="Flow_6">
        <di:waypoint x="630" y="300" />
        <di:waypoint x="630" y="340" />
      </bpmndi:BPMNEdge>
      <bpmndi:BPMNEdge id="Flow_7_di" bpmnElement="Flow_7">
        <di:waypoint x="680" y="380" />
        <di:waypoint x="730" y="380" />
      </bpmndi:BPMNEdge>
      <bpmndi:BPMNEdge id="Flow_8_di" bpmnElement="Flow_8">
        <di:waypoint x="830" y="380" />
        <di:waypoint x="855" y="380" />
        <di:waypoint x="855" y="500" />
        <di:waypoint x="880" y="500" />
      </bpmndi:BPMNEdge>
      <bpmndi:BPMNEdge id="Flow_Reject_di" bpmnElement="Flow_Reject">
        <di:waypoint x="830" y="380" />
        <di:waypoint x="872" y="380" />
      </bpmndi:BPMNEdge>
      <bpmndi:BPMNEdge id="Flow_9_di" bpmnElement="Flow_9">
        <di:waypoint x="980" y="500" />
        <di:waypoint x="1032" y="500" />
      </bpmndi:BPMNEdge>
    </bpmndi:BPMNPlane>
  </bpmndi:BPMNDiagram>
</bpmn:definitions>