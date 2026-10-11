(function () {
    'use strict';

    var body = document.body;
    var menu = document.getElementById('menu');
    var titleEl = document.getElementById('menu-title');
    var subtitleEl = document.getElementById('menu-subtitle');
    var counterEl = document.getElementById('menu-counter');
    var itemsEl = document.getElementById('menu-items');
    var scrollEl = document.getElementById('menu-scroll');
    var thumbEl = document.getElementById('menu-scroll-thumb');
    var scrollTextEl = document.getElementById('menu-scroll-text');
    var descriptionEl = document.getElementById('menu-description');
    var descriptionTextEl = document.getElementById('menu-description-text');
    var creditEl = document.getElementById('menu-credit');

    var POSITIONS = ['pos-left', 'pos-center', 'pos-right'];

    function clamp(value, min, max) {
        if (typeof value !== 'number' || isNaN(value)) return min;
        if (value < min) return min;
        if (value > max) return max;
        return value;
    }

    function setPosition(position) {
        var name = 'pos-right';
        if (position === 'left' || position === 'center') {
            name = 'pos-' + position;
        }
        for (var i = 0; i < POSITIONS.length; i++) {
            body.classList.toggle(POSITIONS[i], POSITIONS[i] === name);
        }
    }

    function buildRow(item) {
        var row = document.createElement('div');
        row.className = 'item';
        if (item.selected) row.classList.add('item--selected');
        if (item.disabled) row.classList.add('item--disabled');

        var label = document.createElement('span');
        label.textContent = item.label || '';
        row.appendChild(label);

        if (item.right) {
            var right = document.createElement('strong');
            right.textContent = item.right;
            row.appendChild(right);
        }

        return row;
    }

    function renderItems(items) {
        var fragment = document.createDocumentFragment();
        for (var i = 0; i < items.length; i++) {
            fragment.appendChild(buildRow(items[i] || {}));
        }
        itemsEl.textContent = '';
        itemsEl.appendChild(fragment);
    }

    function renderScroll(scroll) {
        if (!scroll) {
            scrollEl.classList.add('menu-scroll--hidden');
            return;
        }

        var size = clamp(scroll.size, 0.08, 1);
        var position = clamp(scroll.position, 0, 1 - size);

        thumbEl.style.width = (size * 100) + '%';
        thumbEl.style.left = (position * 100) + '%';
        scrollTextEl.textContent = (scroll.up ? '^' : ' ') +
            '  ' + (scroll.more || 0) + ' more  ' +
            (scroll.down ? 'v' : ' ');

        scrollEl.classList.remove('menu-scroll--hidden');
    }

    function hide() {
        menu.classList.add('menu--hidden');
    }

    function render(data) {
        if (data.open === false) {
            hide();
            return;
        }

        if (data.accent) {
            document.documentElement.style.setProperty('--accent', data.accent);
        }

        setPosition(data.position);

        titleEl.textContent = data.title || 'tsivtools';
        subtitleEl.textContent = data.subtitle || 'tsivtools';

        var total = data.total || 0;
        if (total > 0) {
            counterEl.textContent = (data.index || 0) + ' / ' + total;
            counterEl.style.display = '';
        } else {
            counterEl.textContent = '';
            counterEl.style.display = 'none';
        }

        renderItems(Array.isArray(data.items) ? data.items : []);
        renderScroll(data.scroll);

        if (data.description) {
            descriptionTextEl.textContent = data.description;
            descriptionEl.classList.remove('menu-description--hidden');
        } else {
            descriptionTextEl.textContent = '';
            descriptionEl.classList.add('menu-description--hidden');
        }

        creditEl.classList.toggle('menu-credit--hidden', data.watermark === false);

        menu.classList.remove('menu--hidden');
    }

    window.addEventListener('message', function (event) {
        var data = event.data || {};
        if (data.action === 'menu') {
            render(data);
        } else if (data.action === 'menuClose') {
            hide();
        }
    });
})();
