# RisuAIOnlineModule (온라인 통합 모듈)

RisuAIOnlineModule은 RisuAI 내에서 다양한 온라인 인터랙션 및 콘텐츠 표시를 통합적으로 관리하는 Lua 스크립트 모듈입니다. 사용자 입력과 AI 출력을 기반으로 동적인 HTML UI를 생성하고, 이미지 생성 프롬프트를 관리하며, 사용자 액션(예: 리롤)에 반응합니다.

## 주요 기능 (Features)

*   **동적 UI 생성:**
    *   다양한 콘텐츠 타입(프로필, 시뮬레이션 카드, DC 게시글, 에로 스테이터스, 트윗, 카카오톡 메시지)에 대한 리롤(Reroll) UI 제공
    *   에로 스테이터스 카드 HTML 렌더링
    *   시뮬레이션 봇 카드 HTML 렌더링
    *   트위터 스타일 포스트 HTML 렌더링
    *   DCInside 스타일 게시글 및 댓글 HTML 렌더링
    *   카카오톡 스타일 메시지 HTML 렌더링
*   **템플릿 기반 콘텐츠 파싱:**
    *   AI가 특정 형식(예: `STATUS[...]`, `TWITTER[...]`)으로 출력한 텍스트를 파싱하여 구조화된 데이터로 변환
*   **이미지 생성 연동:**
    *   AI 출력 내 이미지 플레이스홀더(예: `<NAI1>`, `<NOIMAGE>`)를 인식하고, 해당 위치에 실제 이미지 또는 이미지 생성 프롬프트를 삽입/관리
    *   다양한 콘텐츠 유형에 맞는 이미지 생성 프롬프트 자동 구성
*   **설정 기반 동작 변경:**
    *   글로벌 변수(토글)를 통해 모듈의 세부 동작(예: 이미지 포함 여부, 대상 캐릭터)을 제어
*   **이벤트 처리:**
    *   RisuAI의 입력, 요청, 출력, 버튼 클릭 이벤트에 연동하여 상황에 맞는 로직 수행
*   **유틸리티:**
    *   HTML 및 JSON 문자열 이스케이프 처리
    *   오류 메시지 알림
    *   채팅 기록 조작 및 변수 관리

## 핵심 구성 요소 (Core Components)

*   **UI 생성 및 관리:**
    *   `showRerollForms`: 생성된 이미지 또는 콘텐츠에 대한 리롤 UI를 동적으로 생성하여 채팅에 추가합니다.
    *   `changeInlay`: 채팅 기록 내 특정 내용을 새로운 내용(주로 이미지 태그)으로 교체합니다.
*   **콘텐츠 유형별 처리:**
    *   `inputEroStatus` / `changeEroStatus`: AI가 '에로 스테이터스' 정보를 생성하도록 유도하는 프롬프트를 추가하고, AI의 출력을 HTML 카드로 변환합니다.
    *   `inputSimulCard` / `changeSimulCard`: AI가 '시뮬레이션 봇' 정보를 생성하도록 유도하는 프롬프트를 추가하고, AI의 출력을 HTML 카드로 변환합니다.
    *   `inputTwitter` / `changeTwitter`: AI가 '트위터' 형식의 게시글을 생성하도록 유도하는 프롬프트를 추가하고, AI의 출력을 트위터 UI와 유사한 HTML로 변환합니다.
    *   `inputDCInside` / `changeDCInside`: AI가 'DCInside' 게시글 형식으로 응답하도록 유도하는 프롬프트를 추가하고, AI의 출력을 DCInside UI와 유사한 HTML로 변환합니다.
    *   `inputKAKAOTalk` / `changeKAKAOTalk`: AI가 '카카오톡' 메시지 형식으로 응답하도록 유도하는 프롬프트를 추가하고, AI의 출력을 카카오톡 UI와 유사한 HTML로 변환합니다.
*   **이미지 프롬프트 생성:**
    *   `inputImage`: 현재 활성화된 콘텐츠 유형(카드, SNS 등)에 맞춰 이미지 생성에 필요한 상세 프롬프트(긍정적/부정적)를 구성합니다.
*   **이스케이프 함수:**
    *   `escapeHtml`: HTML 특수 문자를 이스케이프합니다.
    *   `escapeJsonValue`: JSON 문자열 값을 이스케이프합니다.
*   **오류 처리:**
    *   `ERR`: 모듈 내에서 발생하는 특정 오류 상황에 대해 사용자에게 알림을 표시합니다.
*   **이벤트 리스너:**
    *   `listenEdit("editInput", ...)`: 사용자 입력 단계에서 특정 조건(주로 메신저 모드)에 따라 입력 데이터를 가공합니다.
    *   `listenEdit("editRequest", ...)`: AI에게 요청을 보내기 직전, 활성화된 모듈 설정에 따라 필요한 지시사항(프롬프트)을 요청 데이터에 추가합니다.
    *   `listenEdit("editDisplay", ...)`: AI의 응답을 사용자에게 보여주기 직전, 특정 패턴(예: `STATUS[...]`)을 감지하여 HTML UI로 변환합니다.
    *   `onInput(...)`: 사용자 입력 후 AI 응답이 생성되기 전에 실행되며, 이전 AI 응답에 포함된 특정 UI를 접기/펴기 가능한 형태로 변환하는 등의 전처리 작업을 수행합니다.
    *   `onOutput(...)`: AI 응답 생성 후 실행되며, 응답 내용에서 이미지 생성 지시자(예: `<NAI1>`)를 찾아 실제 이미지를 생성하고 삽입합니다. 또한, 생성된 이미지들에 대한 리롤 UI를 표시합니다.
    *   `onButtonClick(...)`: 모듈이 생성한 HTML UI 내 버튼(주로 리롤 버튼) 클릭 시 실행되어 해당 액션을 처리합니다.

## 설정 (Toggles / Global Variables)

본 모듈은 RisuAI의 글로벌 변수(토글)를 통해 다양한 기능을 활성화/비활성화하거나 세부 동작을 제어합니다. 주요 토글은 다음과 같습니다:

*   `toggle_NAIGLOBAL`: 전체 이미지 생성 기능 활성화 여부.
*   `toggle_NAICARD`: 에로 스테이터스 또는 시뮬레이션 카드 기능 활성화 여부 (`1`: 에로 스테이터스, `2`: 시뮬레이션 카드).
*   `toggle_NAICARDNOIMAGE`: 카드 생성 시 이미지 포함 여부 (`0`: 포함, `1`: 미포함).
*   `toggle_NAICARDTARGET`: 카드 생성 대상 (`0`: 유저, `1`: 캐릭터, `2`: 모든 여성 캐릭터 - 에로 스테이터스 전용).
*   `toggle_NAISNS`: SNS(트위터) 인터페이스 기능 활성화 여부.
*   `toggle_NAISNSNOIMAGE`: SNS 게시물에 이미지 포함 여부.
*   `toggle_NAISNSTARGET`: SNS 게시물 생성 대상.
*   `toggle_NAISNSREAL`: SNS 게시물 업로드 시점.
*   `toggle_NAICOMMUNITY`: 커뮤니티(DCInside) 인터페이스 기능 활성화 여부.
*   `toggle_NAICOMMUNITYNOIMAGE`: 커뮤니티 게시물에 이미지 포함 여부.
*   `toggle_NAIDCPOSTNUMBER`: DCInside 게시물 생성 개수.
*   `toggle_NAIDCNOSTALKER`: DCInside 게시물 내 유저/캐릭터 언급 금지 여부.
*   `toggle_NAIMESSENGER`: 메신저(카카오톡) 인터페이스 기능 활성화 여부.
*   `toggle_NAIMESSENGERNOIMAGE`: 메신저 메시지에 이미지 포함 여부.
*   `toggle_NAIPRESETPROMPT`: 이미지 생성 시 사용할 사전 설정된 프롬프트 세트 번호.
*   `toggle_NAIARTISTPROMPT`, `toggle_NAIQUALITYPROMPT`, `toggle_NAINEGPROMPT`: 사용자 정의 아티스트, 품질, 부정적 프롬프트 (사전 설정 미사용 시).
*   `toggle_NAICOMPATIBILITY`: 이미지 프롬프트 내 괄호 `{}`를 `()`로 변경할지 여부.
*   `toggle_NAIORIGINAL`, `toggle_NAIORIGINALTEXT`: 원작 기반 캐릭터 묘사 여부 및 원작명.
*   `toggle_UTILREMOVEPREVIOUSDISPLAY`: 이전 AI 응답 전체를 접기/펴기 처리할지 여부.

## 사용법 (Usage)

RisuAIOnlineModule은 RisuAI 환경 내에서 자동으로 실행되도록 설계되었습니다. 사용자는 RisuAI의 설정을 통해 위에서 언급된 토글 값들을 조정하여 모듈의 동작을 커스터마이징할 수 있습니다. AI와의 대화 중 특정 키워드나 패턴이 감지되면 모듈이 활성화되어 관련 UI를 생성하거나 이미지 생성 로직을 수행합니다.
