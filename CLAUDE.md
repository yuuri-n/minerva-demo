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
        ├── objects/        # カスタム項目
        │   ├── Lead/fields/
        │   ├── Opportunity/fields/
        │   └── Account/fields/
        ├── flexipages/     # Lightningページ（画面レイアウト）
        ├── layouts/        # ページレイアウト（FlexiPageに上書きされるため参考程度）
        ├── profiles/       # Admin プロファイル（FLS管理）
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

### Account（取引先）
| 項目API名 | ラベル | 種類 |
|---|---|---|
| CSStatus__c | CSステータス | 選択リスト |
| CSOwner__c | CS担当者 | 参照(User) |
| LastCSContactDate__c | 最終CS連絡日 | 日付 |
| ContractRenewalDate__c | 契約更新日 | 日付 |

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

| FlexiPage名 | 対象オブジェクト |
|---|---|
| Lead_Record_Page_Three_Column | Lead |
| Custom_Opportunity_Page | Opportunity |
| Custom_Account_Page | Account |

## 標準選択リスト

### リードステータス（LeadStatus）
未コンタクト → 今いそ → アプローチ中 → 見込み → 商談（IsConverted=true） → NG

### 商談フェーズ（OpportunityStage）
商談設定済み → 商談実施済み／見込み → 商談実施済み／ナーチャリング → 契約（Won） → NG（Lost）

## 注意事項

- **FLS**: CLIでデプロイしたカスタム項目はFLSが自動付与されない。`profiles/Admin.profile-meta.xml` に `fieldPermissions` を追加してデプロイすること
- **Flow有効化**: 新規Flowをデプロイ後、自動有効化されない場合がある。Flow Builder UIで手動有効化が必要な場合あり
- **FlexiPage vs レイアウト**: 商談・取引先はカスタムFlexiPageが適用されており、ページレイアウトの変更は画面に反映されない。FlexiPageを編集すること
- **デモHTMLは更新不要**: `demo/` 配下のHTMLファイルは参考用。Salesforce実装のみ行う
