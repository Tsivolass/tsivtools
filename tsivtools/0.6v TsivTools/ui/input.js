(function () {
    'use strict';

    var overlay = document.getElementById('overlay');
    var box = document.getElementById('box');
    var title = document.getElementById('title');
    var field = document.getElementById('field');
    var counter = document.getElementById('counter');

    var open = false;
    var maxLength = 0;

    function resource() {
        return (typeof GetParentResourceName === 'function')
            ? GetParentResourceName()
            : 'tsivtools';
    }

    function post(endpoint, body) {
        fetch('https://' + resource() + '/' + endpoint, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(body || {})
        }).catch(function () {});
    }

    function updateCounter() {
        if (!maxLength) {
            counter.textContent = '';
            return;
        }
        counter.textContent = field.value.length + ' / ' + maxLength;
        counter.classList.toggle('over', field.value.length > maxLength);
    }

    function show(data) {
        open = true;
        maxLength = data.maxLength || 0;

        title.textContent = data.title || 'Enter a value';
        field.value = data.default || '';
        field.setAttribute('maxlength', maxLength || 255);
        field.setAttribute('inputmode', data.numeric ? 'decimal' : 'text');

        overlay.classList.remove('hidden');
        updateCounter();

        requestAnimationFrame(function () {
            field.focus();
            field.select();
        });
    }

    function close(submitted) {
        if (!open) return;
        open = false;
        overlay.classList.add('hidden');
        post(submitted ? 'inputSubmit' : 'inputCancel', { value: field.value });
        field.value = '';
    }

    window.addEventListener('message', function (event) {
        var data = event.data || {};
        if (data.action === 'openInput') {
            show(data);
        } else if (data.action === 'closeInput') {
            close(false);
        }
    });

    field.addEventListener('input', updateCounter);

    document.addEventListener('keydown', function (event) {
        if (!open) return;

        if (event.key === 'Enter') {
            event.preventDefault();
            close(true);
        } else if (event.key === 'Escape') {
            event.preventDefault();
            close(false);
        }
    });

    overlay.addEventListener('mousedown', function (event) {
        if (open && !box.contains(event.target)) close(false);
    });
})();
