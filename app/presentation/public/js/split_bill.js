(function() {
  function initSplitBillForm() {
    var form = document.querySelector('[data-split-form]');
    if (!form) return;

    var tableBody = document.querySelector('#split-people-table tbody');
    var template = document.querySelector('#split-person-template');
    var addButton = document.querySelector('[data-add-person]');

    if (!tableBody || !template || !addButton) return;

    function toggleRemoveButtons() {
      var rows = tableBody.querySelectorAll('.split-person-row');
      rows.forEach(function(row) {
        var button = row.querySelector('[data-remove-person]');
        if (button) {
          button.disabled = rows.length <= 1;
        }
      });
    }

    function bindRow(row) {
      var removeButton = row.querySelector('[data-remove-person]');
      if (removeButton) {
        removeButton.addEventListener('click', function() {
          if (tableBody.querySelectorAll('.split-person-row').length > 1) {
            row.remove();
            toggleRemoveButtons();
          }
        });
      }
    }

    addButton.addEventListener('click', function() {
      var fragment = template.content.cloneNode(true);
      var row = fragment.querySelector('.split-person-row');
      tableBody.appendChild(fragment);
      bindRow(row);
      toggleRemoveButtons();
    });

    tableBody.querySelectorAll('.split-person-row').forEach(bindRow);
    toggleRemoveButtons();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initSplitBillForm);
  } else {
    initSplitBillForm();
  }
})();
