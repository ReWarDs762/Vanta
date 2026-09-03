# VANTA — Serveur FiveM Zombie Survival PVP

> **Toute la documentation d'architecture vit dans [`CLAUDE.md`](CLAUDE.md).**
> Ce fichier n'en est qu'un pointeur : lis `CLAUDE.md`, pas celui-ci.

## Où trouver quoi

| Question | Fichier |
|---|---|
| Architecture stable, pièges techniques, schéma de base | [`CLAUDE.md`](CLAUDE.md) |
| Avancement par resource, bugs actifs, écarts doc/code, ce qui est testé en jeu | [`STATUS.md`](STATUS.md) |
| Quoi faire, dans quel ordre, check-list de sortie, journal de session | [`ROADMAP.md`](ROADMAP.md) |
| Audit d'origine du dépôt, licences, restauration de `spooner` | [`audit-initial.md`](audit-initial.md) |

## Pourquoi ce fichier ne contient plus rien

`AGENTS.md` était une copie de `CLAUDE.md`, entretenue à la main. Les deux ont
divergé : au 03/09/2026 il faisait 389 lignes contre 618, ignorait la resource
`pvp_combat` (créée le 23/08), le système de notifications générique de
`vanta_ui`, et toutes les décisions prises depuis. Deux documents
d'architecture qui se contredisent, lus par des outils différents selon
l'assistant utilisé, c'est pire que pas de second document du tout.

Réduit à un pointeur pour qu'il ne puisse plus mentir.
