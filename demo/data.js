const initialData = {
  accounts: [
    { id: 'ACC-001', name: '株式会社テックアルファ', industry: 'IT', phone: '03-1234-5678' },
    { id: 'ACC-002', name: '株式会社ビジネスベータ', industry: '製造', phone: '06-9876-5432' }
  ],
  opportunities: [
    {
      id: 'OPP-001', accountId: 'ACC-001', name: 'システム導入提案',
      stage: 'アプローチ中', amount: 3000000,
      callStatus: '未架電', nextActionNote: '初回架電', nextActionAt: '2026-04-21T10:00',
      lastContactedAt: null, closeDate: '2026-06-30'
    },
    {
      id: 'OPP-002', accountId: 'ACC-001', name: '追加ライセンス拡張',
      stage: '商談中', amount: 800000,
      callStatus: '通電済', nextActionNote: '資料送付後フォロー', nextActionAt: '2026-04-22T14:00',
      lastContactedAt: '2026-04-18T11:30', closeDate: '2026-05-31'
    },
    {
      id: 'OPP-003', accountId: 'ACC-002', name: 'CRM導入支援',
      stage: 'アプローチ中', amount: 5000000,
      callStatus: '不通', nextActionNote: '再架電', nextActionAt: '2026-04-21T15:00',
      lastContactedAt: '2026-04-19T09:00', closeDate: '2026-07-31'
    }
  ],
  cases: [
    {
      id: 'CASE-001', accountId: 'ACC-001', subject: '操作方法の問い合わせ',
      status: 'オープン', priority: '中', description: 'ダッシュボードの表示が崩れる',
      createdAt: '2026-04-15T10:00'
    },
    {
      id: 'CASE-002', accountId: 'ACC-002', subject: 'データ移行設定依頼',
      status: '対応中', priority: '高', description: '旧システムからのデータ移行を依頼',
      createdAt: '2026-04-17T14:30'
    }
  ],
  activities: []
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
