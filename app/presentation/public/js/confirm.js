// CSP-safe confirmation prompts: a form with data-confirm asks before submit.
// (Inline onclick handlers are blocked by our Content-Security-Policy.)
(function () {
  function init() {
    document.querySelectorAll('form[data-confirm]').forEach(function (form) {
      form.addEventListener('submit', function (event) {
        if (!window.confirm(form.getAttribute('data-confirm'))) {
          event.preventDefault();
        }
      });
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
