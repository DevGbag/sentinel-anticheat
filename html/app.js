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
  };

  const playersBody = document.getElementById('playersBody');
  const playerSearch = document.getElementById('playerSearch');
  const itemTarget = document.getElementById('itemTarget');
  const itemSearch = document.getElementById('itemSearch');
  const itemSelect = document.getElementById('itemSelect');
  const itemCount = document.getElementById('itemCount');
  const logList = document.getElementById('logList');

  function closeMenu() {
    document.body.classList.remove('visible');
    fetchNui('close');
  }

  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && document.body.classList.contains('visible')) {
      closeMenu();
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
          <td>
            <div class="action-group">
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

    playersBody.innerHTML = rows || `<tr><td colspan="4" class="empty-state">No players match.</td></tr>`;
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

  function renderLogs() {
    if (!state.logs.length) {
      logList.innerHTML = `<div class="empty-state">No anticheat flags yet.</div>`;
      return;
    }
    logList.innerHTML = state.logs
      .map((entry) => {
        const time = entry.time ? new Date(entry.time * 1000).toLocaleTimeString() : '';
        return `
        <div class="log-entry">
          <div>
            <span class="kind">${escapeHtml(entry.kind)}</span>
            &nbsp;<strong>${escapeHtml(entry.name)}</strong> — ${escapeHtml(entry.detail || '')}
          </div>
          <div class="meta">${time}</div>
        </div>`;
      })
      .join('');
  }

  function escapeHtml(str) {
    return String(str == null ? '' : str).replace(/[&<>"']/g, (c) => ({
      '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
    }[c]));
  }

  playerSearch.addEventListener('input', renderPlayers);
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
        break;
    }
  });
})();
