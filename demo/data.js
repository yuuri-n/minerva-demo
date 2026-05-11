const initialData = {
  accounts: [
    { id: 'ACC-001', name: 'リラクゼーションサロン クレア', industry: '美容・リラクゼーション', phone: '03-1234-5678' },
    { id: 'ACC-002', name: 'エステサロン ラ・ルーチェ', industry: '美容・エステ', phone: '06-9876-5432' }
  ],
  opportunities: [
    {
      id: 'OPP-001', accountId: 'ACC-001', name: 'ララピール 導入提案',
      stage: 'アプローチ中', amount: 150000,
      callStatus: '未架電', nextActionNote: '初回架電', nextActionAt: '2026-04-25T10:00',
      lastContactedAt: null, closeDate: '2026-06-30',
      keyword: 'ララピール 導入',
      inquiryNote: '新規メニューとしてララピールを導入したい。条件（価格/ロット/講習）を知りたい'
    },
    {
      id: 'OPP-002', accountId: 'ACC-001', name: 'レモンボトル 正規導入支援',
      stage: '商談中', amount: 280000,
      callStatus: '通電済', nextActionNote: '資料送付後フォロー', nextActionAt: '2026-04-26T14:00',
      lastContactedAt: '2026-04-22T11:30', closeDate: '2026-05-31',
      keyword: 'レモンボトル 正規導入',
      inquiryNote: 'レモンボトルの正規導入を検討中。施術提供までの流れ（講習/同意書/注意事項）を確認したい'
    },
    {
      id: 'OPP-003', accountId: 'ACC-002', name: '美容商材 卸・仕入れ提案',
      stage: 'アプローチ中', amount: 500000,
      callStatus: '不通', nextActionNote: '再架電', nextActionAt: '2026-04-25T15:00',
      lastContactedAt: '2026-04-23T09:00', closeDate: '2026-07-31',
      keyword: '美容 商材 卸',
      inquiryNote: '既存メニューの差別化のため、卸で仕入れ可能な商材と"売れる提案資料/トーク"も欲しい'
    }
  ],
  cases: [
    {
      id: 'CASE-001', accountId: 'ACC-001', subject: 'ララピール 講習日程の問い合わせ',
      status: 'オープン', priority: '中', description: '初回講習の日程調整を希望。平日午後を希望しているが、オンライン対応可否も確認したい',
      createdAt: '2026-04-19T10:00'
    },
    {
      id: 'CASE-002', accountId: 'ACC-002', subject: '商材サンプル・トークスクリプト提供依頼',
      status: '対応中', priority: '高', description: 'エステ 商材 仕入れで問い合わせ。サンプル提供と"売れる提案トーク"資料の送付を要望',
      createdAt: '2026-04-21T14:30'
    }
  ],
  activities: [],
  contracts: [
    {
      id: 'CON-001', accountId: 'ACC-001',
      product: 'ララピール', keyword: 'ララピール 仕入れ',
      amount: 150000, contractDate: '2026-02-10',
      status: '運用中',
      lectureDate: '2026-02-20',
      firstOrderDate: '2026-03-01',
      nextFollowAt: '2026-05-01',
      note: 'メニュー化完了。月2〜3件施術中。次回フォローで追加ロット提案予定'
    },
    {
      id: 'CON-002', accountId: 'ACC-001',
      product: 'レモンボトル', keyword: 'レモンボトル 正規導入',
      amount: 280000, contractDate: '2026-04-20',
      status: '講習完了',
      lectureDate: '2026-04-23',
      firstOrderDate: null,
      nextFollowAt: '2026-05-10',
      note: '講習済み。初回注文はまだ。GW明けに連絡予定'
    },
    {
      id: 'CON-003', accountId: 'ACC-002',
      product: 'エステ商材セット（卸）', keyword: 'エステ 商材 仕入れ',
      amount: 200000, contractDate: '2026-04-05',
      status: 'フォロー要',
      lectureDate: null,
      firstOrderDate: null,
      nextFollowAt: '2026-04-25',
      note: '契約後、講習日程の連絡が取れていない。早急にフォロー必要'
    }
  ]
};

function getData() {
  const stored = localStorage.getItem('minerva_demo');
  return stored ? JSON.parse(stored) : JSON.parse(JSON.stringify(initialData));
}

function saveData(data) {
  localStorage.setItem('minerva_demo', JSON.stringify(data));
}

function resetData() {
  localStorage.removeItem('minerva_demo');
}

const callRules = {
  '不通':       { callStatus: '不通',        nextActionNote: '再架電',       stageAdvance: false },
  '通電':       { callStatus: '通電済',       nextActionNote: 'フォロー確認', stageAdvance: false },
  'いま忙しい': { callStatus: '折り返し待ち', nextActionNote: '再架電',       stageAdvance: false },
  '折り返し依頼': { callStatus: '折り返し待ち', nextActionNote: '折り返し確認', stageAdvance: false },
  'アポ獲得':   { callStatus: 'アポ確定',     nextActionNote: 'MTG準備',      stageAdvance: true  }
};

const stages = ['アプローチ中', '商談中', '提案中', 'クローズ'];

function applyCallResult(opportunityId, callResult, nextActionAt, memo) {
  const data = getData();
  const opp = data.opportunities.find(o => o.id === opportunityId);
  const rule = callRules[callResult];

  opp.callStatus = rule.callStatus;
  opp.nextActionNote = rule.nextActionNote;
  opp.nextActionAt = nextActionAt;
  opp.lastContactedAt = new Date().toISOString();

  if (rule.stageAdvance) {
    const idx = stages.indexOf(opp.stage);
    if (idx < stages.length - 1) opp.stage = stages[idx + 1];
  }

  data.activities.unshift({
    id: 'ACT-' + Date.now(),
    opportunityId,
    accountId: opp.accountId,
    callResult,
    nextActionAt,
    memo: memo || '',
    createdAt: new Date().toISOString()
  });

  saveData(data);
  return data;
}

function formatDate(isoString) {
  if (!isoString) return '—';
  const d = new Date(isoString);
  return `${d.getFullYear()}/${String(d.getMonth()+1).padStart(2,'0')}/${String(d.getDate()).padStart(2,'0')} ${String(d.getHours()).padStart(2,'0')}:${String(d.getMinutes()).padStart(2,'0')}`;
}

function formatDateOnly(isoString) {
  if (!isoString) return '—';
  const d = new Date(isoString);
  return `${d.getFullYear()}/${String(d.getMonth()+1).padStart(2,'0')}/${String(d.getDate()).padStart(2,'0')}`;
}

function getAccount(id) {
  return getData().accounts.find(a => a.id === id);
}

function getOpportunity(id) {
  return getData().opportunities.find(o => o.id === id);
}

function getActivitiesForOpportunity(oppId) {
  return getData().activities.filter(a => a.opportunityId === oppId);
}

function getCasesForAccount(accountId) {
  return getData().cases.filter(c => c.accountId === accountId);
}

function getOpportunitiesForAccount(accountId) {
  return getData().opportunities.filter(o => o.accountId === accountId);
}

function getContractsForAccount(accountId) {
  return (getData().contracts || []).filter(c => c.accountId === accountId);
}

function contractStatusColor(status) {
  const map = {
    '講習待ち': '#ff9e2c',
    '講習完了': '#0176d3',
    '運用中':   '#2e844a',
    'フォロー要': '#c23934'
  };
  return map[status] || '#888';
}

function stageColor(stage) {
  const map = {
    'アプローチ中': '#ff9e2c',
    '商談中': '#0176d3',
    '提案中': '#9050e9',
    'クローズ': '#2e844a'
  };
  return map[stage] || '#888';
}

function callStatusBadge(status) {
  const map = {
    '未架電': '#888',
    '不通': '#c23934',
    '通電済': '#2e844a',
    '折り返し待ち': '#ff9e2c',
    'アポ確定': '#0176d3'
  };
  return map[status] || '#888';
}
