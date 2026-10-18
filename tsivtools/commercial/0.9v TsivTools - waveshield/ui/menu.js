(function () {
    'use strict';

    var state = {
        open: false,
        title: '',
        subtitle: '',
        path: [],
        categories: [],
        items: [],
        filtered: [],
        selectedIndex: 1,
        accent: { r: 168, g: 85, b: 247 },
        position: 'right',
        query: ''
    };

    var menuEl = document.getElementById('menu');
    var titleEl = document.getElementById('menu-title');
    var subtitleEl = document.getElementById('menu-subtitle');
    var pathEl = document.getElementById('menu-path');
    var searchEl = document.getElementById('menu-search');
    var catsEl = document.getElementById('menu-cats');
    var itemsEl = document.getElementById('menu-items');
    var closeEl = document.getElementById('menu-close');
    var overlay = document.getElementById('overlay');

    function resource() {
        return (typeof GetParentResourceName === 'function')
            ? GetParentResourceName()
            : 'atlas_tsiv_menu';
    }

    function post(endpoint, body) {
        fetch('https://' + resource() + '/' + endpoint, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(body || {})
        }).catch(function () {  });
    }

    function esc(value) {
        return String(value == null ? '' : value).replace(/[&<>"']/g, function (c) {
            return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
        });
    }

    function inputOpen() {
        return !!overlay && !overlay.classList.contains('hidden');
    }

    function refocus() {}

    function findEntry(index) {
        for (var i = 0; i < state.filtered.length; i++) {
            if (state.filtered[i].orig === index) return state.filtered[i];
        }
        return null;
    }

    function isSelectable(entry) {
        return !!entry && entry.item.enabled && entry.item.kind !== 'label';
    }

    function firstSelectable() {
        for (var i = 0; i < state.filtered.length; i++) {
            if (isSelectable(state.filtered[i])) return state.filtered[i].orig;
        }
        return 0;
    }

    function hasIndex(index) {
        return findEntry(index) !== null;
    }

    function applyAccent() {
        var a = state.accent || { r: 168, g: 85, b: 247 };
        document.documentElement.style.setProperty('--accent', 'rgb(' + a.r + ',' + a.g + ',' + a.b + ')');
    }

    function renderPath() {
        pathEl.textContent = state.path.length > 1 ? state.path.join('  \u203A  ') : '';
    }

    function renderCats() {
        if (!state.categories.length) {
            catsEl.style.display = 'none';
            catsEl.innerHTML = '';
            return;
        }
        catsEl.style.display = '';
        var html = '';
        for (var i = 0; i < state.categories.length; i++) {
            var cat = state.categories[i];
            html += '<div class="cat' + (cat.active ? ' active' : '') + '" data-cat="' + cat.index + '">'
                + esc(cat.label) + '</div>';
        }
        catsEl.innerHTML = html;
    }

    function rightHtml(item) {
        if (item.kind === 'checkbox') {
            return '<span class="toggle' + (item.checked ? ' on' : '') + '"></span>';
        }
        if (item.kind === 'list') {
            return '<div class="list">'
                + '<span class="arrow" data-list="-1">\u2039</span>'
                + '<span class="list-value">' + esc(item.right) + '</span>'
                + '<span class="arrow" data-list="1">\u203A</span>'
                + '</div>';
        }
        if (item.kind === 'submenu') {
            return '<span class="chev">\u203A</span>';
        }
        if (item.right) {
            return '<span class="tag">' + esc(item.right) + '</span>';
        }
        return '';
    }

    function renderItems() {
        if (!state.filtered.length) {
            itemsEl.innerHTML = '<div class="empty">'
                + (state.query ? 'No results' : 'Nothing here') + '</div>';
            return;
        }

        var html = '';
        for (var i = 0; i < state.filtered.length; i++) {
            var entry = state.filtered[i];
            var item = entry.item;
            var cls = 'row k-' + item.kind;
            if (item.kind === 'label' || !item.enabled) cls += ' disabled';
            if (item.kind === 'label') cls += ' label-row';
            if (entry.orig === state.selectedIndex) cls += ' selected';

            html += '<div class="' + cls + '" data-index="' + entry.orig + '">'
                + '<div class="row-main">'
                + '<div class="row-label">' + esc(item.label) + '</div>';
            if (item.description) {
                html += '<div class="row-desc">' + esc(item.description) + '</div>';
            }
            html += '</div><div class="row-right">' + rightHtml(item) + '</div></div>';
        }
        itemsEl.innerHTML = html;
        updateSelection();
    }

    function applyFilter() {
        var query = state.query.toLowerCase();
        var filtered = [];

        for (var i = 0; i < state.items.length; i++) {
            var item = state.items[i];
            if (query) {
                var hay = (item.label + ' ' + (item.description || '')).toLowerCase();
                if (hay.indexOf(query) === -1) continue;
                if (item.kind === 'label') continue;
            }
            filtered.push({ item: item, orig: i + 1 });
        }

        state.filtered = filtered;

        if (!hasIndex(state.selectedIndex) || !isSelectable(findEntry(state.selectedIndex))) {
            var next = firstSelectable();
            if (next) state.selectedIndex = next;
        }

        renderItems();
    }

    function updateSelection() {
        var rows = itemsEl.querySelectorAll('.row');
        for (var i = 0; i < rows.length; i++) {
            var on = parseInt(rows[i].getAttribute('data-index'), 10) === state.selectedIndex;
            rows[i].classList.toggle('selected', on);
            if (on) rows[i].scrollIntoView({ block: 'nearest' });
        }
    }

    function move(direction) {
        var list = state.filtered;
        if (!list.length) return;

        var pos = -1;
        for (var i = 0; i < list.length; i++) {
            if (list[i].orig === state.selectedIndex) { pos = i; break; }
        }

        var count = list.length;
        for (var step = 1; step <= count; step++) {
            var next = pos + direction * step;
            next = ((next % count) + count) % count;
            if (isSelectable(list[next])) {
                state.selectedIndex = list[next].orig;
                break;
            }
        }
        updateSelection();
    }

    function activate() {
        var entry = findEntry(state.selectedIndex);
        if (!isSelectable(entry)) return;
        post('menuActivate', { index: state.selectedIndex });
    }

    function changeList(direction) {
        var entry = findEntry(state.selectedIndex);
        if (!entry || entry.item.kind !== 'list' || !entry.item.enabled) return;
        post('menuList', { index: state.selectedIndex, direction: direction });
    }

    itemsEl.addEventListener('click', function (event) {
        var row = event.target.closest('.row');
        if (!row) return;
        var index = parseInt(row.getAttribute('data-index'), 10);
        var arrow = event.target.closest('.arrow');

        if (arrow) {
            state.selectedIndex = index;
            post('menuList', { index: index, direction: parseInt(arrow.getAttribute('data-list'), 10) });
            return;
        }

        var entry = findEntry(index);
        if (!isSelectable(entry)) return;
        state.selectedIndex = index;
        post('menuActivate', { index: index });
    });

    itemsEl.addEventListener('mouseover', function (event) {
        var row = event.target.closest('.row');
        if (!row) return;
        var entry = findEntry(parseInt(row.getAttribute('data-index'), 10));
        if (!isSelectable(entry)) return;
        state.selectedIndex = entry.orig;
        updateSelection();
    });

    catsEl.addEventListener('click', function (event) {
        var cat = event.target.closest('.cat');
        if (!cat) return;
        post('menuCategory', { index: parseInt(cat.getAttribute('data-cat'), 10) });
    });

    if (closeEl) {
        closeEl.addEventListener('mousedown', function (event) { event.preventDefault(); });
        closeEl.addEventListener('click', function () {
            post('menuClose', {});
        });
    }

    searchEl.addEventListener('input', function () {
        state.query = searchEl.value;
        applyFilter();
    });

    document.addEventListener('keydown', function (event) {
        if (!state.open || inputOpen()) return;

        switch (event.key) {
            case 'ArrowUp':
                event.preventDefault();
                move(-1);
                break;
            case 'ArrowDown':
                event.preventDefault();
                move(1);
                break;
            case 'ArrowLeft':
                event.preventDefault();
                changeList(-1);
                break;
            case 'ArrowRight':
                event.preventDefault();
                changeList(1);
                break;
            case 'Tab':
                event.preventDefault();
                cycleCategory(event.shiftKey ? -1 : 1);
                break;
            case 'Enter':
                event.preventDefault();
                activate();
                break;
            case 'Backspace':
                if (state.query.length === 0) {
                    event.preventDefault();
                    post('menuBack', {});
                }
                break;
            case 'Escape':
                event.preventDefault();
                if (state.query.length > 0) {
                    searchEl.value = '';
                    state.query = '';
                    applyFilter();
                } else {
                    post('menuClose', {});
                }
                break;
        }
    });

    function cycleCategory(direction) {
        if (state.categories.length < 1) return;

        var active = -1;
        for (var i = 0; i < state.categories.length; i++) {
            if (state.categories[i].active) { active = i; break; }
        }

        var next = active;
        if (next === -1) {
            next = direction > 0 ? 0 : state.categories.length - 1;
        } else {
            next = ((active + direction) % state.categories.length + state.categories.length) % state.categories.length;
        }

        post('menuCategory', { index: state.categories[next].index });
    }

    function show() {
        state.open = true;
        state.query = '';
        if (searchEl) searchEl.value = '';
        menuEl.classList.remove('hidden');
        document.body.classList.toggle('input-open', inputOpen());
    }

    function hide() {
        state.open = false;
        menuEl.classList.add('hidden');
        if (searchEl) searchEl.blur();
    }

    function render(payload) {
        state.title = payload.title || '';
        state.subtitle = payload.subtitle || '';
        state.path = payload.path || [];
        state.categories = payload.categories || [];
        state.items = payload.items || [];
        state.accent = payload.accent || state.accent;
        state.position = payload.position === 'left' ? 'left' : 'right';
        state.selectedIndex = payload.index || 1;

        menuEl.classList.remove('left', 'right');
        menuEl.classList.add(state.position);

        applyAccent();
        titleEl.textContent = state.title;
        subtitleEl.textContent = state.subtitle;
        renderPath();
        renderCats();
        applyFilter();
    }

    window.addEventListener('message', function (event) {
        var data = event.data || {};
        if (data.action === 'menu:open') {
            show();
        } else if (data.action === 'menu:close') {
            hide();
        } else if (data.action === 'menu:render') {
            if (!state.open) show();
            render(data);
        }
    });

    function resetTilt() {
        var panel = menuEl.querySelector('.panel');
        if (!panel) return;
        panel.style.setProperty('--tilt-x', '0deg');
        panel.style.setProperty('--tilt-y', '0deg');
    }

    menuEl.addEventListener('mousemove', function (event) {
        if (!state.open) return;
        var panel = menuEl.querySelector('.panel');
        if (!panel) return;
        var rect = panel.getBoundingClientRect();
        if (!rect.width || !rect.height) return;
        var x = ((event.clientX - rect.left) / rect.width - 0.5) * 2;
        var y = ((event.clientY - rect.top) / rect.height - 0.5) * 2;
        x = Math.max(-1, Math.min(1, x));
        y = Math.max(-1, Math.min(1, y));
        panel.style.setProperty('--tilt-y', (x * 4).toFixed(2) + 'deg');
        panel.style.setProperty('--tilt-x', (-y * 3).toFixed(2) + 'deg');
    });

    menuEl.addEventListener('mouseleave', resetTilt);

    if (overlay && window.MutationObserver) {
        new MutationObserver(function () {
            document.body.classList.toggle('input-open', inputOpen());
        }).observe(overlay, { attributes: true, attributeFilter: ['class'] });
    }
})();