(function () {
  var radios = document.querySelectorAll('input[name="transaction_type"]');
  var transferFields = document.getElementById('transfer-fields');
  var categoryFields = document.getElementById('category-fields');

  function toggle() {
    var isTransfer = document.getElementById('type-transfer') &&
                     document.getElementById('type-transfer').checked;
    if (transferFields) transferFields.style.display = isTransfer ? '' : 'none';
    if (categoryFields) categoryFields.style.display = isTransfer ? 'none' : '';
  }

  radios.forEach(function (r) { r.addEventListener('change', toggle); });
})();
