document.addEventListener('DOMContentLoaded', function () {
  Chart.defaults.font.family = '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, sans-serif';
  Chart.defaults.color = '#737373';

  // ── Donut: Expenses by Category ──────────────────────────────────────
  var catEl = document.getElementById('categoryChart');
  if (catEl) {
    var catLabels = JSON.parse(catEl.dataset.labels || '[]');
    var catValues = JSON.parse(catEl.dataset.values || '[]');
    var palette = ['#0f0f0f', '#3d3d3d', '#6b6b6b', '#949494', '#bdbdbd', '#d6d6d6', '#e8e8e8'];

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
            backgroundColor: 'rgba(22, 163, 74, 0.75)',
            borderColor:     'rgba(22, 163, 74, 1)',
            borderWidth: 1.5,
            borderRadius: 4,
            borderSkipped: false
          },
          {
            label: 'Expenses',
            data: mExpenses,
            backgroundColor: 'rgba(220, 38, 38, 0.75)',
            borderColor:     'rgba(220, 38, 38, 1)',
            borderWidth: 1.5,
            borderRadius: 4,
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
