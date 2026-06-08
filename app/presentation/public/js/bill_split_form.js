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

    addButton.addEventListener('click', function () {
      var fragment = template.content.cloneNode(true);
      var row = fragment.querySelector('.participant-row');
      list.appendChild(fragment);
      bindRemove(row);
    });

    list.querySelectorAll('.participant-row').forEach(bindRemove);
  }

  // Step 2: add/remove dish rows. Each new row gets a unique index spliced into
  // its field names (items[<index>][...]) so they survive add/remove.
  function initDishes() {
    var list = document.querySelector('[data-dish-list]');
    var template = document.querySelector('#dish-template');
    var addButton = document.querySelector('[data-add-dish]');
    if (!list || !template || !addButton) return;

    var counter = parseInt(addButton.getAttribute('data-next-index'), 10) || 0;

    function bindRemove(row) {
      var button = row.querySelector('[data-remove-dish]');
      if (button) {
        button.addEventListener('click', function () {
          if (list.querySelectorAll('.dish-row').length > 1) row.remove();
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

    list.querySelectorAll('.dish-row').forEach(bindRemove);
  }

  function init() {
    initParticipants();
    initDishes();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
