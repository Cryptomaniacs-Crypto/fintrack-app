(function () {
  // Step 1: add/remove participant username rows.
  function initParticipants() {
    var list = document.querySelector('[data-participant-list]');
    var template = document.querySelector('#participant-template');
    var addButton = document.querySelector('[data-add-participant]');
    if (!list || !template || !addButton) return;

    function bindRemove(row) {
      var button = row.querySelector('[data-remove-participant]');
      if (button) {
        button.addEventListener('click', function () { row.remove(); });
      }
    }

    function addRow(username) {
      var fragment = template.content.cloneNode(true);
      var row = fragment.querySelector('.participant-row');
      if (username) {
        var input = row.querySelector('input[name="participant_username[]"]');
        if (input) input.value = username;
      }
      list.appendChild(fragment);
      bindRemove(row);
      return row;
    }

    addButton.addEventListener('click', function () { addRow(); });

    list.querySelectorAll('.participant-row').forEach(bindRemove);

    // Per-row friend dropdown: picking a friend from a row's ▾ menu fills that
    // row's username input. Delegated so dynamically-added rows work too.
    list.addEventListener('click', function (event) {
      var option = event.target.closest('[data-friend-option]');
      if (!option) return;
      var row = option.closest('.participant-row');
      if (!row) return;
      var input = row.querySelector('input[name="participant_username[]"]');
      if (input) input.value = option.getAttribute('data-username') || '';
    });
  }

  // Step 2: add/remove item rows. Each new row gets a unique index spliced into
  // its field names (items[<index>][...]) so they survive add/remove.
  function initItems() {
    var list = document.querySelector('[data-item-list]');
    var template = document.querySelector('#item-template');
    var addButton = document.querySelector('[data-add-item]');
    if (!list || !template || !addButton) return;

    var counter = parseInt(addButton.getAttribute('data-next-index'), 10) || 0;

    function bindRemove(row) {
      var button = row.querySelector('[data-remove-item]');
      if (button) {
        button.addEventListener('click', function () {
          if (list.querySelectorAll('.item-row').length > 1) row.remove();
        });
      }
    }

    addButton.addEventListener('click', function () {
      var index = counter++;
      var html = template.innerHTML.replace(/__INDEX__/g, index).trim();
      var wrapper = document.createElement('div');
      wrapper.innerHTML = html;
      var row = wrapper.firstElementChild;
      list.appendChild(row);
      bindRemove(row);
    });

    list.querySelectorAll('.item-row').forEach(bindRemove);
  }

  function init() {
    initParticipants();
    initItems();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
