# InBody 체성분 입력을 활용한 러닝 앱 페이스·거리 추천 알고리즘 설계에 대한 근거 기반 분석

## Executive summary

본 보고서는 “키·체중·나이·성별·체지방률(PBF)·골격근량(SMM)을 InBody로 측정해 입력하면, 러닝 앱이 **권장 페이스(min·km⁻¹)**와 **권장 운동거리(km)**를 출력”하는 알고리즘을 설계하기 위해, (가) InBody/체성분 변수를 사용한 **VO₂max(최대산소섭취량)** 예측식(국내 우선)과 (나) 예측된 VO₂max를 러닝 페이스·거리로 변환하기 위한 **ACSM 러닝 대사방정식**, (다) 거리 처방에 필요한 **지속가능 강도(임계/critical speed) 개념** 및 **부상위험을 고려한 초기 러닝 볼륨 처방 근거**를 결합한 “검증 가능한 파이프라인”을 제시한다. citeturn23view0turn27search0turn33view0turn34search0turn20view1turn26search13turn15search1

핵심 결론은 다음과 같다. 첫째, **InBody 입력만(6개 변수만)으로 러닝 페이스/거리를 직접 예측하는(=페이스 또는 거리 자체를 종속변수로 한) 한국어·동료심사 논문 기반 방정식은 확인되지 않았다**. 따라서 현실적인 앱 설계는 (1) **체성분 기반 VO₂max 추정**(또는 러닝 필드테스트 기반 VO₂max 추정) → (2) **VO₂max→vVO₂max(VO₂max 속도)→페이스 변환(ACSM)** → (3) **목표 강도·세션 타입별 거리/시간 처방**의 3단계 파이프라인이 가장 방어 가능하다. citeturn23view0turn27search0turn33view0turn34search0

둘째, 국내 문헌에서 **체지방률(PBF)**은 VO₂max 예측에 일관되게 포함되는 경향이 있으며(음의 계수), 청소년 PACER 기반 예측식은 **InBody 720 체지방률을 명시적으로 사용**한다. 반면 **골격근량(SMM)을 독립변수로 직접 포함**한 러닝 기반 예측식은(본 조사 범위에서) 확인되지 않아, SMM은 ① 위험/신뢰도 플래그(예: 낮은 SMM·높은 PBF에서 보수적 처방) ② 개인화 보정(추후 앱 내 재학습/캘리브레이션) 변수로 쓰는 설계가 합리적이다. citeturn27search0turn23view0turn29view0

셋째, VO₂→속도 변환에는 널리 쓰이는 **ACSM 러닝 방정식**(VO₂ = 0.2·speed + 0.9·speed·grade + 3.5)이 있으나, 임상/특정 집단에서 오차가 커질 수 있어(예: 다른 회귀식 대비 과대추정) 앱은 **예측구간(PI)과 신뢰도 표시**, **현장 러닝 테스트(예: PACER/Cooper/최근 레이스 기록)로 보정**을 기본 UX로 포함해야 한다. citeturn34search0turn34search2turn33view0

## 연구 범위와 문헌 선정 기준

본 보고서의 “근거 문헌”은 다음 기준으로 포함·제외하였다.

포함 기준은 (1) 동료심사 학술논문(국내 우선) (2) 종속변수가 VO₂max(또는 VO₂peak)인 예측식/모델을 제시하거나, 혹은 러닝 수행(셔틀런/PACER/트레드밀 달리기) 맥락에서 VO₂max를 추정하는 공식이 제시된 연구 (3) 독립변수에 최소한 **InBody 체지방률(PBF)** 또는 (키·체중·성별·나이 등) 러닝 앱 입력으로 현실적으로 수집 가능한 변수가 포함되며, 회귀계수/성능지표(예: R², SEE, ICC, Bland–Altman)가 제시된 연구이다. citeturn27search0turn33view0turn23view0

제외 기준은 (1) 러닝과 무관하게 **사이클/로잉 등 다른 종목만**을 대상으로 한 예측모델(본 보고서의 “러닝 페이스” 출력으로 직접 연결이 어렵기 때문) (2) 동료심사 아닌 블로그/상업 자료 (3) InBody 변수 없이 일반적 서술만 있는 자료이다. 다만 안전·측정 표준화·검사 정의를 위해서는 심폐운동부하검사(CPET) 가이드 및 InBody 장비 매뉴얼(공식 문서)을 보조근거로 사용했다. citeturn17search2turn20view1

**부정적(negative) 결과의 명시:** “InBody 6개 입력(키·체중·나이·성별·PBF·SMM)만으로 러닝 페이스(min·km⁻¹) 또는 권장 거리(km)를 직접 산출하는 동료심사 방정식”은 본 조사에서 확인되지 않았다. 따라서 페이스/거리 출력은 **VO₂max(또는 유사 중간지표)**를 매개로 변환·처방하는 형태로 설계해야 한다. citeturn23view0turn27search0turn33view0

## 러닝 성과 목표변수와 측정, 그리고 페이스·거리 변환 원리

VO₂max(또는 VO₂peak)는 점증적 운동부하 중 산소섭취가 도달 가능한 최대 수준을 의미하며, 실험실에서는 트레드밀/사이클의 점증부하와 호기 가스분석으로 측정한다. CPET 과학성명은 VO₂peak/VO₂max를 포함한 CPET 지표의 임상적 의미와 검사 표준화를 다루며, 트레드밀 기반 VO₂ 측정이 “최대 유산소 능력”의 대표적 기준임을 전제로 한다. citeturn17search2turn33view0

러닝 앱 관점에서 최종 출력은 보통 **(a) 권장 페이스(min·km⁻¹)**와 **(b) 권장 거리(km)**이다. 그러나 문헌에서 직접적으로 “페이스/거리”를 종속변수로 하는 InBody 기반 방정식이 부족하므로, 현실적 파이프라인은 다음처럼 중간지표를 둔다.

- **VO₂max 추정(또는 측정)**: 비운동(설문 기반), 러닝 필드테스트(PACER), 혹은 서브맥스 트레드밀/스텝테스트 등으로 VO₂max를 추정할 수 있다. 한국 성인 19–64세에서는 PACER·스텝·트레드밀 서브맥스 데이터로 VO₂max 회귀식을 개발·검증해 PACER가 가장 높은 설명력(≈71.7%)을 보였다고 보고한다. citeturn33view0  
- **VO₂max → vVO₂max → 페이스**: ACSM 러닝 대사방정식은 트레드밀 속도(speed)와 경사(grade)로 VO₂를 추정하며, 이를 역으로 풀어 “특정 VO₂에 해당하는 속도”를 구해 페이스로 변환한다(아래 식). citeturn34search0turn34search2  
- **페이스 → 권장 거리**: 세션 타입(이지/템포/롱런 등)별 목표강도(예: VO₂max의 일정 비율 또는 임계속도 기반)와 목표시간(분)을 정하면 거리 = 시간 ÷ 페이스로 산출된다. 단, 초보·비만·고령 집단에서는 주당 시작거리와 증가폭이 부상위험에 영향을 주므로 “거리 처방”은 안전 근거를 포함해야 한다. BMI>30 비만 초보 러너에서 첫 주/초기 누적거리의 차이가 부상 위험과 관련됨을 보고한 연구가 있어, 앱은 체중/체지방이 높은 사용자에 대해 초기 거리를 보수적으로 설정하는 설계가 타당하다. citeturn26search13turn26search2

### 핵심 변환식

ACSM 러닝(달리기) 방정식(속도 m·min⁻¹, grade는 소수; 예 1% = 0.01)은 다음과 같이 인용된다. citeturn34search0turn34search2

- **정방향(속도→VO₂)**  
  VO₂(mL·kg⁻¹·min⁻¹) = 0.2·v + 0.9·v·grade + 3.5 citeturn34search0turn34search2

- **역방향(VO₂→속도)**  
  v = (VO₂ − 3.5) / (0.2 + 0.9·grade)  (m·min⁻¹) citeturn34search0turn34search2

- **속도→페이스 변환**  
  pace(min·km⁻¹) = 1000 / v citeturn34search0turn34search2

트레드밀에서 실외 러닝의 에너지 비용을 가깝게 만들기 위해 약 1% 경사 적용을 제안한 고전 연구(평지 실외의 공기저항을 상쇄하기 위한 근사)가 있으며, 실제 앱 구현에서 “실외 러닝 페이스”를 목표로 한다면 grade=0.01을 기본값으로 두는 선택이 합리적이다. citeturn0search25

**주의:** ACSM 방정식은 “대사비용의 표준 회귀식”으로 널리 쓰이지만, 특정 집단(예: CAD 환자)에서는 다른 회귀식(FRIEND 등)과 비교할 때 과대추정(MAPE ~20%)이 보고되어, 앱은 예측치에 대한 과신을 피하고 **예측구간/보정 절차**를 반드시 포함해야 한다. citeturn34search2turn33view0

## InBody/체성분 기반 VO₂max 예측식 근거와 비교

아래 표는 “러닝 앱 입력(또는 실무적으로 수집 가능한 필드테스트)”과 결합해 VO₂max를 예측할 수 있는 국내 우선 방정식/모델을 요약한 것이다. 특히 **InBody를 명시적으로 사용한 러닝 기반 예측식은 청소년 PACER 연구(2019)**가 확인되며, 성인에서는 InBody 대신 키·체중·연령·성별과 PACER 카운트(및 HR)를 포함하는 대규모 회귀식(2022)이 공개되어 있다. citeturn27search0turn33view0turn23view0

### 비교 요약표

| 연구(국가) | 표본(연령/성별) | 러닝 테스트/측정 | 체성분·입력변수 | 목표변수 | 모델/성능 | 한계(핵심) |
|---|---:|---|---|---|---|---|
| entity["people","이정아","pt researcher, korea"] 등, 2005(한국) citeturn23view0 | n=101 (19–35세) | 트레드밀 Balke + 가스분석(기준 VO₂max) citeturn23view0 | %fat, 성별(남0/여1), 신체활동평정(PAR) (옵션: HRmax/HRrest) citeturn23view0 | VO₂max(mL/kg/min) citeturn23view0 | 비운동 회귀식: R²≈0.70, SEE≈3.74 (HR변수 제외식) citeturn23view0 | 나이·키·체중·SMM 미포함(적용범위 제한), PAR 필요(앱 추가 입력 필요) citeturn23view0 |
| entity["people","On Lee","exercise scientist, korea"] & entity["people","Jin-Wook Chung","exercise scientist, korea"], 2019(한국) DOI:10.15857/ksep.2019.28.2.168 citeturn27search0 | n=407(청소년) | 20m PACER + 기준 VO₂max(최대부하검사) citeturn27search0 | **InBody 720 체지방률(PBF)** + PACER 횟수 + 성별(남=1) + 신장 citeturn27search0 | VO₂max(mL/kg/min) citeturn27search0 | 회귀식 R²=0.772, SEE=3.579, ICC≈0.871, Bland–Altman LoA 제시 citeturn27search0 | 성인 일반화 불가(청소년 전용), SMM 미포함 citeturn27search0 |
| entity["people","박동호","exercise researcher, korea"] 등, 2014(한국) citeturn1view1 | n=58(여중생) | 20m 왕복셔틀런 + 기준 VO₂max(트레드밀) citeturn1view1 | (InBody 명시 없음) 왕복횟수, 체중 citeturn1view1 | VO₂max(mL/kg/min) citeturn1view1 | 공식: VO₂max=0.231·laps −0.311·weight +46.201; r=0.74, SEE=4.29 citeturn1view1 | 성별/연령 제한(여중생), 체성분 직접 변수(PBF/SMM) 없음 citeturn1view1 |
| entity["people","Jinwook Chung","exercise scientist, korea"] & entity["people","Kihyuk Lee","exercise scientist, korea"], 2022(한국/국제저널) Appl. Sci. 12:1371 citeturn33view0 | n=541(19–64세) | PACER/스텝/트레드밀 서브맥스 + 기준 VO₂max(최대 GXT) citeturn33view0 | PACER식: 성별·나이·신장·체중·counts (InBody 변수는 미포함) citeturn33view0 | VO₂max(mL/kg/min) citeturn33view0 | PACER 회귀식 SEE=3.732, ICC=0.910, Bland–Altman 제시 citeturn33view0 | PBF·근육량 변수를 추가 고려할 필요를 저자도 언급(추가연구 필요) citeturn29view0 |
| entity["people","T.W. Jang","occupational medicine, korea"] 등, 2012(한국/국제저널) citeturn24view0 | n=217(남 21–55, 여 20–64) | Queens College step test 기반 VO₂max 추정값을 종속변수로 회귀 citeturn24view0 | 나이·성별·BMI·흡연·여가 신체활동평정 + 직무활동(보행/육체노동 등) citeturn24view0 | VO₂max(mL/kg/min) citeturn24view0 | Adj R²=0.791, SEE=3.360; 방정식 계수 공개 citeturn24view0 | 러닝 직접 측정 아님(스텝테스트 기반), InBody PBF/SMM 미포함 citeturn24view0 |

### 핵심 예측식 원문 수준 정리

- (국내/비운동, 19–35세)  
  VO₂max = 48.47 − 0.41·(%fat) + 0.45·(physical activity rating) − 5.12·(female; 남=0, 여=1)  
  (R≈0.84, SEE≈3.74, R²≈0.70) citeturn23view0

- (국내/청소년 PACER+InBody 720)  
  VO₂max = 53.550 + 0.169·(PACER 횟수) − 0.333·(체지방률) + 2.276·(성별; 남=1, 여=0) − 0.080·(신장)  
  (R²=0.772, SEE=3.579; ICC≈0.871; Bland–Altman 제시) citeturn27search0

- (국내/성인 19–64 PACER)  
  VO₂max = 43.418 + 5.114·(성별; 남=1, 여=0) − 0.094·(나이) − 0.022·(신장) − 0.135·(체중) + 0.229·(PACER counts)  
  (SEE=3.732; ICC=0.910; Bland–Altman 제시) citeturn33view0

이들 식에서 관찰되는 패턴은 다음과 같다. (1) **PBF는 음(-)의 계수**로 포함되는 경우가 많았다(건강한 젊은 성인 비운동식, 청소년 InBody 기반식). citeturn23view0turn27search0 (2) **SMM을 직접 포함한 러닝 기반 공개식은 확인되지 않았고**, 성인 대규모 연구(2022)는 키·체중·나이·성별+PACER counts 중심이며, 저자도 “체지방/근육량 등 추가 변수 고려 필요”를 한계로 명시한다. citeturn29view0turn33view0

### 원문 링크/DOI 모음(요청 형식: 코드블록)

```text
이정아 외(2005) KCI 상세(방정식 포함):
https://www.kci.go.kr/kciportal/ci/sereArticleSearch/ciSereArtiView.kci?sereArticleSearchBean.artiId=ART000971411

On Lee & Jin-Wook Chung(2019) Exercise Science PDF (InBody 720 명시, 방정식/ICC/LoA 포함):
https://www.ksep-es.org/upload/pdf/es-28-2-168.pdf
DOI: https://doi.org/10.15857/ksep.2019.28.2.168

Chung & Lee(2022) Applied Sciences PDF (PACER/스텝/트레드밀 회귀식 포함):
https://www.mdpi.com/2076-3417/12/3/1371/pdf
DOI: https://doi.org/10.3390/app12031371

T.W. Jang et al.(2012) Tohoku J Exp Med PDF (비운동 회귀식 계수 포함):
https://www.jstage.jst.go.jp/article/tjem/227/4/227_313/_pdf
```

## 러닝 앱 알고리즘 설계 제안

이 절은 “6개 InBody 입력(키·체중·나이·성별·PBF·SMM)”을 **필수 입력**으로 받고, 필요 시 “선택 입력(필드테스트/웨어러블 HR/최근 기록)”을 받아 정확도를 올리는 구조로 설계한다. 핵심은 **근거가 있는 회귀식은 VO₂max까지**가 대부분이므로, 페이스·거리는 **표준 변환식 + 안전 기반 처방 규칙**으로 산출하되, 불확실성을 수치로 함께 내보내는 것이다. citeturn23view0turn27search0turn33view0turn34search0turn26search13

### 파이프라인 개요

```mermaid
flowchart TD
  A[필수 입력: 키, 체중, 나이, 성별, PBF, SMM] --> B{가용 데이터에 따라 VO2max 모델 선택}
  B -->|청소년 + PACER 가능| C1[VO2max 예측: PACER + PBF(InBody) + 성별 + 키]
  B -->|성인 + PACER 가능| C2[VO2max 예측: PACER + 성별 + 나이 + 키 + 체중]
  B -->|19-35세 + 활동평정 가능| C3[VO2max 예측: PBF + 성별 + 활동평정(+선택 HR비)]
  B -->|그 외| C4[보수적 초기값/추가 테스트 권유(캘리브레이션 런)]
  C1 --> D[VO2max ± 예측오차(SEE) 산출]
  C2 --> D
  C3 --> D
  C4 --> D
  D --> E[ACSM 러닝 방정식 역산 -> vVO2max -> 페이스]
  E --> F[세션 타입별 목표 강도(비율/임계속도) 결정]
  F --> G[권장 시간(분)·빈도·초기 주간거리 규칙 + 위험 플래그]
  G --> H[출력: 권장 페이스 ± PI, 권장 거리 ± PI, 신뢰도/안전 경고]
```

ACSM 방정식(VO₂=0.2·v+0.9·v·grade+3.5)을 이용해 vVO₂max와 페이스로 변환하며, 실외 러닝 근사를 위해 기본 grade=1%(0.01)을 택하는 옵션을 제공한다. citeturn34search0turn0search25

### 구체 알고리즘 설계안

#### 설계안 A: “InBody + (권장) PACER 1회” 중심(성인/청소년 공통)

1) **입력 수집(필수 + 선택)**  
- 필수: 키(cm), 체중(kg), 나이(yr), 성별, PBF(%), SMM(kg)  
- 선택: PACER counts(왕복 횟수), 최근 5km/10km 기록(시간), 휴식시 심박수, 금연/흡연 등

2) **VO₂max 예측(모델 선택 로직)**  
- 청소년(교육 연령대) + PACER 가능: 2019 국내식( InBody 720 PBF 포함 ) 사용 citeturn27search0  
- 성인(19–64) + PACER 가능: 2022 성인 PACER 식 사용 citeturn33view0  
- 19–35 + 활동평정 가능: 2005 비운동식 사용(가스분석 기준으로 개발) citeturn23view0  
- 그 외: “추가 테스트 권장” + 보수적 처방(아래 안전 모듈) citeturn17search5turn26search13

3) **VO₂max 예측오차(불확실성) 부여**  
각 회귀식의 SEE를 잔차 표준편차로 간주해,  
- 95% 예측구간(근사): VO₂max_PI ≈ ŷ ± 1.96·SEE  
로 산출한다. (해당 SEE는 원논문에 제시됨) citeturn23view0turn27search0turn33view0

4) **VO₂max → 페이스 변환(ACSM 역산)**  
- vVO₂max = (VO₂max − 3.5)/(0.2 + 0.9·grade)  
- pace_vVO₂max = 1000 / vVO₂max  
이때 grade 기본값은 0.01(트레드밀 1%) 또는 0(평지)로 선택 가능. citeturn34search0turn0search25

5) **세션별 목표강도→권장 페이스**  
직접적인 “VO₂max→템포페이스” 근거식이 InBody 기반으로 확립돼 있지 않으므로, 앱은 **가정 기반 규칙**을 명시하고(아래 “가정” 표기), 사용자 보정으로 업데이트해야 한다.  
- 템포(임계에 준하는 지속주): 목표 VO₂ = 0.85·VO₂max (가정)  
- 롱런(지속 유산소): 목표 VO₂ = 0.75·VO₂max (가정)  
마라톤의 평균 페이스가 VO₂max의 75–85% 수준에서 형성된다는 리뷰 진술은 “지속주/롱런 강도 설정의 출발점”으로 활용 가능하나, 개인의 러닝경제성·임계비율 차이가 커 보정이 필요하다. citeturn16search20turn34search0

6) **권장 거리 산출(시간 기반 처방 + 안전 규칙)**  
- 세션 시간(분)은 “사용자 수준/부상위험(BMI 등)”에 따라 규칙 기반으로 추천한다.  
- 거리(km) = 시간(분) ÷ 페이스(min·km⁻¹)  
비만 초보(BMI 30–35)에서 초기 주간거리(예: 3km vs 6km)가 부상발생에 영향을 줄 수 있다는 근거가 있어, 앱은 고 BMI·고 PBF 사용자에게 초기 세션 거리를 보수적으로 설정하고 점진 증가 정책을 적용해야 한다. citeturn26search13turn26search2

#### 설계안 B: “임계속도(critical speed) 기반 거리 추천” 옵션(기록 기반 개인화)

VO₂max만으로 거리·지속시간을 강하게 처방하기 어렵다면, 앱은 **사용자의 최근 기록 2개(예: 1.5km, 5km 또는 3km, 10km)**로 critical speed(CS) 파라미터를 추정하는 모듈을 별도로 제공할 수 있다. CS 개념은 강도 영역(heavy vs severe)을 가르는 경계로 제시되며, 다양한 수학적 형태가 동치이고(거리–시간 선형화 등) 실무 처방에 활용된다. citeturn15search1turn15search10

- 2점(두 기록) 선형모형(거리–시간):  
  d = CS·t + D′  
  (d: m, t: s)  
  CS = (d₂−d₁)/(t₂−t₁),  D′ = d₁ − CS·t₁  
이후 템포/지속주는 CS 이하(예: 0.95·CS 등), 인터벌은 CS 초과(예: 1.05·CS 등)로 페이스를 제안하고, 거리(또는 시간)는 D′ 소모를 기준으로 제한한다(예: 1회 세션에서 D′의 30–60%만 사용). **단, 이 비율은 문헌-직접 최적값이 고정돼 있지 않으므로 앱 내 실험/검증이 필요**하다. citeturn15search1turn15search10

### 불확실성 전파(VO₂max SEE → 페이스/거리 PI)

VO₂max 예측오차(SEE)가 페이스로 전파되는 민감도는 ACSM 역산식에서 도출된다.

- v = (VO₂ − 3.5)/k,  k=(0.2 + 0.9·grade) citeturn34search0  
- pace = 1000/v  (min·km⁻¹)  
따라서 VO₂가 낮아질수록(혹은 grade가 커질수록) 같은 SEE가 페이스 불확실성을 더 크게 만든다. 이는 앱이 **저체력/고령 사용자에게 넓은 PI와 보수 처방**을 제공해야 함을 의미한다. citeturn34search0turn17search5

### 구현용 의사코드

```text
INPUT (required):
  height_cm, weight_kg, age_yr, sex {M/F}, PBF_percent, SMM_kg
INPUT (optional):
  pacer_counts, activity_rating_0to10, resting_hr, stage3_hr, smoker_0or1, work_PA_vars, recent_race_times

STEP 0: Validate & risk flags
  compute BMI = weight_kg / (height_cm/100)^2
  flag_high_BMI = (BMI >= 30)
  flag_high_PBF = (sex==M and PBF>25) or (sex==F and PBF>35)   # 임계값은 제품/학술기준과 다를 수 있어 '보수 플래그'로만 사용
  flag_low_SMM = SMM_kg / (height_cm/100)^2 < threshold_SMI    # 인구집단별 기준 필요(추후 보정)
  if contraindication questionnaire positive -> show medical referral prompt (no pace prescription)

STEP 1: Choose VO2max model
  if age in adolescent_range AND pacer_counts available:
      use Lee&Chung2019: VO2max_hat = 53.550 + 0.169*pacer - 0.333*PBF + 2.276*sex_male - 0.080*height_cm
      SEE = 3.579
  else if age in [19,64] AND pacer_counts available:
      use Chung&Lee2022 PACER: VO2max_hat = 43.418 + 5.114*sex_male - 0.094*age - 0.022*height_cm - 0.135*weight_kg + 0.229*pacer_counts
      SEE = 3.732
  else if age in [19,35] AND activity_rating available:
      use Lee2005 non-exercise: VO2max_hat = 48.47 - 0.41*PBF + 0.45*activity_rating - 5.12*sex_female
      SEE = 3.74
  else if smoker and activity/work vars available:
      use Jang2012: VO2max_hat = 43.978 -0.123*age +11.642*sex_male -0.271*BMI -1.365*smoker +0.701*leisure_PA + ...
      SEE = 3.360
  else:
      VO2max_hat = conservative default (require calibration run)
      SEE = large_default

STEP 2: Prediction interval for VO2max
  VO2_PI_low  = VO2max_hat - 1.96*SEE
  VO2_PI_high = VO2max_hat + 1.96*SEE

STEP 3: Convert VO2 -> pace using ACSM inverse equation
  grade = user_setting default 0.01
  function pace_from_VO2(VO2):
      v_m_per_min = (VO2 - 3.5) / (0.2 + 0.9*grade)
      pace_min_per_km = 1000 / v_m_per_min
      return pace_min_per_km

  pace_vVO2max = pace_from_VO2(VO2max_hat)
  pace_vVO2max_PI = [pace_from_VO2(VO2_PI_high), pace_from_VO2(VO2_PI_low)]  # high VO2 = faster = lower pace

STEP 4: Session pace targets (heuristic, adjustable)
  tempo_VO2 = 0.85 * VO2max_hat
  long_VO2  = 0.75 * VO2max_hat
  tempo_pace = pace_from_VO2(tempo_VO2)
  long_pace  = pace_from_VO2(long_VO2)
  compute PI similarly using VO2 PI.

STEP 5: Distance prescription
  choose duration_min by fitness tier & risk flags
    if flag_high_BMI or flag_high_PBF or beginner:
         tempo_duration = 10-15 min (or skip tempo)
         long_duration  = 20-40 min
    else:
         tempo_duration = 20-30 min
         long_duration  = 60-90 min
  distance_km = duration_min / pace_min_per_km
  propagate PI by using pace PI bounds.

OUTPUT:
  recommended tempo pace ± PI, recommended tempo distance ± PI
  recommended long pace ± PI, recommended long distance ± PI
  confidence label + safety messages + prompt for calibration run
```

## 수치 예시

아래 예시는 “예측식의 적용 범위”와 “가정(특히 템포/롱런 강도 비율)”을 명확히 표시한다. 특히 ACSM 방정식은 표준이지만 개인의 러닝경제성 차이로 페이스 오차가 커질 수 있으므로, 앱은 첫 1~2주 내 **보정 러닝(예: PACER 또는 12분 달리기, 혹은 최근 레이스 기록 입력)**을 요청하는 UX가 필수다. citeturn34search0turn34search2turn33view0

### 예시 1: 젊은 남성(레크리에이션 러너)

입력(필수): 키 175cm, 체중 70kg, 나이 25, 남, PBF 15%, SMM 33kg  
선택 입력: 신체활동평정(PAR)=6(예: 주 3–4회 유산소/러닝)  
모델: 2005 비운동식(19–35세 범위 내) citeturn23view0

- VO₂max 추정:  
  ŷ = 48.47 −0.41·15 +0.45·6 −5.12·0 = **45.02 mL/kg/min** citeturn23view0  
  95% PI(근사): 45.02 ± 1.96·3.74 ⇒ **37.69 ~ 52.35** citeturn23view0

- vVO₂max 페이스(grade=1% 가정):  
  pace ≈ **5.03 min/km**  
  PI: **4.28 ~ 6.11 min/km** citeturn34search0turn0search25turn23view0

- 템포(가정: 0.85·VO₂max) 페이스:  
  **6.01 min/km** (PI: **5.10 ~ 7.32**) citeturn34search0turn23view0

- 롱런(가정: 0.75·VO₂max) 페이스:  
  **6.91 min/km** (PI: **5.84 ~ 8.44**) citeturn34search0turn23view0

- 거리 예시(가정: 템포 20분, 롱런 60분):  
  템포 거리 ≈ 20/6.01 = **3.33 km** (PI: **2.73 ~ 3.92 km**)  
  롱런 거리 ≈ 60/6.91 = **8.69 km** (PI: **7.11 ~ 10.28 km**)  
  (PI는 페이스 PI를 시간 고정 하에 변환) citeturn34search0turn23view0

### 예시 2: 중년 여성(레크리에이션 러너)

입력(필수): 키 162cm, 체중 60kg, 나이 45, 여, PBF 30%, SMM 22kg  
선택 입력: PACER counts=30 (앱 내 20m 셔틀런 1회 수행)  
모델: 2022 성인 PACER 식(19–64세 범위 내) citeturn33view0

- VO₂max 추정:  
  ŷ = 43.418 +5.114·0 −0.094·45 −0.022·162 −0.135·60 +0.229·30  
  = **34.39 mL/kg/min** citeturn33view0  
  95% PI(근사): 34.39 ± 1.96·3.732 ⇒ **27.08 ~ 41.70** citeturn33view0

- vVO₂max 페이스(grade=1%): **6.77 min/km** (PI: **5.47 ~ 8.86**) citeturn34search0turn0search25turn33view0  
- 템포(0.85·VO₂max 가정): **8.12 min/km** (PI: **6.61 ~ 10.89**) citeturn34search0turn33view0  
- 롱런(0.75·VO₂max 가정): **9.37 min/km** (PI: **7.64 ~ 12.55**) citeturn34search0turn33view0  

거리 예시(템포 15분, 롱런 45분처럼 “초보-중급 보수 처방”을 적용):  
- 템포 거리 ≈ 15/8.12 = **1.85 km** (PI: **1.38 ~ 2.27 km**)  
- 롱런 거리 ≈ 45/9.37 = **4.80 km** (PI: **3.59 ~ 5.89 km**) citeturn26search13turn33view0turn34search0  

### 예시 3: 고령(좌식 생활) 사용자

입력(필수): 키 158cm, 체중 65kg, 나이 68, 여, PBF 38%, SMM 20kg  
선택 입력(가정): 흡연=0, 여가 신체활동평정=1, 직무활동=0(은퇴)  
모델: 2012 성인 근로자 비운동 회귀식(연령 상한이 여 64세로 완전히 일치하진 않으므로 **외삽 경고** 필요) citeturn24view0turn17search5

- VO₂max 추정(직무활동 0 가정):  
  ŷ ≈ 43.978 −0.123·68 +11.642·0 −0.271·BMI −1.365·0 +0.701·1  
  (BMI≈26.0) ⇒ **약 29.27 mL/kg/min** citeturn24view0  
  95% PI(근사): 29.27 ± 1.96·3.36 ⇒ **22.68 ~ 35.86** citeturn24view0  

- vVO₂max 페이스(grade=1%): **8.11 min/km** (PI: **6.46 ~ 10.89**) citeturn34search0turn0search25turn24view0  

**안전 권고(중요):** 고령·좌식 생활 + 높은 PBF/낮은 SMM 프로파일에서는 “템포(임계) 러닝” 자체를 처방하기보다, CPET/사전 선별(증상/질환 여부) 후 **걷기-조깅 혼합**과 점진적 볼륨 증가가 우선이다. ACSM 사전선별 가이드 및 CPET 금기/주의사항 문헌은 증상·질환이 있는 경우 의학적 평가를 동반할 것을 강조한다. citeturn17search5turn17search2turn20view1

따라서 앱 출력 예시는 다음처럼 “대체 세션”으로 표현하는 것이 임상적으로 더 안전하다(가정 명시).  
- ‘지속 유산소(걷기/조깅)’ 목표 VO₂ = 0.65·VO₂max (가정) → pace ≈ 12–13 min/km 수준(개인 차 큼)  
- 권장 시간 20–30분, 주 3회부터 시작(증상/기저질환 있으면 의료상담) citeturn17search5turn34search0turn26search11

## 측정 표준화, UX 프로토콜, 안전·윤리 및 검증 계획

### InBody 입력 측정 표준화(앱 UX 권장)

InBody 770 트레이닝 매뉴얼은 검사 전 주의사항(운동·식사·카페인/알코올·사우나·로션 등)과 검사 전 행동(전날 수분섭취, 5분 이상 직립, 배뇨, 금속 제거 등)을 구체적으로 제시한다. 앱은 “InBody 측정값 업로드” UX에서 아래 체크리스트를 강제/권고 입력으로 두고, 조건 위반 시 **신뢰도 낮음** 플래그를 반환하는 것이 타당하다. citeturn20view1

- 검사 전 피하기: 6–12시간 내 운동, 3–4시간 내 식사, 24시간 내 알코올/카페인, 샤워/사우나, 손·발 로션 citeturn20view1  
- 검사 전 하기: 전날 충분한 수분섭취, 5분 이상 서 있기, 화장실 다녀오기, 양말/신발/금속 제거, 추운 환경이면 20분 워밍업 citeturn20view1

### 안전·윤리적 고지 및 금기 체크

러닝 앱이 “권장 페이스/거리”를 제시하는 것은 사용자에게 사실상 운동 처방으로 해석될 수 있으므로, 다음을 기본 탑재해야 한다.

- **사전 선별(증상/질환/약물/임신/심박기 등)**: ACSM 사전 선별 지침은 무증상자/질환자/현재 활동수준에 따라 의학적 평가 필요성이 달라짐을 체계화한다. citeturn17search5turn17search9  
- **CPET 및 고강도 운동 관련 주의**: AHA CPET 성명은 검사 표준화와 함께 임상적 위험 및 적절한 감독 필요성을 다룬다. citeturn17search2  
- **고 BMI·초보의 부상위험 고려**: BMI가 높은 초보 러너에서 초기 러닝 거리/노출량이 부상 위험과 관련될 수 있으므로, 고위험 사용자에게는 “거리·빈도·강도 보수화” 및 “걷기-조깅 혼합”을 기본값으로 둔다. citeturn26search13turn26search2  

### 모델 구현 파라미터, 캘리브레이션, 검증 설계

- 필수 파라미터: 각 VO₂max 회귀식의 계수, SEE, 적용 연령/집단 조건(예: 2019 청소년, 2022 성인 19–64 등). citeturn27search0turn33view0turn23view0  
- 전이/보정(캘리브레이션): ACSM 방정식이 집단에 따라 오차가 커질 수 있고, VO₂max→페이스 변환은 러닝경제성 개인차에 민감하므로, 앱은 “사용자 1회 보정 런”을 통해 개인별 보정계수(예: 실제 페이스 대비 예측 페이스 비율)를 학습해 업데이트해야 한다. citeturn34search2turn33view0  
- 검증 지표: 원논문들이 ICC, SEE, Bland–Altman LoA를 사용해 예측-실측 일치도를 평가하므로, 앱 검증도 동일 프레임워크(측정 vs 예측 산점도, Bland–Altman, 보정곡선)를 사용한다. citeturn27search0turn33view0  

### 권장 시각화(앱 내/리서치 리포트)

- **Measured vs Predicted VO₂max** 산점도 + 회귀선(기울기≈1, 절편≈0 여부) citeturn33view0turn27search0  
- **Bland–Altman plot**(bias 및 LoA) – 예측식 선택/캘리브레이션 전후 비교 citeturn33view0turn27search0  
- **페이스 예측구간 리본(plot)**: VO₂max PI→페이스 PI 전환 결과를 사용자에게 “범위”로 제시(과신 방지) citeturn34search0turn34search2  
- **BMI 또는 PBF 구간별 권장 주간거리/부상 플래그 히트맵**: 고 BMI 초보의 시작거리 보수화 근거를 UX로 투명화 citeturn26search13turn26search2  

### 근거의 공백과 향후 연구 과제

현재 공개된 국내 러닝 관련 VO₂max 회귀식에서 **InBody SMM(골격근량)이 직접 입력으로 채택된 사례는 확인되지 않았고**, 성인 대규모 모델(2022)도 PBF/근육량 변수를 “추가연구 필요”로 남겼다. citeturn29view0turn33view0 따라서 향후 연구는 (1) InBody PBF뿐 아니라 SMM, TBW, PhA 같은 BIA 파생변수를 포함한 러닝 VO₂max/임계속도 예측모델 (2) VO₂max뿐 아니라 **러닝 페이스(예: 임계 페이스, 5K/10K 성적, 운동경제성)**를 직접 종속변수로 한 모델 (3) 외부 코호트 검증과 인구집단별 전이학습을 우선 과제로 삼아야 한다. citeturn27search0turn33view0turn15search1