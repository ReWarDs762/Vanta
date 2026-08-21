let hideTimeout = null;

window.addEventListener('message', (event) => {
  const data = event.data;
  if (!data || data.action !== 'showLootToast') return;

  const toast    = document.getElementById('loot-toast');
  const amountEl = document.getElementById('loot-amount');
  const itemEl   = document.getElementById('loot-item');

  amountEl.textContent = `+${data.amount}$`;
  itemEl.textContent   = data.item || '';
  itemEl.style.display = data.item ? '' : 'none';

  clearTimeout(hideTimeout);
  toast.classList.remove('visible');
  void toast.offsetWidth; // force reflow pour rejouer la transition même si déjà visible
  toast.classList.add('visible');

  hideTimeout = setTimeout(() => {
    toast.classList.remove('visible');
  }, 2500);
});
