fx_version 'cerulean'
game 'gta5'

description 'VANTA Design System v2 — Shared UI tokens & components'
author 'VANTA'
version '2.0.0'

-- Expose les fichiers pour que les autres resources puissent y accéder via nui://vanta_ui/...
-- PAS de ui_page ici : vanta_ui est un design system partagé (CSS only), pas un NUI affiché en jeu.
-- index.html est un showcase de référence consultable hors jeu uniquement.

files {
    'html/vanta.css',
}
