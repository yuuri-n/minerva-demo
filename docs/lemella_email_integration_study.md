# ルメラ メール資料請求 → Salesforce 自動取り込み＋Slack 通知 設計書

> **対象プロジェクト**: Minerva Demo  
> **作成日**: 2026-06-03  
> **背景**: ルメラ（LEMELLA）システムは CSV 抽出不可のため、資料請求時に配信される受信メールをフックにして Salesforce への自動取り込みと Slack 通知を実現する方法を調査・検討する。

---

## 1. 前提・現状整理

### 1.1 既存の類似実装

| 実装 | ファイル | 概要 |
|---|---|---|
| Web-to-Lead フォーム | `docs/web-to-lead/lemella-lp-form.html` | LP からのフォーム送信で Lead を自動生成。LeadSource = `LP Resource Request` |
| 重複チェック LWC | `classes/AccountDedupController.cls` | メールアドレスキーで既存 Account を検索・警告するコントローラ |
| Lead → Opportunity 自動作成 Flow | `flows/Lead_Auto_Create_Opportunity.flow-meta.xml` | Lead.Status = 「商談」で Opportunity を自動生成 |
| Lead 移行バッチ | `classes/LeadMigrationBatch.cls` | 既存リードデータの一括移行ロジック |

### 1.2 本タスクで実現したいこと

```
ルメラシステム
  └─ 資料請求イベント
       └─ 通知メール配信（Minerva 担当者アドレス宛）
            │
            ▼
       Salesforce（メール受信）
            ├─ [新規]     メールアドレス未登録 → Lead を新規作成
            ├─ [掘り起こし] メールアドレス既存 → 既存 Lead/Contact を更新 + タスク作成
            │
            ▼
       Slack 通知「新規問い合わせが届きました」
```

---

## 2. Salesforce 取り込み手法の比較検討

### 手法① : Salesforce 標準「Email-to-Lead」（メール-to-リード）

#### 仕組み

```
受信メール → SF Email Services エンドポイント（@salesforce.com アドレス）
         → 標準ロジックで Lead 自動生成
```

Salesforce Setup > **機能設定 > メール > Email-to-Lead** から有効化するだけで利用可能。送信元のメールアドレス・件名・本文をそのまま Lead のフィールドにマッピングする。

#### メリット

| # | 内容 |
|---|---|
| ✅ 1 | コード不要・設定のみで即日稼働 |
| ✅ 2 | Salesforce 標準機能のため保守コストがほぼゼロ |
| ✅ 3 | メール本文を `Description` に自動格納するため後から確認しやすい |

#### デメリット

| # | 内容 |
|---|---|
| ❌ 1 | **重複判定が不可能**。既存 Lead が存在しても常に「新規 Lead を作成」する |
| ❌ 2 | メール本文のパース（氏名・会社名・電話番号の抽出）ができない |
| ❌ 3 | LeadSource や Brand__c などのカスタム項目を自動セットできない |
| ❌ 4 | 「掘り起こし」フローへの振り分けが実現できない |
| ❌ 5 | Slack 通知を直接トリガーするには別途 Flow が必要（それ自体は可能） |

#### 評価

> **新規/掘り起こしの自動判別は不可**。Lead の重複を許容するか、手動で後から名寄せする運用であれば成立するが、メールアドレスをユニークキーとする本プロジェクトの方針（2026-05-13 MTG 決定）と**根本的に矛盾する**。

---

### 手法② : Apex カスタム「InboundEmailHandler」（推奨）

#### 仕組み

```
受信メール → SF Email Services（@salesforce.com アドレス）
         → Apex InboundEmailHandler クラスが起動
         → メール本文を正規表現でパース
         → 既存 Lead を Email で SOQL 検索
              ├─ 未登録  → Lead.insert（新規作成）+ LeadSource セット
              └─ 登録済み → Lead.update（Status 更新）+ Task 作成
         → Flow を呼び出して Slack 通知
```

#### メリット

| # | 内容 |
|---|---|
| ✅ 1 | **メールアドレスで重複チェックし、新規/掘り起こしを自動判別**できる |
| ✅ 2 | メール本文を正規表現でパースし、氏名・会社名・電話番号を各 SF 項目にマッピングできる |
| ✅ 3 | LeadSource = `Lemella Resource Request`、Brand__c = LEMELLA 等を自動セットできる |
| ✅ 4 | 既存 `AccountDedupController` の重複チェックロジックを参考に実装できる |
| ✅ 5 | Lead 作成後に Flow を呼び出せるため、Slack 通知との連携が容易 |
| ✅ 6 | 複数ブランド（LHALA / LEMELLA 等）の通知メールも同一ハンドラで振り分け可能 |

#### デメリット

| # | 内容 |
|---|---|
| ❌ 1 | Apex コードの実装・テストクラス作成が必要（工数：2〜3 日） |
| ❌ 2 | ルメラ通知メールの本文フォーマットを事前に確認・確定させる必要がある |
| ❌ 3 | メールフォーマットが変更された場合に正規表現の修正が必要 |

---

### 2.3 比較サマリーと推奨手法

| 評価軸 | Email-to-Lead | **InboundEmailHandler** |
|---|:---:|:---:|
| 設定コスト | ◎ ゼロ | △ Apex 実装必要 |
| 新規/掘り起こし判別 | ✗ 不可 | ◎ Email で SOQL 判定 |
| フィールド自動マッピング | △ 限定的 | ◎ パース自由 |
| カスタム項目セット | ✗ 不可 | ◎ 全項目対応 |
| Slack 通知との連携 | △ Flow 別途 | ◎ Handler 内から呼出 |
| 保守コスト | ◎ 低 | △ コード管理が必要 |
| 本プロジェクト適合度 | ✗ **要件未達** | ✅ **要件を完全充足** |

> ### 🟢 推奨：**手法② Apex InboundEmailHandler**
>
> メールアドレスをユニークキーとする本プロジェクトの名寄せ方針（2026-05-13 MTG 決定事項）を実現するには、重複判定ロジックを実装できる InboundEmailHandler が唯一の選択肢。既存の `AccountDedupController.cls` で確立された重複チェックパターンを流用できるため、実装コストも限定的。

---

## 3. Apex InboundEmailHandler 実装イメージ

### 3.1 クラス構成（擬似コード）

```apex
// sf-src/force-app/main/default/classes/LemellaEmailHandler.cls
global class LemellaEmailHandler implements Messaging.InboundEmailHandler {

    global Messaging.InboundEmailResult handleInboundEmail(
        Messaging.InboundEmail email,
        Messaging.InboundEnvelope envelope
    ) {
        Messaging.InboundEmailResult result = new Messaging.InboundEmailResult();
        String body = email.plainTextBody ?? email.htmlBody;

        // 1. メール本文から各項目をパース
        String extractedEmail = extractField(body, 'メールアドレス');
        String extractedName  = extractField(body, 'お名前');
        String extractedPhone = extractField(body, '電話番号');
        String extractedCompany = extractField(body, '会社名');

        // 2. 既存 Lead を Email で検索（新規/掘り起こし判定）
        List<Lead> existing = [
            SELECT Id, Status, Email, LastName, Company
            FROM Lead
            WHERE Email = :extractedEmail
            AND IsConverted = false
            LIMIT 1
        ];

        if (existing.isEmpty()) {
            // ── 新規 ──────────────────────────────────────
            Lead newLead = new Lead(
                LastName    = extractedName,
                Company     = extractedCompany,
                Email       = extractedEmail,
                Phone       = extractedPhone,
                LeadSource  = 'Lemella Resource Request',
                Status      = '未コンタクト'
                // Brand__c   = [Brand__c から LEMELLA の ID を取得してセット]
            );
            insert newLead;
            notifySlack(newLead.Id, '新規', extractedName, extractedCompany);

        } else {
            // ── 掘り起こし ────────────────────────────────
            Lead existingLead = existing[0];
            Task followupTask = new Task(
                WhoId   = existingLead.Id,
                Subject = '[ルメラ] 資料請求あり（再問い合わせ）',
                Status  = 'Not Started',
                Priority = 'High'
            );
            insert followupTask;
            notifySlack(existingLead.Id, '掘り起こし', existingLead.LastName, existingLead.Company);
        }

        result.success = true;
        return result;
    }

    // Slack 通知は Flow 呼び出し or HTTP Callout で実装
    private void notifySlack(Id leadId, String type, String name, String company) {
        // → §4 参照
    }

    private String extractField(String body, String fieldName) {
        // 正規表現でフィールド名の後の値を抽出
        Pattern p = Pattern.compile(fieldName + '[：:　 ]*([^\\n]+)');
        Matcher m = p.matcher(body);
        return m.find() ? m.group(1).trim() : '';
    }
}
```

### 3.2 Email Services 設定手順

```
Salesforce Setup
  → 開発 → メールサービス（Email Services）
  → 新規作成
      - クラス名: LemellaEmailHandler
      - メールアドレス: lemella-inquiry@[orgid].salesforce.com（自動生成）
      - 有効なメール送信元: ルメラ通知元アドレス（要確認）

ルメラ通知設定
  → 資料請求受付時の通知先メールアドレスに上記 SF アドレスを追加/変更
```

### 3.3 事前確認が必要なルメラメール本文の形式

実装前に以下を確認する必要がある：

| 確認項目 | 内容 |
|---|---|
| 通知メールの差出人アドレス | SF Email Services の「有効送信元」フィルタに設定 |
| 本文フォーマット（HTML or テキスト） | パース方式（正規表現のパターン）が変わる |
| 含まれる項目名（お名前 / 氏名 など表記） | 正規表現のキーワード設定に影響 |
| 件名のパターン | 複数ブランド対応時の振り分けに使用 |

---

## 4. Slack 通知の実装方法と実現可能性

### 4.1 実装オプション比較

| # | 方法 | 難易度 | コスト | 推奨度 |
|---|---|:---:|:---:|:---:|
| A | **Flow + Slack Incoming Webhook（Named Credential）** | 中 | 無料 | ◎ |
| B | Flow + Salesforce 公式 Slack App（SF for Slack） | 低 | 要ライセンス確認 | △ |
| C | Apex から直接 HTTP Callout to Slack | 中 | 無料 | ○ |
| D | Zapier / Make 経由（SF Webhook → Slack） | 低 | 有料プランあり | △ |

### 4.2 推奨：オプション A「Flow + Named Credential + Slack Incoming Webhook」

Slack の **Incoming Webhook URL** を Named Credential として SF に登録し、Record-Triggered Flow（または InboundEmailHandler から呼び出す Invocable Flow）で HTTP POST を実行する方法。追加ライセンス不要でコスト最小。

#### 実装手順概要

```
【Slack 側の準備】
1. Slack App を作成（https://api.slack.com/apps）
2. Incoming Webhooks を有効化
3. 通知先チャンネルを選択して Webhook URL を取得
   例: https://hooks.slack.com/services/T.../B.../xxx

【Salesforce 側の設定】
1. Setup → セキュリティ → 名前付き認証情報（Named Credentials）
   → 新規作成
       - 名前: Slack_Minerva_Webhook
       - URL: https://hooks.slack.com/services/...（Webhook URL）
       - 認証プロトコル: No Authentication

2. Setup → リモートサイトの設定
   → https://hooks.slack.com を追加（HTTP Callout 許可）

3. Flow 作成（Record-Triggered または Invocable）
   → トリガー: Lead が作成されたとき（LeadSource = Lemella Resource Request）
   → アクション: HTTP Callout（POST）
       - Endpoint: {!$Credential.Slack_Minerva_Webhook}
       - Body: {"text": "🔔 新規資料請求\n名前: {!Lead.LastName}\n会社: {!Lead.Company}"}
```

#### Slack 通知メッセージ イメージ

```
🔔 【ルメラ】新規資料請求が届きました
───────────────────────────
種別  : 新規 / 掘り起こし
お名前: 田中 花子
会社名: 株式会社〇〇サロン
メール: tanaka@example.com
電話  : 090-0000-0000
SF URL: https://[org].lightning.force.com/lightning/r/Lead/[Id]/view
```

### 4.3 InboundEmailHandler からの呼び出し方法

```apex
// InboundEmailHandler 内から Flow を Invocable で呼び出す
private void notifySlack(Id leadId, String type, String name, String company) {
    Map<String, Object> params = new Map<String, Object>{
        'leadId'    => leadId,
        'notifType' => type,
        'name'      => name,
        'company'   => company
    };
    Flow.Interview.LeadSlackNotify interview = new Flow.Interview.LeadSlackNotify(params);
    interview.start();
}
```

または Apex から直接 HTTP Callout を行う場合：

```apex
@future(callout=true)
private static void callSlackWebhook(String message) {
    HttpRequest req = new HttpRequest();
    req.setEndpoint('callout:Slack_Minerva_Webhook');
    req.setMethod('POST');
    req.setHeader('Content-Type', 'application/json');
    req.setBody('{"text":"' + message + '"}');
    new Http().send(req);
}
```

> ⚠️ Apex の `handleInboundEmail` 内から直接 HTTP Callout を行うと制限違反（callout 不可コンテキスト）になるため、`@future(callout=true)` アノテーションが必須。

---

## 5. 全体アーキテクチャ図

```
┌─────────────────────────────────────────────────────┐
│                  ルメラ 資料請求フォーム              │
└────────────────────────┬────────────────────────────┘
                         │ 資料請求イベント
                         ▼
┌─────────────────────────────────────────────────────┐
│          ルメラシステム（通知メール送信）              │
│  宛先: lemella-inquiry@[orgid].salesforce.com        │
└────────────────────────┬────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────┐
│  Salesforce Email Services                          │
│  └─ LemellaEmailHandler.cls（Apex）                 │
│       ├─ メール本文パース（正規表現）                │
│       ├─ Email で Lead.Email を SOQL 検索           │
│       │     ├─ 未登録 → Lead 新規作成               │
│       │     └─ 登録済 → Task 作成（掘り起こし）     │
│       └─ @future で Slack Webhook 呼び出し          │
└────────────────────────┬────────────────────────────┘
                         │
           ┌─────────────┴──────────────┐
           ▼                            ▼
┌──────────────────┐         ┌──────────────────────┐
│   Lead レコード   │         │   Slack チャンネル    │
│  （新規/更新）    │         │  （即時通知）         │
└──────────────────┘         └──────────────────────┘
```

---

## 6. LeadSource への追加が必要な値

本実装にあわせて `LeadSource` 選択リストに以下を追加する：

| API 値 | 表示ラベル | 用途 |
|---|---|---|
| `Lemella Resource Request` | ルメラ資料請求 | ルメラメール経由の新規/掘り起こし Lead |

（関連ファイル: `sf-src/.../standardValueSets/LeadSource.standardValueSet-meta.xml`）

---

## 7. 未着手タスクリスト（ネクストアクション）

### 🔴 高優先度（実装開始前に必須）

| # | タスク | 担当 | 備考 |
|---|---|---|---|
| N-1 | **ルメラ通知メールの本文フォーマットを確認・入手** | 先方確認 | 正規表現パターン設計の前提。テスト用メール1通を転送してもらう |
| N-2 | **Slack 通知先チャンネル・Webhook URL の取得** | Minerva 担当者 | 通知先を若槻さん/二川さんのいるチャンネルに決定 |
| N-3 | **LeadSource に「ルメラ資料請求」を追加してデプロイ** | 開発 | `LeadSource.standardValueSet-meta.xml` 修正 → deploy |

### 🟡 中優先度（コア実装）

| # | タスク | 担当 | 備考 |
|---|---|---|---|
| N-4 | `LemellaEmailHandler.cls` の実装 | 開発 | §3.1 の疑似コードを元に実装。`LemellaEmailHandlerTest.cls` も同時作成（カバレッジ 75%以上必要） |
| N-5 | SF Named Credential（Slack Webhook）の設定 | 開発 | Setup UI 操作のみ。`Slack_Minerva_Webhook` として登録 |
| N-6 | `Lead_Slack_Notify` Flow の作成（またはApex @future実装） | 開発 | N-5 完了後に作成 |
| N-7 | Email Services エンドポイントの作成とルメラ通知先変更 | 開発 + 先方 | SF アドレスをルメラ側に設定してもらう |

### 🟢 低優先度（品質向上・運用整備）

| # | タスク | 備考 |
|---|---|---|
| N-8 | エラーハンドリング強化（メールパース失敗時の fallback Lead 作成） | パース失敗時も未加工データを Description に格納して Lead 作成 |
| N-9 | 複数ブランド対応（メール件名でブランドを判定し Brand__c を自動セット） | LHALA / LEMELLA / Minerva それぞれの通知メールフォーマットを確認後 |
| N-10 | 掘り起こし時の重複通知防止（一定期間内の同一 Email は通知スキップ） | N-4 実装時に同時対応可能 |
| N-11 | インテグレーションテスト（ルメラからの実際のメールでエンドツーエンド確認） | ステージング環境での動作確認 |

---

## 8. 先方確認事項まとめ

| # | 確認内容 | 確認先 | ブロック対象タスク |
|---|---|---|---|
| ① | ルメラ通知メールのサンプルを1通転送してもらえるか | Minerva 佐藤さん | N-1, N-4 |
| ② | Slack 通知先チャンネルはどこにするか（若槻/二川さんが見るチャンネル） | Minerva 佐藤さん | N-2, N-5 |
| ③ | ルメラ通知メールの送信元アドレスを教えてもらえるか | ルメラシステム管理者 | N-7 |
| ④ | ルメラ通知先メールアドレスの変更権限はどこにあるか | ルメラシステム管理者 | N-7 |

---

*このドキュメントは Minerva Demo プロジェクトの技術設計資料です。*  
*N-1（メール本文フォーマットの確認）が完了次第、N-4（Apex 実装）に着手できます。*
