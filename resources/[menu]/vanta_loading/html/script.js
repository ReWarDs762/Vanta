// ─────────────────────────────────────────────
//  VANTA Loading Screen — script.js
// ─────────────────────────────────────────────

const fill  = document.getElementById('fill');
const pct   = document.getElementById('pct');
const step  = document.getElementById('step');

// Messages affichés pendant le chargement
const messages = [
    'Connexion au serveur...',
    'Chargement des ressources...',
    'Synchronisation des données...',
    'Initialisation du monde...',
    'Préparation de votre équipement...',
    'Analyse de la zone de survie...',
    'Chargement terminé.',
];

let currentProgress = 0;
let targetProgress  = 0;
let messageIndex    = 0;
let animFrame       = null;

// Avance la barre vers la cible en douceur
function animateProgress() {
    if (currentProgress < targetProgress) {
        currentProgress = Math.min(currentProgress + 0.8, targetProgress);
        const v = Math.round(currentProgress);
        fill.style.width = v + '%';
        pct.textContent  = v + '%';
    }

    if (currentProgress < 100) {
        animFrame = requestAnimationFrame(animateProgress);
    }
}

// Met à jour le message affiché
function setStep(text) {
    step.style.opacity = '0';
    setTimeout(() => {
        step.textContent   = text;
        step.style.opacity = '1';
    }, 200);
}

// Réception des événements FiveM
window.addEventListener('message', function(e) {
    const data = e.data;

    // Progression standard FiveM (0.0 → 1.0)
    if (data.eventName === 'loadProgress') {
        const p = Math.round((data.loadFraction || 0) * 100);
        targetProgress = p;

        // Changer le message tous les ~15%
        const idx = Math.min(Math.floor(p / 15), messages.length - 1);
        if (idx !== messageIndex) {
            messageIndex = idx;
            setStep(messages[messageIndex]);
        }

        cancelAnimationFrame(animFrame);
        animFrame = requestAnimationFrame(animateProgress);
    }

    // FiveM envoie startFadeOut quand le jeu est prêt → animation immédiate
    if (data.eventName === 'startFadeOut') {
        targetProgress  = 100;
        currentProgress = 100;
        fill.style.width = '100%';
        pct.textContent  = '100%';
        setStep('Chargement terminé.');
        document.body.classList.add('fade-out');
    }
});

// Fallback : si FiveM n'envoie aucun event (test navigateur)
// Simule une progression automatique
(function simulateFallback() {
    if (window.invokeNative) return; // on est dans FiveM, pas besoin

    let p = 0;
    const interval = setInterval(() => {
        p += Math.random() * 6 + 2;
        if (p >= 100) {
            p = 100;
            clearInterval(interval);
            setStep('Chargement terminé.');
        } else {
            const idx = Math.min(Math.floor(p / 15), messages.length - 1);
            if (idx !== messageIndex) {
                messageIndex = idx;
                setStep(messages[messageIndex]);
            }
        }
        targetProgress = p;
        cancelAnimationFrame(animFrame);
        animFrame = requestAnimationFrame(animateProgress);
    }, 400);
})();
