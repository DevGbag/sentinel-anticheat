(function () {
  const resourceName = window.GetParentResourceName ? GetParentResourceName() : 'sentinel_ac';

  function fetchNui(name, data) {
    return fetch(`https://${resourceName}/${name}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data || {}),
    }).catch(() => {});
  }

  const state = {
    selfId: null,
    players: [],
    items: {},
    logs: [],
    frozen: {}, // playerId -> bool, UI-tracked toggle state
    spectatingId: null,
    bans: [],
    modalPlayerId: null,
  };

  const playersBody = document.getElementById('playersBody');
  const playerSearch = document.getElementById('playerSearch');
  const itemTarget = document.getElementById('itemTarget');
  const itemSearch = document.getElementById('itemSearch');
  const itemSelect = document.getElementById('itemSelect');
  const itemCount = document.getElementById('itemCount');
  const logList = document.getElementById('logList');
  const logSearch = document.getElementById('logSearch');
  const logKind = document.getElementById('logKind');
  const bansBody = document.getElementById('bansBody');
  const banSearch = document.getElementById('banSearch');
  const playerModal = document.getElementById('playerModal');
  const modalTitle = document.getElementById('modalTitle');
  const modalInfo = document.getElementById('modalInfo');
  const modalFlags = document.getElementById('modalFlags');
  const screenshotWrap = document.getElementById('screenshotWrap');

  function closeMenu() {
    document.body.classList.remove('visible');
    fetchNui('close');
  }

  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && document.body.classList.contains('visible')) {
      if (playerModal.classList.contains('open')) closeModal();
      else closeMenu();
    }
  });

  document.querySelectorAll('.tab-btn').forEach((btn) => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('.tab-btn').forEach((b) => b.classList.remove('active'));
      document.querySelectorAll('.tab-page').forEach((p) => p.classList.remove('active'));
      btn.classList.add('active');
      document.querySelector(`.tab-page[data-page="${btn.dataset.tab}"]`).classList.add('active');
    });
  });

  document.querySelectorAll('[data-action="close"]').forEach((el) => {
    el.addEventListener('click', closeMenu);
  });
  document.querySelectorAll('[data-action="refreshPlayers"]').forEach((el) => {
    el.addEventListener('click', () => fetchNui('refreshPlayers'));
  });
  document.querySelectorAll('[data-action="refreshLogs"]').forEach((el) => {
    el.addEventListener('click', () => fetchNui('refreshLogs'));
  });
  document.querySelectorAll('[data-action="refreshBans"]').forEach((el) => {
    el.addEventListener('click', () => fetchNui('refreshBans'));
  });
  document.querySelectorAll('[data-action="closeModal"]').forEach((el) => {
    el.addEventListener('click', closeModal);
  });

  function renderPlayers() {
    const filter = playerSearch.value.trim().toLowerCase();
    const rows = state.players
      .filter((p) => !filter || p.name.toLowerCase().includes(filter) || String(p.id).includes(filter))
      .map((p) => {
        const isSelf = p.id === state.selfId;
        const isFrozen = !!state.frozen[p.id];
        const isSpectating = state.spectatingId === p.id;
        return `
        <tr>
          <td>${p.id}${isSelf ? ' <span style="color:var(--accent)">(you)</span>' : ''}</td>
          <td>${escapeHtml(p.name)}</td>
          <td>${p.ping}</td>
          <td><span class="flag-count${p.flags > 0 ? ' hot' : ''}">${p.flags || 0}</span></td>
          <td>
            <div class="action-group">
              <button class="btn small" data-act="info" data-id="${p.id}">Info</button>
              <button class="btn small" data-act="goto" data-id="${p.id}">Goto</button>
              <button class="btn small" data-act="bring" data-id="${p.id}">Bring</button>
              <button class="btn small" data-act="spectate" data-id="${p.id}">${isSpectating ? 'Stop Spec' : 'Spectate'}</button>
              <button class="btn small" data-act="heal" data-id="${p.id}">Heal</button>
              <button class="btn small" data-act="freeze" data-id="${p.id}">${isFrozen ? 'Unfreeze' : 'Freeze'}</button>
              <button class="btn small danger" data-act="kill" data-id="${p.id}">Kill</button>
              <button class="btn small danger" data-act="kick" data-id="${p.id}">Kick</button>
              <button class="btn small danger" data-act="ban" data-id="${p.id}">Ban</button>
            </div>
          </td>
        </tr>`;
      })
      .join('');

    playersBody.innerHTML = rows || `<tr><td colspan="5" class="empty-state">No players match.</td></tr>`;
  }

  function renderItemTarget() {
    const opts = [`<option value="${state.selfId}">Myself (${state.selfId})</option>`]
      .concat(
        state.players
          .filter((p) => p.id !== state.selfId)
          .map((p) => `<option value="${p.id}">${escapeHtml(p.name)} (${p.id})</option>`)
      );
    itemTarget.innerHTML = opts.join('');
  }

  function renderItemSelect() {
    const filter = itemSearch.value.trim().toLowerCase();
    const entries = Object.entries(state.items)
      .filter(([name, item]) => !filter || name.toLowerCase().includes(filter) || (item.label || '').toLowerCase().includes(filter))
      .sort((a, b) => (a[1].label || a[0]).localeCompare(b[1].label || b[0]));

    itemSelect.innerHTML = entries
      .map(([name, item]) => `<option value="${name}">${escapeHtml(item.label || name)}${item.weapon ? ' 🔫' : ''}</option>`)
      .join('');
  }

  function logEntryHtml(entry) {
    const time = entry.time ? new Date(entry.time * 1000).toLocaleTimeString() : '';
    const action = entry.action || '';
    return `
        <div class="log-entry">
          <div>
            <span class="kind">${escapeHtml(entry.kind)}</span>
            &nbsp;<strong>${escapeHtml(entry.name)}</strong> — ${escapeHtml(entry.detail || '')}
            ${action ? `<span class="action ${escapeHtml(action)}">${escapeHtml(action)}</span>` : ''}
          </div>
          <div class="meta">${time}</div>
        </div>`;
  }

  function renderLogKinds() {
    const current = logKind.value;
    const kinds = [...new Set(state.logs.map((e) => e.kind))].sort();
    logKind.innerHTML = ['<option value="">All detections</option>']
      .concat(kinds.map((k) => `<option value="${escapeHtml(k)}">${escapeHtml(k)}</option>`))
      .join('');
    logKind.value = kinds.includes(current) ? current : '';
  }

  function renderLogs() {
    renderLogKinds();
    if (!state.logs.length) {
      logList.innerHTML = `<div class="empty-state">No anticheat flags yet.</div>`;
      return;
    }
    const filter = logSearch.value.trim().toLowerCase();
    const kind = logKind.value;
    const rows = state.logs.filter((e) =>
      (!kind || e.kind === kind) &&
      (!filter || (e.name || '').toLowerCase().includes(filter) || (e.detail || '').toLowerCase().includes(filter)));
    logList.innerHTML = rows.length
      ? rows.map(logEntryHtml).join('')
      : `<div class="empty-state">No flags match the filter.</div>`;
  }

  function renderBans() {
    const filter = banSearch.value.trim().toLowerCase();
    const rows = state.bans
      .filter((b) => !filter || [b.id, b.name, b.reason].some((v) => String(v || '').toLowerCase().includes(filter)))
      .sort((a, b) => (b.bannedAt || 0) - (a.bannedAt || 0))
      .map((b) => `
        <tr>
          <td><code>${escapeHtml(b.id)}</code></td>
          <td>${escapeHtml(b.name)}</td>
          <td>${escapeHtml(b.reason)}</td>
          <td>${escapeHtml(b.bannedBy)}</td>
          <td>${b.expires ? escapeHtml(new Date(b.expires * 1000).toLocaleString()) : 'Permanent'}</td>
          <td><button class="btn small danger" data-unban="${escapeHtml(b.id)}">Unban</button></td>
        </tr>`)
      .join('');
    bansBody.innerHTML = rows || `<tr><td colspan="6" class="empty-state">No active bans.</td></tr>`;
  }

  function renderStats(stats) {
    document.querySelectorAll('[data-stat]').forEach((el) => {
      const v = stats ? stats[el.dataset.stat] : undefined;
      el.textContent = v === undefined || v === null ? '–' : v;
    });
  }

  function openModal(id) {
    state.modalPlayerId = id;
    modalTitle.textContent = `Player ${id}`;
    modalInfo.innerHTML = '<div class="k">Loading…</div>';
    modalFlags.innerHTML = '';
    screenshotWrap.innerHTML = '';
    playerModal.classList.add('open');
    fetchNui('playerInfo', { id });
  }

  function closeModal() {
    state.modalPlayerId = null;
    playerModal.classList.remove('open');
    screenshotWrap.innerHTML = '';
  }

  function renderPlayerInfo(info) {
    if (!info) {
      modalInfo.innerHTML = '<div class="k">Player is no longer online.</div>';
      return;
    }
    if (info.id !== state.modalPlayerId) return;

    modalTitle.textContent = `${info.name} (${info.id})`;
    const rows = [
      ['Ping', info.ping],
      ['Health', info.health],
      ['Armour', info.armour],
      ['HW tokens', info.tokens],
      ['AC bypass', info.bypassed ? 'yes' : 'no'],
    ];
    modalInfo.innerHTML = rows
      .map(([k, v]) => `<div class="k">${k}</div><div class="v">${escapeHtml(v)}</div>`)
      .concat(`<div class="k">Identifiers</div><div class="v">${(info.identifiers || []).map(escapeHtml).join('<br>')}</div>`)
      .join('');
    modalFlags.innerHTML = (info.flags || []).length
      ? info.flags.map(logEntryHtml).join('')
      : '<div class="empty-state">No flags this session.</div>';
  }

  function escapeHtml(str) {
    return String(str == null ? '' : str).replace(/[&<>"']/g, (c) => ({
      '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
    }[c]));
  }

  playerSearch.addEventListener('input', renderPlayers);
  logSearch.addEventListener('input', renderLogs);
  logKind.addEventListener('change', renderLogs);
  banSearch.addEventListener('input', renderBans);

  bansBody.addEventListener('click', (e) => {
    const btn = e.target.closest('button[data-unban]');
    if (!btn) return;
    if (confirm(`Lift ban ${btn.dataset.unban}?`)) fetchNui('unban', { banId: btn.dataset.unban });
  });

  document.getElementById('screenshotBtn').addEventListener('click', () => {
    if (state.modalPlayerId === null) return;
    screenshotWrap.innerHTML = '<div class="empty-state">Requesting screenshot…</div>';
    fetchNui('screenshot', { id: state.modalPlayerId });
  });
  itemSearch.addEventListener('input', renderItemSelect);

  document.getElementById('giveItemBtn').addEventListener('click', () => {
    const item = itemSelect.value;
    if (!item) return;
    fetchNui('giveItem', {
      id: parseInt(itemTarget.value, 10),
      item,
      count: parseInt(itemCount.value, 10) || 1,
    });
  });

  playersBody.addEventListener('click', (e) => {
    const btn = e.target.closest('button[data-act]');
    if (!btn) return;
    const id = parseInt(btn.dataset.id, 10);
    const act = btn.dataset.act;

    switch (act) {
      case 'info':
        openModal(id);
        break;
      case 'goto':
        fetchNui('teleportToPlayer', { id });
        break;
      case 'bring':
        fetchNui('teleportPlayerToMe', { id });
        break;
      case 'heal':
        fetchNui('heal', { id });
        break;
      case 'kill':
        if (confirm('Kill this player?')) fetchNui('kill', { id });
        break;
      case 'freeze': {
        const next = !state.frozen[id];
        state.frozen[id] = next;
        fetchNui('freeze', { id, state: next });
        renderPlayers();
        break;
      }
      case 'kick': {
        const reason = prompt('Kick reason:', 'Removed by admin');
        if (reason !== null) fetchNui('kick', { id, reason });
        break;
      }
      case 'ban': {
        const reason = prompt('Ban reason:', 'Banned by admin');
        if (reason === null) break;
        const hours = prompt('Duration in hours (0 = permanent):', '0');
        fetchNui('ban', { id, reason, hours: parseInt(hours, 10) || 0 });
        break;
      }
      case 'spectate':
        if (state.spectatingId === id) {
          fetchNui('stopSpectate');
          state.spectatingId = null;
        } else {
          fetchNui('startSpectate', { id });
          state.spectatingId = id;
        }
        renderPlayers();
        break;
    }
  });

  window.addEventListener('message', (event) => {
    const { action, data, selfId } = event.data || {};
    switch (action) {
      case 'open':
        state.selfId = selfId;
        document.body.classList.add('visible');
        break;
      case 'close':
        document.body.classList.remove('visible');
        closeModal();
        break;
      case 'players':
        state.players = data || [];
        renderPlayers();
        renderItemTarget();
        break;
      case 'items':
        state.items = data || {};
        renderItemSelect();
        break;
      case 'logs':
        state.logs = data || [];
        renderLogs();
        break;
      case 'newFlag':
        state.logs.unshift(data);
        renderLogs();
        fetchNui('refreshStats');
        break;
      case 'stats':
        renderStats(data);
        break;
      case 'bans':
        state.bans = data || [];
        renderBans();
        break;
      case 'playerInfo':
        renderPlayerInfo(data);
        break;
      case 'screenshot':
        if (event.data.id === state.modalPlayerId && typeof data === 'string' && data.startsWith('data:image/')) {
          screenshotWrap.innerHTML = '';
          const img = document.createElement('img');
          img.src = data;
          screenshotWrap.appendChild(img);
        }
        break;
    }
  });
})();
