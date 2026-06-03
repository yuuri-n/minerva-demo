# LINE アンケート → Salesforce Lead マッピング設計書

> **対象プロジェクト**: Minerva Demo  
> **作成日**: 2026-06-03  
> **対象オブジェクト**: Lead（リード）  
> **データソース**: LINEアンケート（展示会・キャンペーン取得リード）

---

## 1. マッピング対応表

| # | LINEアンケート項目 | SF 項目ラベル | SF API 名 | 型 | 備考 |
|---|---|---|---|---|---|
| 1 | お名前（姓） | 姓 | `LastName` | テキスト（標準） | 名前が姓名一体の場合は全て LastName に格納し、FirstName は空欄 |
| 2 | お名前（名） | 名 | `FirstName` | テキスト（標準） | アンケートに姓名分離欄がある場合のみ入力 |
| 3 | 法人名・店舗名 | 会社名 | `Company` | テキスト（標準） | 必須項目。未入力の場合は「不明」等のデフォルト値を設定 |
| 4 | 連絡手段 | リードソース | `LeadSource` | 選択リスト（標準） | 固定値「LINE展示会」を設定。**未着手：LeadSource に値の追加が必要**（[§4 タスクリスト参照](#4-未着手タスクリスト)） |
| 5 | 業種 | 業種 | `Industry` | 選択リスト（標準） | Salesforce 標準選択肢との照合が必要。**先方に選択肢を確認の上マッピングを確定する**（[§3.1 注記参照](#31-業種-industry-の選択肢確認)） |
| 6 | 役職 | 役職 | `Title` | テキスト（標準） | 自由入力テキストとして格納 |
| 7 | 希望ブランド・情報 | ブランド | `Brand__c` | 参照（Lookup）→ `Brand__c` オブジェクト | **BrandCode__c ではなく参照型**。BrandCode__c = "FLOWNEE" / "LHALA" / "LEMELLA" 等のレコードを検索して ID をセット（[§3.2 注記参照](#32-希望ブランドのマッピング注意事項)） |
| 8 | 住所 | 住所（標準） | `Street` / `City` / `State` / `PostalCode` / `Country` | 住所複合型（標準） | 書式が「〒XXX-XXXX 都道府県 市区町村 番地」の場合は事前パースが必要（[§3.3 注記参照](#33-住所フィールドのパース)） |
| 9 | 電話番号 | 電話 | `Phone` | 電話型（標準） | ハイフン有無を統一して格納推奨 |
| *(追加)* | *(取り込み元の識別)* | リードソース補助 | `ApproachMethod__c` | 選択リスト（カスタム） | 「LINE」選択肢は既存値として登録済み。連絡手段の意味合いが「今後のアプローチ方法」なら本項目に入力 |
| *(追加)* | *(展示会ランク)* | ランク | `Rank__c` | 選択リスト（カスタム） | A〜D で手動入力。インポート時にアンケート回答から担当者が判断して入力 |

---

## 2. 全 Lead カスタム項目一覧（現在の実装状態）

> 本マッピングの前提として、Lead オブジェクトに実装済みのカスタム項目を整理する。

| API 名 | ラベル | 型 | 実装状態 |
|---|---|---|---|
| `Brand__c` | ブランド | Lookup → `Brand__c` | ✅ 実装済み |
| `ApproachMethod__c` | アプローチ方法 | 選択リスト（電話/メール/LINE/SMS/DM） | ✅ 実装済み |
| `SubStatus__c` | サブステータス | 選択リスト（Status 従属） | ✅ 実装済み |
| `Rank__c` | ランク | 選択リスト（A/B/C/D） | ✅ 実装済み（2026-06-03） |
| `LastApproachDate__c` | 最終アプローチ日 | 日付 | ✅ 実装済み |
| `LastApproachMethod__c` | 最終アプローチ手法 | テキスト | ✅ 実装済み |
| `LastApproachBy__c` | 最終アプローチ担当者 | Lookup → User | ✅ 実装済み |
| `MigrationDone__c` | 移行済みフラグ | （内部管理用） | ✅ 実装済み |

---

## 3. 補足注記

### 3.1 業種（Industry）の選択肢確認

Salesforce 標準の `Industry` 選択肢（例：Agriculture / Banking / Consulting 等）は英語であり、Minerva 様の業種分類（フェイシャルサロン / ネイルサロン / 美容クリニック 等）と一致しない可能性が高い。

**対応方針（要先方確認）：**
- 選択肢 A：`Industry` の標準値を日本語表示名にカスタマイズ
- 選択肢 B：`Industry` は使わず、テキスト型のカスタム項目 `SalonType__c`（仮）を新設
- 選択肢 C：`Description` に自由記述として格納（選択肢不要な場合）

> 🔴 **先方確認事項**：業種の選択肢一覧を共有してもらい、標準選択肢への流用可否を決定する。

### 3.2 希望ブランドのマッピング注意事項

**重要**：`Lead.Brand__c` は `BrandCode__c` 選択リストではなく、`Brand__c` カスタムオブジェクトへの **参照型（Lookup）** です。

```
Brand__c オブジェクト
  ├─ Name（ブランド名）：例「FLOWNEE」
  └─ BrandCode__c（テキスト50）：例「FLOWNEE」
```

データインポート時の流れ：
1. アンケートの「希望ブランド」欄の値（例：「FLOWNEE」「LHALA」「LEMELLA」）を取得
2. SOQL で `SELECT Id FROM Brand__c WHERE BrandCode__c = 'FLOWNEE'` を実行して ID を取得
3. 取得した ID を `Lead.Brand__c` にセット

**スプレッドシート連携の場合**：Google 拡張機能での取り込み時は `Brand__c` 列にブランドレコードの Salesforce ID を直接入力する運用にするか、事前にブランド名→ID の対照表を用意する。

| ブランド名（アンケート値） | BrandCode__c | SF ID（要確認） |
|---|---|---|
| FLOWNEE | FLOWNEE | 先方確認事項⑤ |
| LHALA | LHALA | 要登録 |
| LEMELLA | LEMELLA | 要登録 |
| Minerva | Minerva | 要登録 |

> 🔴 **先方確認事項**：BrandCode__c の登録値（FLOWNEE 以外）を確認する（CLAUDE.md 未解決事項⑤）。

### 3.3 住所フィールドのパース

LINEアンケートの住所が「〒150-0001 東京都渋谷区神宮前1-1-1」のような1行テキストの場合、Salesforce の住所型は複数フィールドに分割されているため、インポート前にパースが必要。

**推奨分割方針：**
| SF 項目 | 入力値の例 |
|---|---|
| `PostalCode` | `150-0001` |
| `State` | `東京都` |
| `City` | `渋谷区` |
| `Street` | `神宮前1-1-1` |
| `Country` | `日本`（固定値） |

スプレッドシートでのインポートであれば、列を事前に分割して対応する。

---

## 4. 未着手タスクリスト

以下は本マッピングを実際に運用するために必要な開発・設定作業の一覧です。

### 🔴 高優先度（インポート前に必須）

| # | タスク | 対象ファイル / 場所 | 作業内容 |
|---|---|---|---|
| T-1 | `LeadSource` に「LINE展示会」を追加 | `sf-src/.../standardValueSets/LeadSource.standardValueSet-meta.xml` | `<standardValue>` ブロックを追加して `sf project deploy` |
| T-2 | Brand__c レコードの登録確認・追加 | Salesforce UI（データ操作） | LHALA / LEMELLA / Minerva / FLOWNEE の Brand__c レコードが org に存在するか確認し、BrandCode__c を登録 |
| T-3 | 業種（Industry）選択肢の方針確定 | 先方確認 → メタデータ修正 | [§3.1](#31-業種-industry-の選択肢確認) の選択肢 A/B/C を先方と決定後、対応するメタデータ変更を実施 |

### 🟡 中優先度（運用品質向上）

| # | タスク | 対象ファイル / 場所 | 作業内容 |
|---|---|---|---|
| T-4 | インポート用スプレッドシートテンプレートの作成 | `docs/` フォルダ | LINEアンケート列名 → SF API 名の変換ヘッダーを持つ CSV テンプレートを作成 |
| T-5 | 氏名カナ項目の追加検討 | `sf-src/.../objects/Lead/fields/` | アンケートに「担当者名（カナ）」がある場合、`LastNameKana__c` 等のカスタム項目を追加する |
| T-6 | LINE ユーザーID の保存検討 | `sf-src/.../objects/Lead/fields/` | 重複判定・LINE 再送信に使う場合は外部 ID フィールド `LINEUserId__c`（テキスト・外部ID）を追加 |
| T-7 | `Lead.Brand__c` → Brand レコード ID の自動解決 Flow | Flow Builder | インポート後に BrandCode__c テキストから Lookup ID を自動セットする Flow を作成（手動入力をなくす） |

### 🟢 低優先度（将来対応）

| # | タスク | 作業内容 |
|---|---|---|
| T-8 | Campaign との紐づけ自動化 | LINE展示会 Campaign レコード作成後、Lead インポート時に CampaignMember も自動作成する Flow を実装 |
| T-9 | 住所パース自動化 | 1行住所テキストを郵便番号・都道府県・市区町村・番地に自動分割する Flow または Apex を実装 |

---

## 5. 参考：現在の LeadSource 登録済み選択肢

| API 値 | 表示ラベル | 備考 |
|---|---|---|
| `Advertisement` | Advertisement | SF 標準 |
| `Customer Event` | Customer Event | SF 標準 |
| `Employee Referral` | Employee Referral | SF 標準 |
| `External Referral` | External Referral | SF 標準 |
| `Google AdWords` | Google AdWords | SF 標準 |
| `Other` | Other | SF 標準 |
| `Partner` | Partner | SF 標準 |
| `Purchased List` | Purchased List | SF 標準 |
| `Trade Show` | Trade Show | SF 標準（展示会として代用可能） |
| `Webinar` | Webinar | SF 標準 |
| `Website` | Website | SF 標準 |
| `LP Resource Request` | LP資料請求 | ✅ カスタム追加済み（2026-05-12） |
| `LINE Exhibition` | LINE展示会 | ❌ **未追加（T-1 で対応）** |

---

*このドキュメントは Minerva Demo プロジェクトの設計資料です。*  
*メタデータ実装前に先方確認事項（T-1〜T-3）を解消してから着手してください。*
