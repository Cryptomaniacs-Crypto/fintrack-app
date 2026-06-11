document.addEventListener('DOMContentLoaded', function () {
  Chart.defaults.font.family = 'Inter, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, sans-serif';
  Chart.defaults.color = '#979db5';

  // ── Donut: Expenses by Category ──────────────────────────────────────
  var catEl = document.getElementById('categoryChart');
  if (catEl) {
    var catLabels = JSON.parse(catEl.dataset.labels || '[]');
    var catValues = JSON.parse(catEl.dataset.values || '[]');
    // Fold palette: navy → cornflower → electric blue → hyacinth → smoke → silver
    var palette = ['#20294c', '#375390', '#459af8', '#788dba', '#979db5', '#c7cbdb', '#dddfe9'];

    new Chart(catEl, {
      type: 'doughnut',
      data: {
        labels: catLabels,
        datasets: [{
          data: catValues,
          backgroundColor: palette.slice(0, catValues.length),
          borderColor: '#ffffff',
          borderWidth: 2,
          hoverOffset: 6
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        cutout: '62%',
        plugins: {
          legend: {
            position: 'bottom',
            labels: { font: { size: 12 }, padding: 14, boxWidth: 12 }
          },
          tooltip: {
            callbacks: {
              label: function (ctx) {
                var total = ctx.dataset.data.reduce(function (a, b) { return a + b; }, 0);
                var pct = total > 0 ? ((ctx.parsed / total) * 100).toFixed(1) : '0.0';
                return ' $' + ctx.parsed.toFixed(2) + ' (' + pct + '%)';
              }
            }
          }
        }
      }
    });
  }

  // ── Bar: Monthly Income vs Expenses ──────────────────────────────────
  var mEl = document.getElementById('monthlyChart');
  if (mEl) {
    var mLabels   = JSON.parse(mEl.dataset.labels   || '[]');
    var mIncome   = JSON.parse(mEl.dataset.income   || '[]');
    var mExpenses = JSON.parse(mEl.dataset.expenses || '[]');

    new Chart(mEl, {
      type: 'bar',
      data: {
        labels: mLabels,
        datasets: [
          {
            label: 'Income',
            data: mIncome,
            backgroundColor: 'rgba(31, 157, 87, 0.80)',
            borderColor:     'rgba(31, 157, 87, 1)',
            borderWidth: 1.5,
            borderRadius: 6,
            borderSkipped: false
          },
          {
            label: 'Expenses',
            data: mExpenses,
            backgroundColor: 'rgba(224, 85, 109, 0.80)',
            borderColor:     'rgba(224, 85, 109, 1)',
            borderWidth: 1.5,
            borderRadius: 6,
            borderSkipped: false
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            position: 'bottom',
            labels: { font: { size: 12 }, padding: 14, boxWidth: 12 }
          },
          tooltip: {
            callbacks: {
              label: function (ctx) {
                return ' ' + ctx.dataset.label + ': $' + ctx.parsed.y.toFixed(2);
              }
            }
          }
        },
        scales: {
          x: {
            grid: { display: false },
            ticks: { font: { size: 11 } }
          },
          y: {
            grid: { color: '#f0f0f0' },
            beginAtZero: true,
            ticks: {
              font: { size: 11 },
              callback: function (v) { return '$' + v; }
            }
          }
        }
      }
    });
  }
});
