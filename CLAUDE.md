# Minerva Demo - CLAUDE.md

## プロジェクト概要

サロン向けB2B商材を販売するMinerva様向けのSalesforce CRM実装プロジェクト。
HTMLデモ（`demo/`）とSalesforceメタデータ（`sf-src/`）の2軸で管理。

## Salesforce 組織情報

- **org alias**: `minerva-demo`
- **username**: `bizdev+mv@glue-inc.jp`
- **API バージョン**: 66.0

## よく使うコマンド

```bash
# デプロイ（sf-src ディレクトリから実行）
cd sf-src
sf project deploy start --metadata "FlexiPage:Custom_Opportunity_Page" -o minerva-demo
sf project deploy start --metadata "Flow:Flow名" -o minerva-demo
sf project deploy start --metadata "Profile:Admin" -o minerva-demo

# 取得
sf project retrieve start --metadata "FlexiPage:Custom_Opportunity_Page" -o minerva-demo
sf project retrieve start --metadata "Layout:Opportunity-Opportunity Layout" -o minerva-demo

# SOQL
sf data query --query "SELECT Id, Name FROM Lead LIMIT 5" -o minerva-demo
sf data query --query "SELECT Id, DeveloperName FROM FlowDefinition WHERE ..." -o minerva-demo --use-tooling-api
```

## ディレクトリ構成

```
minerva-demo/
├── demo/               # HTMLデモ（参考用・更新不要）
│   ├── index.html
│   ├── leads.html
│   ├── opportunity.html
│   ├── contracts.html
│   └── data.js
└── sf-src/             # Salesforceメタデータ（実装の本体）
    └── force-app/main/default/
        ├── flows/          # 自動化Flow
        ├── objects/        # カスタム項目・カスタムオブジェクト
        │   ├── Lead/fields/
        │   ├── Opportunity/fields/
        │   ├── Account/fields/
        │   ├── Brand__c/               # ブランドマスタ
        │   ├── Sales_Transaction__c/   # 売上トランザクション（Shopify等連携想定）
        │   ├── Sales_Transaction_Item__c/ # 売上明細
        │   └── Appointment__c/         # アポイント
        ├── flexipages/     # Lightningページ（画面レイアウト）
        ├── layouts/        # ページレイアウト（FlexiPageに上書きされるため参考程度）
        ├── profiles/       # Admin プロファイル（ModifyAllDataのためFLS設定不要）
        ├── quickActions/   # クイックアクション
        └── standardValueSets/ # 選択リスト値
```

## 実装済みカスタム項目

### Lead（リード）
| 項目API名 | ラベル | 種類 |
|---|---|---|
| SubStatus__c | サブステータス | 選択リスト |
| ApproachMethod__c | アプローチ方法 | 選択リスト |
| LastApproachDate__c | 最終アプローチ日 | 日付 |
| LastApproachMethod__c | 最終アプローチ手法 | テキスト |
| LastApproachBy__c | 最終アプローチ担当者 | 参照(User) |
| Brand__c | ブランド | 参照(Brand__c) |

### Opportunity（商談）
| 項目API名 | ラベル | 種類 |
|---|---|---|
| IS_Owner__c | IS担当者（商談獲得者） | 参照(User) |
| MeetingDateTime__c | 商談獲得日時 | 日時 |
| LastApproachDate__c | 最終アプローチ日 | 日付 |
| LastApproachMethod__c | 最終アプローチ手法 | テキスト |
| LastApproachBy__c | 最終アプローチ担当者 | 参照(User) |
| NextMeetingDate__c | 次回ミーティング予定日 | 日時 |
| NextActionDate__c | 次回アクション日時 | 日時 |
| NextActionMethod__c | 次回アクション手法 | 選択リスト（電話/メール/LINE/SMS/DM） |
| AccountDivision__c | 法人区分 | 選択リスト（国内/韓国）※デフォルト:国内 |
| CurrencyType__c | 通貨 | 選択リスト（JPY/KRW）※デフォルト:JPY |
| ExchangeRate__c | 為替レート | 数値（精度16, 小数2） |
| JPYAmount__c | 円換算金額 | 数式（金額×為替レート） |
| Brand__c | ブランド | 参照(Brand__c) |

### Account（取引先）
| 項目API名 | ラベル | 種類 |
|---|---|---|
| CSStatus__c | CSステータス | 選択リスト |
| CSOwner__c | CS担当者 | 参照(User) |
| LastCSContactDate__c | 最終CS連絡日 | 日付 |
| ContractRenewalDate__c | 契約更新日 | 日付 |
| Brand__c | ブランド | 参照(Brand__c) |

## 実装済みFlow一覧

| Flow名 | トリガー | 処理 |
|---|---|---|
| Task_Update_Lead_Approach | タスク保存（WhoId=リード） | リードのLastApproach*を自動更新 |
| Task_Update_Opportunity_Approach | タスク保存（WhatId=商談） | 商談のLastApproach*を自動更新 |
| Lead_Auto_Create_Opportunity | リードStatus→「商談」 | 商談レコードを自動作成 |
| Event_Update_Opportunity_NextMeeting | 行動保存（WhatId=商談） | NextMeetingDate__cを自動更新 |
| Event_Auto_Set_EndDateTime | 行動保存（Before Save） | 行動の終了日時を自動設定 |
| Lead_Reminder_Task | （別途確認） | リマインドタスク作成 |
| Lead_To_Opportunity_Reminder | （別途確認） | 商談変換リマインド |
| Opportunity_Contract_Task | （別途確認） | 契約成立タスク作成 |

## クイックアクション一覧

| QuickAction名 | 対象 | 処理 |
|---|---|---|
| NewTask | グローバル | タスク新規作成 |
| NewEvent | グローバル | 行動新規作成（Subject/StartDateTime必須） |
| Opportunity.NewEvent | 商談オブジェクト | 商談から行動を新規作成（WhatId=商談に自動セット） |

## Lightningページ構成

各オブジェクトはカスタムFlexiPageを使用（ページレイアウトより優先）。
**FlexiPageを編集しないと画面に反映されない。**

| FlexiPage名 | 対象オブジェクト | 備考 |
|---|---|---|
| Lead_Record_Page_Three_Column | Lead | |
| Custom_Opportunity_Page | Opportunity | |
| Custom_Account_Page | Account | 関連タブに `force:relatedListContainer` 追加済み（子取引先等を表示） |

## カスタムオブジェクト一覧

| オブジェクト | ラベル | 用途 |
|---|---|---|
| Brand__c | ブランド | ブランドマスタ（BrandCode__c） |
| Sales_Transaction__c | 売上トランザクション | Shopify等からの売上データ連携想定（AutoNumber: TRX-{00000000}） |
| Sales_Transaction_Item__c | 売上明細 | 売上トランザクションの明細行 |
| Appointment__c | Appointment | アポイント管理（AutoNumber: APT-{00000000}） |

## 標準選択リスト

### リードステータス（LeadStatus）
未コンタクト → アプローチ中 → 見込み → 商談（IsConverted=true） → NG

### 商談フェーズ（OpportunityStage）
商談設定済み → 商談実施済み／見込み → 商談実施済み／ナーチャリング → 契約（Won） → NG（Lost）

### AccountType（取引先種別）
標準値（Analyst/Competitor/Customer 等）＋ **問屋**（2026-05-11追加）

### LeadSource（リードソース）
標準値（Website/Trade Show 等）＋ **LP資料請求**（LP Resource Request、2026-05-12追加）

## Web-to-Lead 設定

- **フォームHTML**: `docs/web-to-lead/lemella-lp-form.html`
- **LeadSource**: `LP Resource Request`（表示ラベル: LP資料請求）
- **登録項目**: お名前(last_name) / サロン名・会社名(company) / メール(email) / 電話(phone)
- **事前作業（SF UI）**: Setup → 機能設定 → マーケティング → Web-to-Lead → 有効化 が必要
- **retURL**: `https://lemellajapan.com/lp-salon/contact/?thanks=1`（送信後ページは要変更）

## 確定した運用方針（変更不可・ベースライン）

| 方針 | 内容 | 確定日 |
|---|---|---|
| 名寄せキー | メールアドレスをユニークキーとして採用 | 2026-05-13 MTG |
| データ連携方式 | Google拡張機能でスプシ→SF連携（SF IDで更新/新規を自動判定） | 2026-05-13 MTG |
| シート分割 | リード用シートと商談用シートは別々に運用 | 2026-05-13 MTG |
| 商談と導入の管理 | 商談の受注と実際の導入（製品購入）を**切り離して**管理 | 2026-05-13 MTG |
| 導入済みブランド管理 | 取引先（Account）にチェック項目として管理（Shopify購入は商談と別管理） | 2026-05-13 MTG |
| 韓国法人売上 | **スコープ外（不要）** ← 先方確認済み | 2026-05-15 確定 |
| 進め方 | 定例MTGなし・Slackベースでの確認・相談を基本とする | 2026-05-13 MTG |
| フォロー対象 | 電話繋がらなかった人・見込みの人 → 具体的な日数は佐藤さんが二川さんと決定中 | 2026-05-13 MTG |

## 取り扱い商品・ブランド一覧（CSVデータより確認）

新規会員登録CSVの「検討中の商品」カラムから確認できたブランド/商品名：

| 商品名 | 備考 |
|---|---|
| LHALA PEEL（ララピール） | LHALAブランド主力商品 |
| メジ（脂肪溶解剤） | |
| ソフトピール | |
| DUAL MIX | |
| FuLALA（フラーラ） | |
| soyonシリーズ | |
| ボディスリムクリーム | |
| LEMELLA（カメラ） | LEMELLAブランド主力商品 |

## データ連携設計（スプシ構造・CSVカラム）

### Salesforce連携用スプシの構造（確定）

| フェーズ | 構造 |
|---|---|
| 現状 | リード → 取引先 → 商談 |
| 今後（ブランド別） | 取引先 → 商談(Minerva：新規会員登録済み) / 商談(LHALA) / 商談(LEMELLA) |

### エルメッセージ 新規会員登録フォーム CSVカラム構成

| CSVカラム名 | Salesforce項目マッピング候補 | 備考 |
|---|---|---|
| LINE ユーザーID | 外部ID候補 | 重複判定に使用可 |
| 回答日時 | Lead.CreatedDate 相当 | |
| LINE名 | — | 表示名のみ・正式名でない場合あり |
| 会社名 | Lead.Company | |
| 代表者名 | Lead.LastName | |
| 代表者名（カナ） | カスタム項目候補 | |
| サロン・クリニック名 | Lead.Company or カスタム項目 | 会社名と別途管理要否を確認 |
| 担当者名 | Lead.FirstName | |
| 担当者名（カナ） | カスタム項目候補 | |
| 店舗形態 | Lead.Industry 相当 | フェイシャルサロン/ネイルサロン等 |
| 住所 | Lead.Address | 郵便番号-都道府県-市区町村-番地の形式 |
| メールアドレス | Lead.Email | **名寄せキー（ユニーク）** |
| 電話番号 | Lead.Phone | |
| 検討中の商品（複数可） | Lead.Description or カスタム項目 | カンマ区切りで複数入力あり |

> **注意**: データ件数100件超（2025/10〜2026/05）。同一メールで複数回答あり（重複除去が必要）。

## 次回実装タスク（着手可能・優先順）

| PR | 内容 | ステータス |
|---|---|---|
| PR#7 | Lead に Rank__c（A/B/C 選択リスト）追加 + FLS + FlexiPage | 着手可 |
| PR#8 | OpportunityStage 確率（%）調整（現: 30/60/20/100/0%） | 先方確認待ち（値確定後即着手） |
| PR#9 | LeadSource 選択肢追加（流入経路パターン対応） | 先方確認後着手 |
| UI作業 | Web-to-Lead 有効化（SF Setup → 機能設定 → マーケティング） | 着手可（UI操作のみ） |

### PR#7 Rank__c 仕様（確定）
- **項目API名**: `Rank__c`、型: 選択リスト、対象: Lead
- **選択肢**:
  - A：積極的に質問・話を聞いてくれた人（展示会等での最優先フォロー対象）
  - B：インスタフォロー＋名刺交換できたが反応薄い
  - C：名刺だけ交換できた
- **根拠**: 2026-05-13 MTG + 韓国展示会フローPDF（先方回答: リードに追加する前提）

## 先方確認待ち（ブロッカー）

| # | 確認内容 | ブロックされる作業 |
|---|---|---|
| ① | アプローチリスト表示条件（最終アプローチ日から何日）← 佐藤さんが二川さんと決定中 | ListView実装・Flowリマインド |
| ② | アプローチリスト除外条件（NGのサブステータス詳細） | 同上 |
| ③ | 商談フェーズ確率（%）の具体値 | PR#8確定値 |
| ⑤ | Flownee の BrandCode__c 登録値 | Brand__cマスタ登録 |
| ⑥ | Web-to-Lead retURL（サンクスページURL） | フォーム本番設置 |
| ⑦ | メールアドレス未登録者（約43件）の補完 | データ整備 |
| ⑧ | **ブランド別商談管理デモ** の妥当性確認 → デモ送付済み（2026-05-15時点） | 新方式採用可否の判断 |

> ✅ ④ 韓国法人売上：**スコープ外（不要）** として確定（2026-05-15）

## 設計未確定（次回MTGで判断）

| 論点 | 選択肢 | 影響範囲 |
|---|---|---|
| **ブランド別商談管理（新方式）採用可否** | リード廃止＋商談RTモデル vs 現行継続 | 全オブジェクト設計に影響（最大） |
| 活動メモの残し方 | Task/Event vs リード項目（長文） | Lead画面設計・運用フロー |
| インスタキャンペーン（顧客タグ付け） | Campaign機能でタグ付け → 登録単位・抽出導線を確定 | Campaign/CampaignMember実装 |
| 取引先の漢字名表示・進捗状況 | 項目の正本定義＋ステータス選択肢 | Account FlexiPage |
| 資料請求（Lara/Minerva/LHALA）→SF直連携 | Web-to-Lead横展開 vs Element→スプシ経由 | 各ブランドの流入フロー |
| 資料請求→Slack通知 | 通知先チャンネル＋通知条件 | Flow or 外部連携 |

- **デモURL（新方式たたき台）**: https://skurashima-cyber.github.io/minerva-demo-v2/demo-v2/index.html
  - 送付済み（2026-05-15）、先方確認中

## 作業ログ

### 2026-05-15（仕様すり合わせ・コード実装なし）

#### 実施内容
- Notion要件ページ・PDF（韓国展示会流れ/シルクスキンピール企画流れ/流入経路パターン）を元に現状実装と要件のすり合わせを実施
- 実装済み項目・未実装項目・先方確認待ち・設計未確定の4軸で整理

#### 確認事項
- ブランド別商談管理デモが先方（佐藤さん）に送付済み・確認待ちであることを確認
- Rank__c（A/B/C）の意味をPDFで確定（A=積極的/B=反応薄い/C=名刺のみ）
- GitHubへの直接操作権限（gh CLI認証済み、repoスコープ）を確認

#### 次回セッション最優先タスク
1. PR#7：Lead に Rank__c 追加（dry-run → commit → PR作成）
2. Web-to-Lead 有効化（SF UI操作）
3. 先方回答待ち項目③（商談フェーズ確率%）の回答があり次第 PR#8 着手

### 2026-05-15 セッション②（Notion確認中・完了事項まとめ の統合）

#### 確定した新情報
- **韓国法人売上：スコープ外（不要）** として先方確認済み → 先方確認待ちリストから削除、ExchangeRate__c/CurrencyType__c等は現状維持
- **フォロー対象条件**：電話繋がらなかった人・見込みの人が対象（具体的な日数は佐藤さんが二川さんと決定中）
- **インスタ投稿キャンペーン（新施策）**：インスタ投稿した顧客にタグ付け → Campaign機能で対応予定、詳細は佐藤さんがSlack共有予定
- **Shopify購入データ**：スプシ経由でSalesforce連携・商談とは別管理

#### 実装完了の再確認
- ✅ AccountType「問屋」追加、FlexiPage関連リスト整備、Flow 8本有効化、FLS問題なし（現状ユーザー全員Admin）
- ✅ Lead_Auto_Create_Opportunity の安全性確認（べき等性あり、NG→商談反転時の2件目作成リスクは仕様制限として記録済み）
- ✅ Web-to-Lead 準備完了（有効化のUI操作のみ残り）、経営ダッシュボード叩き台作成済み

#### 残タスク（変更なし）
- PR#7（Rank__c）、PR#8（確率調整）、Web-to-Lead有効化が最優先

## 注意事項

- **FLS**: CLIでデプロイしたカスタム項目はFLSが自動付与されない。`profiles/Admin.profile-meta.xml` に `fieldPermissions` を追加してデプロイすること
- **Flow有効化**: 新規Flowをデプロイ後、自動有効化されない場合がある。Flow Builder UIで手動有効化が必要な場合あり
- **FlexiPage vs レイアウト**: 商談・取引先はカスタムFlexiPageが適用されており、ページレイアウトの変更は画面に反映されない。FlexiPageを編集すること
- **デモHTMLは更新不要**: `demo/` 配下のHTMLファイルは参考用。Salesforce実装のみ行う
