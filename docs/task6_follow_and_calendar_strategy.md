# Task 6 方針策定：自動フォロー仕様・Googleカレンダー同期・商談フェーズ確定

> **対象プロジェクト**: Minerva Demo  
> **作成日**: 2026-06-03  
> **根拠**: 5/26 Slack 合意事項 + 2026-05-13 MTG 決定事項 + コードベース調査

---

## 1. 商談フェーズ（StageName）確定マスター（5/26 確定）

### 1.1 ブランド別フェーズ定義

#### Minerva（RecordType: `Minerva_Consumer`）

| # | フェーズ名 | API 値 | 確率% | Won | Lost | 実装状態 |
|---|---|---|:---:|:---:|:---:|:---:|
| 1 | 新規会員登録 | `新規会員登録` | 10% | — | — | ✅ 実装済 |
| 2 | アプローチ中 | `アプローチ中` | 20% | — | — | ⚠️ 要修正 ※1 |
| 3 | 日程相談中 | `日程相談中` | 30% | — | — | ❌ 未追加 |
| 4 | 商談獲得 | `商談獲得` | 40% | — | — | ⚠️ 要確認 ※2 |
| 5 | 商談済み | `商談済み` | 50% | — | — | ❌ 未追加 |
| 6 | 購入済 | `受注_購入済` | 100% | ✅ Won | — | ✅ 実装済（ラベル差異あり） |
| 7 | NG／失注 | `NG` | 0% | — | ✅ Lost | ✅ 実装済 |

#### LHALA（RecordType: `LHALA_Wholesale`）

| # | フェーズ名 | API 値 | 確率% | Won | Lost | 実装状態 |
|---|---|---|:---:|:---:|:---:|:---:|
| 1 | 資料請求 | `資料請求` | 10% | — | — | ✅ 実装済 |
| 2 | アプローチ中 | `アプローチ中` | 20% | — | — | ⚠️ 要修正 ※1 |
| 3 | 日程相談中 | `日程相談中` | 30% | — | — | ❌ 未追加 |
| 4 | 商談獲得 | `商談獲得` | 40% | — | — | ⚠️ 要確認 ※2 |
| 5 | 商談実施済 | `商談実施済` | 50% | — | — | ❌ 未追加 |
| 6 | 申込・決済済み | `申込_決済済み` | 100% | — | — | ❌ 未追加 |
| 7 | 導入完了 | `導入完了` | 100% | ✅ Won | — | ✅ 実装済 |
| 8 | 失注 | `失注` | 0% | — | ✅ Lost | ❌ 未追加 ※3 |

#### LEMELLA（RecordType: `LEMELLA_Wholesale`）

| # | フェーズ名 | API 値 | 確率% | Won | Lost | 実装状態 |
|---|---|---|:---:|:---:|:---:|:---:|
| 1 | 資料請求 | `資料請求` | 10% | — | — | ✅ 実装済 |
| 2 | 説明会参加 | `説明会参加` | 30% | — | — | ✅ 実装済 |
| 3 | アプローチ中 | `アプローチ中` | 20% | — | — | ⚠️ 要修正 ※1 |
| 4 | 商談済み | `商談済み` | 50% | — | — | ❌ 未追加 |
| 5 | 申込・決済済み | `申込_決済済み` | 100% | ✅ Won | — | ❌ 未追加 |
| 6 | 導入完了 | `導入完了` | 100% | ✅ Won | — | ✅ 実装済 |
| 7 | 失注 | `失注` | 0% | — | ✅ Lost | ❌ 未追加 ※3 |

---

### 1.2 実装ギャップ整理

> ※1 **アプローチ中**：現在 `アプローチ`（ラベル・API値とも）で実装済み。5/26 確定値は `アプローチ中`。既存データへの影響を確認の上、API 値ごとリネームするか新規追加するかを決定する。
>
> ※2 **商談獲得**：既存の `商談`（確率40%）が近い値。名称統一を先方と確認の上、既存値のラベル変更で対応するか新規追加するかを決定する。
>
> ※3 **失注**：現在 `NG`（closed=true, won=false, 0%）が存在するが、LHALA/LEMELLA では「失注」の表示名が確定値。ラベル変更またはブランド別に `失注` を追加する。

### 1.3 追加が必要な OpportunityStage 値（未実装）

以下を `OpportunityStage.standardValueSet-meta.xml` に追加する（PR#8 相当）：

| API 値 | ラベル | 確率% | closed | won | 対象 RT |
|---|---|:---:|:---:|:---:|---|
| `日程相談中` | 日程相談中 | 30% | false | — | Minerva, LHALA |
| `商談獲得` | 商談獲得 | 40% | false | — | Minerva, LHALA |
| `商談済み` | 商談済み | 50% | false | — | Minerva, LEMELLA |
| `商談実施済` | 商談実施済 | 50% | false | — | LHALA |
| `申込_決済済み` | 申込・決済済み | 100% | true | true | LHALA, LEMELLA |
| `失注` | 失注 | 0% | true | false | LHALA, LEMELLA |

### 1.4 BusinessProcess ファイルへの反映も必要

各 RecordType は `businessProcess` を参照しているため、Stage 追加後に各ブランドの BusinessProcess XML にも追記が必要。

```
sf-src/.../objects/Opportunity/businessProcesses/
  ├── Minerva_Consumer_Process.businessProcess-meta.xml
  ├── LHALA_Wholesale_Process.businessProcess-meta.xml
  └── LEMELLA_Wholesale_Process.businessProcess-meta.xml
```

---

## 2. 30日経過後の自動フォロー仕様（Scheduled Flow 基本設計）

### 2.1 要件整理

| 要件 | 内容 |
|---|---|
| 対象レコード | Lead（リード）：Status が「アプローチ中」「見込み」等の未クローズ |
| トリガー条件 | **最終アプローチ日（`LastApproachDate__c`）から〇日経過**（⚠️ 具体値は先方回答待ち） |
| 実行アクション | フォローアップ Task を担当者（OwnerId）に作成 |
| 実行タイミング | 毎日深夜 0:00（バッチ実行）|
| 既存 Flow との関係 | `Lead_Reminder_Task`（SubStatus/Status 変更トリガー）は維持し、本 Flow は「経過日数」軸の補完として並存させる |

### 2.2 Scheduled Flow の設計（擬似設定）

```
Flow 名: Lead_Auto_FollowUp_Scheduled
種別:    スケジュール済みフロー（Schedule-Triggered Flow）
オブジェクト: Lead

─── スケジュール設定 ─────────────────────────────────
実行頻度: 毎日
実行時刻: 00:00（日本時間）

─── フィルター条件 ───────────────────────────────────
条件 1: Status ≠ 'NG' AND Status ≠ '商談'（未クローズのみ）
条件 2: LastApproachDate__c <= TODAY - [〇日] ← ⚠️ 要確認
条件 3: IsConverted = false

─── アクション ──────────────────────────────────────
レコード作成（Task）:
  Subject  : "【自動フォロー】最終アプローチから[〇日]経過: {!Lead.Name}"
  WhoId    : {!Lead.Id}
  OwnerId  : {!Lead.OwnerId}
  Priority : High
  Status   : Not Started
  DueDate  : {!$Flow.CurrentDate}（当日中に対応）
```

> ⚠️ **【先方確認待ち】** フォロー起動までの日数（〇日）は 2026-05-13 MTG で「佐藤さんが二川さんと決定中」となっており未確定。**数値が確定次第、フィルター条件 2 の `-[〇日]` の箇所に当てはめてデプロイすること。**

### 2.3 既存顧客の定期フォロー（3ヶ月/6ヶ月/12ヶ月）

先方要望にある「購入から3ヶ月/6ヶ月/12ヶ月後のフォロー」は Opportunity または Account を対象とする別 Flow で実装する。

| 基準 | 起点フィールド | 対象 | アクション |
|---|---|---|---|
| 購入 3ヶ月後 | `Opportunity.CloseDate` + 90日 | Opportunity（Won） | 「3ヶ月フォロー」Task 作成 |
| 購入 6ヶ月後 | `Opportunity.CloseDate` + 180日 | Opportunity（Won） | 「6ヶ月フォロー」Task 作成 |
| 購入 12ヶ月後 | `Opportunity.CloseDate` + 365日 | Opportunity（Won） | 「12ヶ月フォロー / 更新案内」Task 作成 |

これらも同様の Scheduled Flow として実装可能。基準日・通知メッセージの文言は先方と確認後に確定する。

### 2.4 既存 Flow との共存マップ

```
【既実装・維持】
Lead_Reminder_Task         … SubStatus/Status が変わったとき即時にリマインドタスクを作成
Lead_To_Opportunity_Reminder … Status=商談 になったとき変換タスクを作成

【新規追加予定】
Lead_Auto_FollowUp_Scheduled … 最終アプローチから〇日後に自動でフォローアップタスクを作成
Opp_Periodic_FollowUp_Scheduled … 受注から3/6/12ヶ月後に定期フォロータスクを作成
```

---

## 3. Google カレンダー予定/タスクの SF 取り込み方針

### 3.1 標準機能：Einstein Activity Capture（EAC）

Salesforce には Google Calendar / Gmail と自動同期する **Einstein Activity Capture（EAC）** 機能がある。

| 機能 | 内容 |
|---|---|
| Googleカレンダー → SF | 予定（Event）を SF 活動として自動同期 |
| SF → Googleカレンダー | SF で作成した行動を Google に自動反映 |
| Gmail → SF | メールを SF レコードに関連付けて保存 |

#### ライセンス要件（⚠️ 要確認）

| エディション | EAC 利用可否 |
|---|---|
| Essentials | ✅ 含む |
| Professional | ✅ 含む |
| Enterprise | ✅ 含む |
| Unlimited | ✅ 含む |
| Developer（現デモ環境） | ⚠️ 限定的（本番ライセンス確認が必要） |

> 🔴 **先方確認事項**: 本番 Salesforce 組織のエディションと EAC が有効化されているかを確認する。

#### EAC の制限事項

| # | 制限 |
|---|---|
| 1 | 「SF 活動」としてログは残るが、SF の「タスク」オブジェクトとは別管理（Activity Timeline に表示） |
| 2 | Google Workspace アカウントが必要（個人 Gmail 不可） |
| 3 | データ保持期間に制限あり（24ヶ月） |
| 4 | EAC で同期された活動にはカスタム項目が付与できない |

### 3.2 EAC 以外の選択肢

| 方法 | 概要 | 推奨度 |
|---|---|:---:|
| **EAC**（推奨） | 設定のみ・コード不要 | ◎ |
| Zapier（Google Calendar → SF） | ノーコードで Event を SF に連携 | ○（EAC が使えない場合の代替） |
| Apex + Google Calendar API | フル カスタム連携 | △（開発工数大・保守コスト高） |
| 手動入力（現状維持） | SF の行動（Event）に手動登録 | △（運用コスト高） |

### 3.3 本プロジェクトの方向性

**現時点の推奨**：**EAC のライセンス確認 → 有効であれば即日設定**

```
確認フロー:
  1. 先方組織の Salesforce エディション確認
       Setup → Company Information → Salesforce Edition
  2. EAC 有効化確認
       Setup → Einstein Activity Capture → Settings
  3. Google Workspace アカウントとの接続設定
  4. 同期対象ユーザー（若槻さん・二川さん）を設定
```

EAC が使えない場合は Zapier（Google Calendar → SF Event 作成）を次善策として採用する。

---

## 4. まとめ：今後の実装優先順位

```
フェーズ確率%の更新（PR#8）  →  Scheduled Flow 実装  →  EAC 設定
     ↑先方確認次第即着手可             ↑先方確認待ち（日数未定）    ↑ライセンス確認後
```

---

## 5. 未着手タスクリスト（ネクストアクション）

### 🔴 高優先度（先方確認取れ次第即着手）

| # | タスク | 担当 | ブロッカー |
|---|---|---|---|
| T6-1 | **OpportunityStage に未追加フェーズ 6 値を追加してデプロイ（PR#8）** | 開発 | §1.3 の値を確定 → `OpportunityStage.standardValueSet-meta.xml` 修正 |
| T6-2 | **BusinessProcess XML への追記**（各 RT のフェーズ範囲を更新） | 開発 | T6-1 完了後 |
| T6-3 | **「アプローチ」→「アプローチ中」のラベル統一方針確認** | 先方確認 | 既存データへの影響調査が必要 |

### 🟡 中優先度（日数確定後に着手）

| # | タスク | 担当 | ブロッカー |
|---|---|---|---|
| T6-4 | **`Lead_Auto_FollowUp_Scheduled` Flow の実装** | 開発 | フォロー起動日数（〇日）の先方確認 |
| T6-5 | **`Opp_Periodic_FollowUp_Scheduled` Flow の実装**（3/6/12ヶ月） | 開発 | 基準日・通知文言の先方確認 |
| T6-6 | **EAC（Einstein Activity Capture）の有効化・設定** | 開発 + 先方 | 組織エディションのライセンス確認 |

### 🟢 低優先度（将来対応）

| # | タスク | 備考 |
|---|---|---|
| T6-7 | EAC が使えない場合の Zapier 連携設定 | T6-6 の結果次第 |
| T6-8 | Scheduled Flow のメール通知オプション追加（担当者にサマリーメール） | T6-4/T6-5 完了後に拡張 |

---

## 6. 先方確認事項まとめ

| # | 確認内容 | 確認先 | ブロック対象 |
|---|---|---|---|
| ① | 自動フォロートリガーの日数（最終アプローチから何日？） | 佐藤さん・二川さん | T6-4 |
| ② | 「アプローチ」→「アプローチ中」のリネームで既存データに問題ないか | Minerva 担当者 | T6-1, T6-3 |
| ③ | 購入後の定期フォロー（3/6/12ヶ月）の通知文言・担当者 | 佐藤さん | T6-5 |
| ④ | 本番 SF 組織のエディションと EAC 有効状態 | Minerva 管理者 | T6-6 |
| ⑤ | Google Workspace アカウントの使用有無 | Minerva 担当者 | T6-6 |

---

*このドキュメントは Minerva Demo プロジェクトの方針策定資料です。*  
*各タスクは上記先方確認事項が解消された順に着手してください。*
